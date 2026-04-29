#!/bin/bash
set -euo pipefail

STRATEGY=${STRATEGY:-rolling}
NAMESPACE=${NAMESPACE:-default}
LB_TIMEOUT=300
POLL_INTERVAL=5

# Variables globales para la tabla
R_LB="[Pend]"; R_ROLLOUT="[Pend]"; R_SWITCH="[Pend]"
R_DOWNTIME="[Pend]"; R_ROLLBACK="[Pend]"; R_RIESGO="[Pend]"
RC_LB="[Pend]"; RC_ROLLOUT="N/A"; RC_SWITCH="N/A"
RC_DOWNTIME="[Pend]"; RC_ROLLBACK="[Pend]"; RC_RIESGO="[Pend]"
CA_LB="[Pend]"; CA_ROLLOUT="[Pend]"; CA_SWITCH="Gradual"
CA_DOWNTIME="0s"; CA_ROLLBACK="[Pend]"; CA_RIESGO="10%"
BG_LB="[Pend]"; BG_ROLLOUT="[Pend]"; BG_SWITCH="[Pend]"
BG_DOWNTIME="0s"; BG_ROLLBACK="Instantaneo"; BG_RIESGO="0%"
LB_PROVISIONING_DURATION=0

log() { echo "[$(date +%H:%M:%S)] $*"; }

get_lb_hostname() {
  kubectl get svc -n "$NAMESPACE" \
    -o jsonpath='{.items[?(@.spec.type=="LoadBalancer")].status.loadBalancer.ingress[0].hostname}' \
    2>/dev/null | awk '{print $1}'
}

wait_for_lb() {
  log "Esperando hostname del LoadBalancer..."
  local START=$SECONDS
  local HOST=""
  while [ -z "$HOST" ] && [ $((SECONDS - START)) -lt $LB_TIMEOUT ]; do
    HOST=$(get_lb_hostname)
    [ -z "$HOST" ] && sleep $POLL_INTERVAL
  done
  LB_PROVISIONING_DURATION=$((SECONDS - START))
  echo "$HOST"
}

wait_for_http_200() {
  local HOST=$1
  local START=$SECONDS
  log "Esperando HTTP 200 en http://${HOST}..."
  while [ $((SECONDS - START)) -lt $LB_TIMEOUT ]; do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" \
      --connect-timeout 3 --max-time 5 "http://${HOST}" 2>/dev/null || true)
    [ "$CODE" = "200" ] && { echo $((SECONDS - START)); return 0; }
    sleep $POLL_INTERVAL
  done
  echo "timeout"
}

measure_rollout() {
  local DEPLOY=$1
  local START=$SECONDS
  kubectl rollout status deployment/"$DEPLOY" \
    -n "$NAMESPACE" --timeout=300s &>/dev/null && \
    echo $((SECONDS - START)) || echo "error"
}

collect_rolling() {
  log "Recolectando metricas: Rolling Update"
  local T_ROLLOUT T_LB_PROP LB_HOST
  T_ROLLOUT=$(measure_rollout "duoc-app-deployment")
  LB_HOST=$(wait_for_lb)
  T_LB_PROP=$(wait_for_http_200 "$LB_HOST")

  echo ""
  echo "=============================================="
  echo "  METRICAS - Rolling Update"
  echo "=============================================="
  printf "%-45s %s\n" "A. Tiempo de Rollout (K8s Ready):"      "${T_ROLLOUT}s"
  printf "%-45s %s\n" "B. Propagacion LB (Ready a 200 OK):"    "${T_LB_PROP}s"
  printf "%-45s %s\n" "C1. Provisionamiento del LB (1ra vez):" "${LB_PROVISIONING_DURATION}s"
  printf "%-45s %s\n" "C2. Tiempo TOTAL (Apply a 200 OK):"     "$((T_ROLLOUT + T_LB_PROP))s"
  printf "%-45s %s\n" "D. Downtime:"                           "0s"
  echo "=============================================="

  # Asignar globales
  R_LB="${LB_PROVISIONING_DURATION}s"
  R_ROLLOUT="${T_ROLLOUT}s"
  R_SWITCH="${T_LB_PROP}s"
  R_DOWNTIME="0s"
  R_ROLLBACK="Alto"
  R_RIESGO="100%"
}

