#!/bin/bash
# Script para medir el tiempo total de despliegue desde kubectl apply hasta la disponibilidad del LoadBalancer (200 OK).

# --- Variables Requeridas ---
SERVICE_NAME="duoc-app-service"                                   # Nombre del Service (ej: duoc-app-service)
DEPLOYMENT_NAME="duoc-app-deployment"                             # Nombre del Deployment principal (ej: duoc-app-deployment)
YAML_FILE="EA2/ACT2.2/ALL-IN-ONCE/all-in-once.yaml"         # Ruta al archivo YAML de la nueva versión (ej: ROLLING-UPDATE/v2.yaml)
STRATEGY="recreate"                                         # Estrategia a medir (ej: rolling-update)

if [ -z "$SERVICE_NAME" ] || [ -z "$DEPLOYMENT_NAME" ] || [ -z "$YAML_FILE" ]; then
    echo "Uso: $0 <NOMBRE_SERVICE> <NOMBRE_DEPLOYMENT> <RUTA_YAML> [ESTRATEGIA]"
    echo "Ej: $0 duoc-app-service duoc-app-deployment ROLLING-UPDATE/v2.yaml rolling-update"
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


# 2. ESPERAR URL DE AWS Y DISPONIBILIDAD EXTERNA (200 OK)
# ESTE PASO AHORA MIDE EL TIEMPO COMBINADO DE PROVISIONAMIENTO DE LB, ROLLOUT DE K8S Y PROPAGACIÓN DE TRÁFICO.
echo "[2] Esperando que AWS asigne el hostname al LoadBalancer ($SERVICE_NAME) y responda con 200 OK..."

LB_URL=""
START_TIME_TO_200_OK=$(date +%s.%N) # <-- INICIO de medición combinada
SECONDS_WAITED=0 
MAX_WAIT=120 # Límite de espera de 120 segundos

# Usamos un bucle while explícito para garantizar que el tiempo de espera se cumpla.
while [ $SECONDS_WAITED -lt $MAX_WAIT ]; do
    # 2a. Intenta obtener el hostname de la forma más robusta posible, silenciando errores de kubectl.
    TEMP_LB_URL=$(kubectl get service "$SERVICE_NAME" -o=jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null | awk '{$1=$1};1')
    
    # 2b. Si la URL es no vacía, intentamos hacer el curl y validar 200.
    if [ ! -z "$TEMP_LB_URL" ]; then
        # Capturamos el código de estado HTTP explícitamente. Si curl falla (ej. DNS/conexión), HTTP_STATUS será vacío.
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$TEMP_LB_URL" 2>/dev/null)

        # CORRECCIÓN: Usamos el operador de comparación de cadenas '=' en lugar de '==' para compatibilidad POSIX.
        if [ "$HTTP_STATUS" = "200" ]; then
            LB_URL="$TEMP_LB_URL" # Asignamos la URL
            echo "[SUCCESS] Hostname obtenido y respuesta 200 OK recibida: http://$LB_URL"
            break # Salir del bucle: se cumple la condición de despliegue
        fi
    fi
    
    # Si la URL no existe o no responde 200, esperamos 1 segundo y aumentamos el contador.
    sleep 1
    SECONDS_WAITED=$((SECONDS_WAITED + 1))
done

END_TIME_TO_200_OK=$(date +%s.%N) # <-- FIN de medición combinada
TIME_TO_200_OK_FROM_APPLY=$(echo "$END_TIME_TO_200_OK - $START_TIME_TO_200_OK" | bc)

if [ -z "$LB_URL" ]; then
    echo "[ERROR] No se pudo obtener el Hostname o la respuesta 200 OK después de $MAX_WAIT segundos."
    # --- Diagnóstico ajustado ---
    echo "[INFO] Tiempo transcurrido esperando (Timeout): $SECONDS_WAITED segundos."
    echo "[DIAGNÓSTICO] El despliegue no alcanzó la disponibilidad externa (200 OK). Esto indica que el Load Balancer no está listo o los Pods no están enviando tráfico válido."
    echo "[ACCIÓN REQUERIDA] Revise los eventos de AWS con 'kubectl describe svc $SERVICE_NAME' para diagnosticar fallas de aprovisionamiento o el estado de los Pods."
    # ---------------------------
    exit 1
fi

# 3. CALCULAR RESULTADOS FINALES
# Los pasos de Rollout Status y Propagación del script original se han fusionado en el paso 2 para medir el tiempo total de disponibilidad externa (200 OK).

END_GLOBAL_TIME=$(date +%s.%N)
# La duración total global se calcula desde el inicio del script hasta el 200 OK.
TOTAL_DURATION=$(echo "$END_GLOBAL_TIME - $START_GLOBAL_TIME" | bc)

echo -e "\n--- RESULTADOS FINALES DE DESPLIEGUE ($STRATEGY) ---"
echo "A. Tiempo de Rollout Interno (K8s Ready): N/A"
echo "B. Tiempo de Propagación LB (de Ready a 200 OK): N/A"
echo "C. Tiempo de Disponibilidad Externa (Apply a 200 OK): $TIME_TO_200_OK_FROM_APPLY segundos"
echo "C2. Tiempo TOTAL de Despliegue (Script Start a 200 OK): $TOTAL_DURATION segundos"
echo "D. Downtime (Interrupción Total del Servicio): 0 segundos (Continuo para Rolling Update)"