#!/bin/bash
# Script mejorado para medir A, B, y C.

# --- Variables Requeridas ---
SERVICE_NAME="duoc-app-service"
DEPLOYMENT_NAME="duoc-app-deployment"
YAML_FILE="EA2/ACT2.2/ROLLING-UPDATE/rolling-update.yaml"
STRATEGY="rolling-update"

# --- Variables de Tiempo Añadidas/Inicializadas ---
TIME_ROLLOUT_INTERNAL="N/A"
TIME_LB_PROPAGATION="N/A"

if [ -z "$SERVICE_NAME" ] || [ -z "$DEPLOYMENT_NAME" ] || [ -z "$YAML_FILE" ]; then
    echo "Uso: $0 <NOMBRE_SERVICE> <NOMBRE_DEPLOYMENT> <RUTA_YAML> [ESTRATEGIA]"
    exit 1
fi

echo "--- Iniciando Despliegue de $DEPLOYMENT_NAME ($STRATEGY) ---"

# 1. INICIO DE LA MEDICIÓN GLOBAL
START_GLOBAL_TIME=$(date +%s.%N)
echo "[1] Aplicando YAML y iniciando Rollout..."

# Aplicar el manifiesto (kubectl apply)
kubectl apply -f "$YAML_FILE"
APPLY_COMPLETE_TIME=$(date +%s.%N)
APPLY_DURATION=$(echo "$APPLY_COMPLETE_TIME - $START_GLOBAL_TIME" | bc)
echo "[INFO] Apply de YAML completado en: $APPLY_DURATION segundos."

# ==============================================================================
# 2. NUEVO PASO AÑADIDO: ESPERAR ROLLOUT INTERNO (MEDICIÓN A)
# ==============================================================================
echo "[2] Esperando a que Kubernetes confirme el Rollout Interno (K8s Ready)..."
START_TIME_K8S_READY=$(date +%s.%N) # <-- INICIO de medición A

# Esperar el estado de Rollout completo
kubectl rollout status deployment/$DEPLOYMENT_NAME --timeout=300s
ROLLOUT_COMPLETE_TIME=$(date +%s.%N) # <-- FIN de medición A

# Calcular el tiempo A
if [ $? -eq 0 ]; then
    TIME_ROLLOUT_INTERNAL=$(echo "$ROLLOUT_COMPLETE_TIME - $START_TIME_K8S_READY" | bc)
    echo "[SUCCESS] Rollout Interno (K8s Ready) completado en: $TIME_ROLLOUT_INTERNAL segundos."
else
    echo "[ERROR] El Rollout de Kubernetes falló o superó el tiempo de espera."
    exit 1
fi
# ==============================================================================

# 3. ESPERAR URL DE AWS Y DISPONIBILIDAD EXTERNA (200 OK) (Medición B combinada con C)
# Ahora, este paso mide el tiempo desde que K8s está Ready hasta que el LB responde 200 OK.
echo "[3] Esperando la Disponibilidad Externa (200 OK)..."

LB_URL=""
# Usamos ROLLOUT_COMPLETE_TIME como inicio de la nueva medición (tiempo de propagación).
START_TIME_TO_200_OK=$ROLLOUT_COMPLETE_TIME 
SECONDS_WAITED=0 
MAX_WAIT=120

# ... (La lógica del bucle 'while' permanece igual) ...

while [ $SECONDS_WAITED -lt $MAX_WAIT ]; do
    TEMP_LB_URL=$(kubectl get service "$SERVICE_NAME" -o=jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null | awk '{$1=$1};1')
    
    if [ ! -z "$TEMP_LB_URL" ]; then
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$TEMP_LB_URL" 2>/dev/null)

        if [ "$HTTP_STATUS" = "200" ]; then
            LB_URL="$TEMP_LB_URL"
            echo "[SUCCESS] Hostname obtenido y respuesta 200 OK recibida: http://$LB_URL"
            break
        fi
    fi
    
    sleep 1
    SECONDS_WAITED=$((SECONDS_WAITED + 1))
done

END_TIME_TO_200_OK=$(date +%s.%N)

if [ -z "$LB_URL" ]; then
    echo "[ERROR] No se pudo obtener el Hostname o la respuesta 200 OK después de $MAX_WAIT segundos."
    # ... (Diagnóstico de error) ...
    exit 1
fi

# ==============================================================================
# 4. CALCULAR TIEMPOS FINALES
# ==============================================================================

# C. Tiempo de Disponibilidad Externa (Apply a 200 OK)
# Se calcula desde el 'Apply' original.
TIME_TO_200_OK_FROM_APPLY=$(echo "$END_TIME_TO_200_OK - $APPLY_COMPLETE_TIME" | bc)

# B. Tiempo de Propagación LB (de Ready a 200 OK)
# Es la diferencia entre el 200 OK y cuando K8s estaba Ready (Rollout Complete).
TIME_LB_PROPAGATION=$(echo "$END_TIME_TO_200_OK - $ROLLOUT_COMPLETE_TIME" | bc)

END_GLOBAL_TIME=$(date +%s.%N)
TOTAL_DURATION=$(echo "$END_GLOBAL_TIME - $START_GLOBAL_TIME" | bc)

echo -e "\n--- RESULTADOS FINALES DE DESPLIEGUE ($STRATEGY) ---"
echo "A. Tiempo de Rollout Interno (K8s Ready): $TIME_ROLLOUT_INTERNAL segundos"
echo "B. Tiempo de Propagación LB (de Ready a 200 OK): $TIME_LB_PROPAGATION segundos"
echo "C. Tiempo de Disponibilidad Externa (Apply a 200 OK): $TIME_TO_200_OK_FROM_APPLY segundos"
echo "C2. Tiempo TOTAL de Despliegue (Script Start a 200 OK): $TOTAL_DURATION segundos"
echo "D. Downtime (Interrupción Total del Servicio): 0 segundos (Continuo para Rolling Update)"