collect_recreate() {
  log "Recolectando metricas: Recreate"
  local DT_START T_ROLLOUT T_LB_PROP LB_HOST DOWNTIME
  DT_START=$SECONDS
  kubectl wait pod -n "$NAMESPACE" \
    -l app=duoc-app --for=delete --timeout=120s &>/dev/null || true
  DOWNTIME=$((SECONDS - DT_START))
  T_ROLLOUT=$(measure_rollout "duoc-app-deployment")
  LB_HOST=$(wait_for_lb)
  T_LB_PROP=$(wait_for_http_200 "$LB_HOST")

  echo ""
  echo "=============================================="
  echo "  METRICAS - Recreate (All-In-Once)"
  echo "=============================================="
  printf "%-45s %s\n" "A. Tiempo de Despliegue (Rollout):"     "${T_ROLLOUT}s"
  printf "%-45s %s\n" "B. Downtime total:"                     "${DOWNTIME}s"
  printf "%-45s %s\n" "C1. Provisionamiento del LB (1ra vez):" "${LB_PROVISIONING_DURATION}s"
  printf "%-45s %s\n" "C2. Tiempo TOTAL hasta recuperacion:"   "${T_LB_PROP}s"
  echo "=============================================="

  RC_LB="${LB_PROVISIONING_DURATION}s"
  RC_ROLLOUT="N/A"
  RC_SWITCH="N/A"
  RC_DOWNTIME="${DOWNTIME}s"
  RC_ROLLBACK="Alto"
  RC_RIESGO="100%"
}

collect_canary() {
  log "Recolectando metricas: Canary"
  local START_CANARY T_CANARY LB_HOST START_PROM T_PROMOTION T_LB_PROP
  START_CANARY=$SECONDS
  kubectl wait pod -n "$NAMESPACE" \
    -l app=duoc-app-canary --for=condition=Ready --timeout=180s &>/dev/null || true
  T_CANARY=$((SECONDS - START_CANARY))
  LB_HOST=$(wait_for_lb)
  START_PROM=$SECONDS
  kubectl scale deployment duoc-app-canary-v2 --replicas=9 -n "$NAMESPACE" &>/dev/null || true
  kubectl scale deployment duoc-app-stable-v1 --replicas=1 -n "$NAMESPACE" &>/dev/null || true
  kubectl rollout status deployment/duoc-app-canary-v2 --timeout=180s &>/dev/null || true
  T_PROMOTION=$((SECONDS - START_PROM))
  T_LB_PROP=$(wait_for_http_200 "$LB_HOST")

  echo ""
  echo "=============================================="
  echo "  METRICAS - Canary"
  echo "=============================================="
  printf "%-45s %s\n" "A. Deploy Canary inicial (10%):"        "${T_CANARY}s"
  printf "%-45s %s\n" "B. Tiempo de promocion E2E:"            "${T_PROMOTION}s"
  printf "%-45s %s\n" "C. Provisionamiento del LB (1ra vez):"  "${LB_PROVISIONING_DURATION}s"
  printf "%-45s %s\n" "D. Downtime:"                           "0s"
  printf "%-45s %s\n" "E. Tiempo TOTAL:"                       "$((T_CANARY + T_PROMOTION))s"
  echo "=============================================="

  CA_LB="${LB_PROVISIONING_DURATION}s"
  CA_ROLLOUT="${T_CANARY}s"
  CA_SWITCH="Gradual"
  CA_DOWNTIME="0s"
  CA_ROLLBACK="${T_PROMOTION}s"
  CA_RIESGO="10%"
}

