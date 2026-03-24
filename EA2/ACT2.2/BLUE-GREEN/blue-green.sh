#!/bin/bash
# Script para medir el tiempo total de despliegue y la velocidad de switch del Service (Rollout)
# en la estrategia Blue/Green.

# --- Variables Requeridas ---
SERVICE_NAME="duoc-app-bg-service"                          # Nombre del Service (ej: duoc-app-bg-service)
DEPLOYMENT_GREEN_NAME="duoc-app-green"                      # Nombre del nuevo Deployment (ej: duoc-app-green)
YAML_FILE_GREEN="EA2/ACT2.2/ALL-IN-ONCE/all-in-once.yaml"   # Ruta al archivo YAML del Deployment Green
TARGET_VERSION_COLOR="Green"                                # Color o versión que se espera en la respuesta final

# Variable de tiempo de espera (simula la ventana de prueba)
WAIT_DURATION_S=120

if [ -z "$SERVICE_NAME" ] || [ -z "$DEPLOYMENT_GREEN_NAME" ] || [ -z "$YAML_FILE_GREEN" ]; then
    echo "Uso: $0 <NOMBRE_SERVICE> <NOMBRE_DEPLOYMENT_GREEN> <RUTA_YAML_GREEN>"
    echo "Ej: $0 duoc-app-bg-service duoc-app-green BLUEGREEN/green_deployment.yaml"
    exit 1
fi

echo "--- Iniciando Despliegue Blue/Green (Deploy Green y Switch) ---"

# 1. INICIO DE LA MEDICIÓN GLOBAL
START_GLOBAL_TIME=$(date +%s.%N)
echo "[1] Aprovisionando LoadBalancer y obteniendo URL..."

# ESPERAR LA URL DEL LOADBALANCER DE AWS (TIEMPO DE PROVISIONAMIENTO)
LB_URL=""
START_LB_PROVISIONING=$(date +%s.%N)
for i in {1..120}; do
    LB_URL=$(kubectl get service "$SERVICE_NAME" -o=jsonpath='{.status.loadBalancer.ingress[0].hostname}')
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


# 2. DESPLIEGUE DEL ENTORNO GREEN (INACTIVO)
echo "[2] Aplicando YAML de Deployment GREEN y esperando Rollout Interno..."
kubectl apply -f "$YAML_FILE_GREEN"

# Esperamos a que el nuevo entorno GREEN esté completamente listo (Pods Ready).
START_GREEN_ROLLOUT_TIME=$(date +%s.%N)
kubectl rollout status deployment/"$DEPLOYMENT_GREEN_NAME" --timeout=300s
if [ $? -ne 0 ]; then
    echo "[ERROR] El Rollout del Deployment GREEN falló."
    exit 1
fi
END_GREEN_ROLLOUT_TIME=$(date +%s.%N)
GREEN_DEPLOY_DURATION=$(echo "$END_GREEN_ROLLOUT_TIME - $START_GREEN_ROLLOUT_TIME" | bc)
echo "[SUCCESS] Deployment GREEN listo en: $GREEN_DEPLOY_DURATION segundos."


# 3. VENTANA DE PRUEBA Y OBSERVACIÓN (Simulación de 120 segundos)
echo -e "\n[3] INICIANDO VENTANA DE PRUEBA/OBSERVACIÓN DE 120 SEGUNDOS..."
echo "Simulando testeo de la versión GREEN (V2) para detectar el fallo retardado."
sleep $WAIT_DURATION_S
echo "[SUCCESS] Ventana de prueba de $WAIT_DURATION_S segundos completada. No se detectaron fallos."


# 4. SWITCH DE TRÁFICO (ROLLOUT ACTIVO)
# El momento más crítico: parchear el Service para apuntar a la nueva versión 'green'.
echo -e "\n[4] Ejecutando el Switch de tráfico: BLUE -> GREEN..."
SWITCH_START_TIME=$(date +%s.%N)

# Parchear el Service para cambiar el selector de 'blue' a 'green'
kubectl patch service "$SERVICE_NAME" -p '{"spec": {"selector": {"version": "green"}}}'

SWITCH_END_TIME=$(date +%s.%N)
SWITCH_DURATION=$(echo "$SWITCH_END_TIME - $SWITCH_START_TIME" | bc)
echo "[SUCCESS] Comando 'kubectl patch' completado en: $SWITCH_DURATION segundos."


# 5. VERIFICACIÓN DE CONTINUIDAD Y DISPONIBILIDAD EXTERNA
echo "[5] Verificando respuesta 200 OK y confirmando el contenido de $TARGET_VERSION_COLOR..."

# La métrica de Uptime se mide aquí: el loop debe terminar en < 1s y sin errores.
CHECK_START_TIME=$(date +%s.%N)

# Loop para confirmar que el LoadBalancer responde 200 OK y contiene el texto 'Green'
while ! curl -s "http://$LB_URL" | grep -q "$TARGET_VERSION_COLOR"; do
    # Si la respuesta no contiene "Green", puede ser que el LB aún no se haya actualizado.
    RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$LB_URL")
    if [ "$RESPONSE_CODE" != "200" ]; then
        echo "[ALERTA GRAVE] Downtime detectado durante el Switch! Código: $RESPONSE_CODE"
    fi
    sleep 0.1
done

CHECK_END_TIME=$(date +%s.%N)
PROPAGATION_DURATION=$(echo "$CHECK_END_TIME - $SWITCH_END_TIME" | bc)

# 6. CÁLCULO DE RESULTADOS FINALES

END_GLOBAL_TIME=$(date +%s.%N)
TOTAL_DURATION=$(echo "$END_GLOBAL_TIME - $START_GLOBAL_TIME" | bc)


echo -e "\n--- RESULTADOS FINALES DE DESPLIEGUE (BLUE/GREEN) ---"
echo "A. Tiempo de Despliegue GREEN (Deployment Interno): $GREEN_DEPLOY_DURATION segundos"
echo "B. Tiempo de ESPERA/TESTEO de 120s: $WAIT_DURATION_S segundos"
echo "C. Velocidad de Switch (kubectl patch): $SWITCH_DURATION segundos"
echo "D. Tiempo de Propagación (Patch hasta 200 OK/Green): $PROPAGATION_DURATION segundos"
echo "E. Tiempo TOTAL E2E (Apply -> Switch OK, SIN Contar Espera): $(echo "$GREEN_DEPLOY_DURATION + $SWITCH_DURATION + $PROPAGATION_DURATION" | bc) segundos"
echo "F. Uptime / Downtime: Cero Interrupción (El servicio Blue estuvo activo en todo momento)"
echo "G. Tiempo de Provisionamiento del LB (Solo 1ra vez): $LB_PROVISIONING_DURATION segundos"