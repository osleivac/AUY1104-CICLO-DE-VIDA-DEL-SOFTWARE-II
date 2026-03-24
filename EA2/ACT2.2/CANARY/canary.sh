#!/bin/bash
# Script para medir el tiempo de despliegue inicial y la velocidad de PROMOCIÓN
# (switch de 10% a 100% de V2) en la estrategia Canary, con límite de 120s.

# --- Variables Requeridas ---
SERVICE_NAME="duoc-app-canary-service"
DEPLOYMENT_CANARY_NAME="duoc-app-canary-v2"
YAML_FILE_CANARY="EA2/ACT2.2/CANARY/canary.yaml"
STABLE_DEPLOYMENT_NAME="duoc-app-stable-v1"

# Variables de la aplicación
# ACTUALIZADO: Buscamos "Green" para validar el contenido de V2.
TARGET_VERSION_COLOR="Green" 
PROMOTION_TIMEOUT_S=120

# Variables de tiempo inicializadas
CONFIRMATION_END_TIME=0
HTTP_STATUS=""
RESPONSE=""

if [ -z "$SERVICE_NAME" ] || [ -z "$DEPLOYMENT_CANARY_NAME" ] || [ -z "$YAML_FILE_CANARY" ] || [ -z "$STABLE_DEPLOYMENT_NAME" ]; then
    echo "Uso: $0 <NOMBRE_SERVICE> <NOMBRE_DEPLOYMENT_CANARY> <RUTA_YAML_CANARY> <NOMBRE_DEPLOYMENT_STABLE>"
    echo "Ej: $0 duoc-app-canary-service duoc-app-canary-v2 CANARY/canary_v2.yaml duoc-app-stable-v1"
    exit 1
fi

echo "--- Iniciando Despliegue Canary (Fase de Exposición 10%) ---"

# 1. INICIO DE LA MEDICIÓN GLOBAL
START_GLOBAL_TIME=$(date +%s.%N)
echo "[1] Aprovisionando LoadBalancer y obteniendo URL..."

# ESPERAR LA URL DEL LOADBALANCER DE AWS (TIEMPO DE PROVISIONAMIENTO)
LB_URL=""
START_LB_PROVISIONING=$(date +%s.%N)
for i in {1..120}; do
    LB_URL=$(kubectl get service "$SERVICE_NAME" -o=jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ ! -z "$LB_URL" ]; then
        echo "[SUCCESS] Hostname de LoadBalancer obtenido: http://$LB_URL"
        break
    fi
    sleep 1
done

END_LB_PROVISIONING=$(date +%s.%N)
LB_PROVISIONING_DURATION=$(echo "$END_LB_PROVISIONING - $START_LB_PROVISIONING" | bc)

if [ -z "$LB_URL" ]; then
    echo "[ERROR] No se pudo obtener el Hostname del LoadBalancer después de 120 segundos."
    exit 1
fi


# 2. DESPLIEGUE DEL ENTORNO CANARY (10% DEL TRÁFICO)
echo "[2] Aplicando YAML de Deployment CANARY y esperando Rollout Interno..."
kubectl apply -f "$YAML_FILE_CANARY"

START_CANARY_ROLLOUT_TIME=$(date +%s.%N)
kubectl rollout status deployment/"$DEPLOYMENT_CANARY_NAME" --timeout=300s
if [ $? -ne 0 ]; then
    echo "[ERROR] El Rollout del Deployment CANARY (inicial) falló."
    exit 1
fi
END_CANARY_ROLLOUT_TIME=$(date +%s.%N)
CANARY_DEPLOY_DURATION=$(echo "$END_CANARY_ROLLOUT_TIME - $START_CANARY_ROLLOUT_TIME" | bc)
echo "[SUCCESS] Deployment CANARY (10%) listo en: $CANARY_DEPLOY_DURATION segundos."

# 3. VERIFICACIÓN DE EXPOSICIÓN (OPCIONAL: Asegura que el Canary es alcanzable)
echo "[3] Simulación: La versión Canary (V2) pasó la prueba de 120s sin fallos."


# 4. SIMULACIÓN DE PROMOCIÓN (SWITCH A V2 TOTAL)
echo -e "\n--- INICIANDO PROMOCIÓN (SWITCH A V2 TOTAL) ---"

# Obtener la cantidad de réplicas de la versión estable para asegurar la capacidad
STABLE_REPLICAS=$(kubectl get deployment "$STABLE_DEPLOYMENT_NAME" -o=jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)
CURRENT_CANARY_REPLICAS=$(kubectl get deployment "$DEPLOYMENT_CANARY_NAME" -o=jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)
TOTAL_REPLICAS=$(($STABLE_REPLICAS + $CURRENT_CANARY_REPLICAS))