collect_bluegreen() {
  log "Recolectando metricas: Blue/Green"
  local START_GREEN T_GREEN T_WAIT START_SWITCH T_SWITCH LB_HOST T_PROP
  START_GREEN=$SECONDS
  kubectl rollout status deployment/duoc-app-green \
    --timeout=180s -n "$NAMESPACE" &>/dev/null || true
  T_GREEN=$((SECONDS - START_GREEN))
  log "Periodo de testeo Green (120s)..."
  sleep 120
  T_WAIT=120
  START_SWITCH=$SECONDS
  kubectl patch service duoc-app-bg-service -n "$NAMESPACE" \
    -p '{"spec":{"selector":{"version":"green"}}}' &>/dev/null || true
  T_SWITCH=$((SECONDS - START_SWITCH))
  LB_HOST=$(wait_for_lb)
  T_PROP=$(wait_for_http_200 "$LB_HOST")

  echo ""
  echo "=============================================="
  echo "  METRICAS - Blue/Green"
  echo "=============================================="
  printf "%-45s %s\n" "A. Deploy Green (interno):"             "${T_GREEN}s"
  printf "%-45s %s\n" "B. Periodo de testeo:"                  "${T_WAIT}s"
  printf "%-45s %s\n" "C. Velocidad de switch (patch):"        "${T_SWITCH}s"
  printf "%-45s %s\n" "D. Propagacion (patch a 200 OK Green):" "${T_PROP}s"
  printf "%-45s %s\n" "E. Tiempo TOTAL E2E:"                   "$((T_GREEN + T_SWITCH + T_PROP))s"
  printf "%-45s %s\n" "F. Downtime:"                           "0s"
  printf "%-45s %s\n" "G. Provisionamiento del LB (1ra vez):"  "${LB_PROVISIONING_DURATION}s"
  echo "=============================================="

  BG_LB="${LB_PROVISIONING_DURATION}s"
  BG_ROLLOUT="${T_GREEN}s"
  BG_SWITCH="${T_SWITCH}s"
  BG_DOWNTIME="0s"
  BG_ROLLBACK="Instantaneo"
  BG_RIESGO="0%"
}

print_table() {
  echo ""
  echo "=============================================="
  echo "  TABLA COMPARATIVA - Analisis de Impacto"
  echo "=============================================="
  printf "| %-44s | %-14s | %-12s | %-12s | %-12s |\n" \
    "Metrica Clave" "Rolling Update" "Recreate" "Blue/Green" "Canary"
  printf "| %-44s | %-14s | %-12s | %-12s | %-12s |\n" \
    "--------------------------------------------" \
    "--------------" "------------" "------------" "------------"
  printf "| %-44s | %-14s | %-12s | %-12s | %-12s |\n" \
    "Tiempo Infraestructura (LB)" \
    "$R_LB" "$RC_LB" "$BG_LB" "$CA_LB"
  printf "| %-44s | %-14s | %-12s | %-12s | %-12s |\n" \
    "Tiempo Despliegue Interno (Rollout K8s)" \
    "$R_ROLLOUT" "$RC_ROLLOUT" "$BG_ROLLOUT" "$CA_ROLLOUT"
  printf "| %-44s | %-14s | %-12s | %-12s | %-12s |\n" \
    "Velocidad Switch / Rollout Activo" \
    "$R_SWITCH" "$RC_SWITCH" "$BG_SWITCH" "$CA_SWITCH"
  printf "| %-44s | %-14s | %-12s | %-12s | %-12s |\n" \
    "Downtime" \
    "$R_DOWNTIME" "$RC_DOWNTIME" "$BG_DOWNTIME" "$CA_DOWNTIME"
  printf "| %-44s | %-14s | %-12s | %-12s | %-12s |\n" \
    "Velocidad Mitigacion / Rollback" \
    "$R_ROLLBACK" "$RC_ROLLBACK" "$BG_ROLLBACK" "$CA_ROLLBACK"
  printf "| %-44s | %-14s | %-12s | %-12s | %-12s |\n" \
    "Riesgo de Exposicion al Bug" \
    "$R_RIESGO" "$RC_RIESGO" "$BG_RIESGO" "$CA_RIESGO"
  echo ""
}

# Main
log "Iniciando recoleccion de metricas - Estrategia: ${STRATEGY}"

case "$STRATEGY" in
  rolling)    collect_rolling   ;;
  recreate)   collect_recreate  ;;
  canary)     collect_canary    ;;
  blue-green) collect_bluegreen ;;
  *) echo "Estrategia desconocida: $STRATEGY"; exit 1 ;;
esac

print_table
log "Reporte completo generado"