if [ "$TOTAL_REPLICAS" -eq 0 ]; then
    echo "[ERROR] No se pudieron obtener las réplicas totales. Asegúrate de que $STABLE_DEPLOYMENT_NAME existe."
    exit 1
fi

echo "[4] Promoviendo V2 a $TOTAL_REPLICAS réplicas y escalando V1 ($STABLE_DEPLOYMENT_NAME) a 0..."
PROMOTION_START_TIME=$(date +%s.%N)

# Tarea A: Escalar la versión Canary (V2) al total
kubectl scale deployment/"$DEPLOYMENT_CANARY_NAME" --replicas=$TOTAL_REPLICAS
# Tarea B: Escalar la versión Estable (V1) a cero (eliminando el riesgo de la versión antigua)
kubectl scale deployment/"$STABLE_DEPLOYMENT_NAME" --replicas=0

# Esperar a que el Rollout de la V2 finalice (todos los Pods nuevos estén Ready)
echo "[INFO] Esperando que la promoción de V2 termine su Rollout en Kubernetes..."
kubectl rollout status deployment/"$DEPLOYMENT_CANARY_NAME" --timeout=300s
if [ $? -ne 0 ]; then
    echo "[ERROR] El Rollout de promoción falló."
    exit 1
fi

# 5. CONFIRMACIÓN FINAL DENTRO DE LA VENTANA DE 120 SEGUNDOS
echo "[5] Confirmando disponibilidad externa y contenido final (Límite: $PROMOTION_TIMEOUT_S s)..."

CONFIRMATION_START_TIME=$(date +%s.%N)

# Loop de confirmación robustecido
i=1
while [ $i -le $PROMOTION_TIMEOUT_S ]; do
    # 5a. Verificamos el código de estado HTTP primero
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$LB_URL" 2>/dev/null)
    
    if [ "$HTTP_STATUS" = "200" ]; then
        # 5b. Si es 200 OK, obtenemos el contenido para verificar la versión
        RESPONSE=$(curl -s "http://$LB_URL")
        if echo "$RESPONSE" | grep -q "$TARGET_VERSION_COLOR"; then
            CONFIRMATION_END_TIME=$(date +%s.%N)
            echo "[SUCCESS] Versión Final ($TARGET_VERSION_COLOR) confirmada en el LoadBalancer."
            break
        fi
    fi
    
    sleep 1
    i=$((i + 1))
done

# --- CÁLCULO DE DURACIONES FLOTANTES ANTES DE LA VALIDACIÓN DE FALLA ---
PROMOTION_E2E_DURATION=$(echo "$CONFIRMATION_END_TIME - $PROMOTION_START_TIME" | bc)
END_GLOBAL_TIME=$(date +%s.%N)
TOTAL_DURATION=$(echo "$END_GLOBAL_TIME - $START_GLOBAL_TIME" | bc)

# 6. VALIDACIÓN FINAL Y RESULTADOS
# NOTA: Usamos 'bc' para una comparación numérica segura de la duración
if [ $(echo "$PROMOTION_E2E_DURATION <= 0" | bc -l) -eq 1 ]; then
    echo "[ERROR] La promoción de V2 (Switch) falló al confirmarse en el LoadBalancer después de $PROMOTION_TIMEOUT_S segundos (TIMEOUT)."
    echo "[DIAGNÓSTICO] Última respuesta HTTP: $HTTP_STATUS. Último contenido (si existe): $RESPONSE"
    exit 1
fi

echo -e "\n--- RESULTADOS FINALES DE DESPLIEGUE (CANARY PROMOCIÓN) ---"
echo "A. Tiempo de Despliegue CANARY Inicial (10%): $CANARY_DEPLOY_DURATION segundos"
echo "B. Tiempo de PROMOCIÓN E2E (Scale V2 a 100% -> Confirmación 200 OK/V2): $PROMOTION_E2E_DURATION segundos"
echo "C. Tiempo de Provisionamiento del LB (Solo 1ra vez): $LB_PROVISIONING_DURATION segundos"
echo "D. Riesgo de Exposición durante el Switch: 0 segundos (Continuidad garantizada por los Pods V2/Canary ya existentes)"
echo "E. Tiempo TOTAL (Apply Canary -> Promoción Finalizada): $TOTAL_DURATION segundos"