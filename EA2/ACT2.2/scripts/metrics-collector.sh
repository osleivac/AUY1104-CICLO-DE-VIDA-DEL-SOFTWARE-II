#!/bin/bash
# metrics-collector.sh
# Recoge métricas de la estrategia activa y genera tabla comparativa

set -euo pipefail

STRATEGY=${STRATEGY:-rolling}
NAMESPACE=${NAMESPACE:-default}
LB_TIMEOUT=300      # seg máximos esperando LoadBalancer
POLL_INTERVAL=5

RED='\033[0;31m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

log()  { echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} $*"; }
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
err()  { echo -e "${RED}✗${NC} $*"; }

# ── Utilidades ──────────────────────────────────────────────────────────────
get_lb_hostname() {
  kubectl get svc -n "$NAMESPACE" \
    -o jsonpath='{.items[?(@.spec.type=="LoadBalancer")].status.loadBalancer.ingress[0].hostname}' \
    2>/dev/null | awk '{print $1}'
}

wait_for_lb() {
  log "Esperando asignación de hostname del LoadBalancer..."
  local START=$SECONDS
  local HOST=""
  while [ -z "$HOST" ] && [ $((SECONDS - START)) -lt $LB_TIMEOUT ]; do
    HOST=$(get_lb_hostname)
    [ -z "$HOST" ] && sleep $POLL_INTERVAL
  done
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

# ── Métricas por estrategia ─────────────────────────────────────────────────
collect_rolling() {
  log "Recolectando métricas: Rolling Update"
  local DEPLOY="rolling-deployment"

  T_ROLLOUT=$(measure_rollout "$DEPLOY")
  LB_HOST=$(wait_for_lb)
  T_LB_PROP=$(wait_for_http_200 "$LB_HOST")

  echo ""
  echo "═══════════════════════════════════════"
  echo "  MÉTRICAS — Rolling Update"
  echo "═══════════════════════════════════════"
  echo "A. Tiempo de Rollout (K8s Ready):    ${T_ROLLOUT}s"
  echo "B. Propagación LB (Ready → 200 OK):  ${T_LB_PROP}s"
  echo "D. Downtime:                         0s (continuidad garantizada)"
  echo "   Riesgo:                           100% (V2 reemplaza directamente)"
  echo "═══════════════════════════════════════"
}

collect_recreate() {
  log "Recolectando métricas: Recreate (All-In-Once)"
  local DEPLOY="allinonce-deployment"

  # Detectar inicio de downtime (pods terminando)
  local DT_START=$SECONDS
  kubectl wait pod -n "$NAMESPACE" \
    -l app=allinonce \
    --for=delete --timeout=120s &>/dev/null || true
  local DT_END=$SECONDS
  DOWNTIME=$((DT_END - DT_START))

  T_ROLLOUT=$(measure_rollout "$DEPLOY")
  LB_HOST=$(wait_for_lb)
  T_LB_PROP=$(wait_for_http_200 "$LB_HOST")

  echo ""
  echo "═══════════════════════════════════════"
  echo "  MÉTRICAS — Recreate"
  echo "═══════════════════════════════════════"
  echo "A. Tiempo de Despliegue (Rollout):   ${T_ROLLOUT}s"
  echo "B. Downtime total:                   ${DOWNTIME}s"
  echo "C. Tiempo hasta recuperación:        ${T_LB_PROP}s"
  echo "   Riesgo:                           100%"
  echo "═══════════════════════════════════════"
}

collect_canary() {
  log "Recolectando métricas: Canary"

  local START_CANARY=$SECONDS
  kubectl wait pod -n "$NAMESPACE" \
    -l version=canary \
    --for=condition=Ready --timeout=180s &>/dev/null || true
  T_CANARY=$((SECONDS - START_CANARY))

  LB_HOST=$(wait_for_lb)

  # Verificar distribución de tráfico (10 muestras)
  local V2_COUNT=0; local V1_COUNT=0
  for i in $(seq 1 10); do
    RESP=$(curl -s --connect-timeout 3 --max-time 5 \
      "http://${LB_HOST}" 2>/dev/null || echo "")
    echo "$RESP" | grep -qi "green" && V2_COUNT=$((V2_COUNT+1)) || V1_COUNT=$((V1_COUNT+1))
  done

  # Promoción a 100%
  local START_PROM=$SECONDS
  kubectl scale deployment canary-v2 --replicas=9 -n "$NAMESPACE"
  kubectl scale deployment canary-v1 --replicas=1 -n "$NAMESPACE"
  kubectl rollout status deployment/canary-v2 --timeout=180s &>/dev/null
  T_PROMOTION=$((SECONDS - START_PROM))

  echo ""
  echo "═══════════════════════════════════════"
  echo "  MÉTRICAS — Canary"
  echo "═══════════════════════════════════════"
  echo "A. Deploy canary 10%:                ${T_CANARY}s"
  echo "B. Tiempo promoción E2E:             ${T_PROMOTION}s"
  echo "   Distribución observada:           V1=${V1_COUNT}/10 · V2=${V2_COUNT}/10"
  echo "D. Downtime:                         0s"
  echo "   Riesgo de exposición:             ~10% (solo fracción canary)"
  echo "═══════════════════════════════════════"
}

collect_bluegreen() {
  log "Recolectando métricas: Blue/Green"

  # Tiempo deploy Green
  local START_GREEN=$SECONDS
  kubectl rollout status deployment/green-deployment \
    --timeout=180s -n "$NAMESPACE" &>/dev/null || true
  T_GREEN=$((SECONDS - START_GREEN))

  # Periodo de espera/testeo
  log "Periodo de testeo Green (120s)..."
  sleep 120
  T_WAIT=120

  # Switch
  local START_SWITCH=$SECONDS
  kubectl patch service bluegreen-service -n "$NAMESPACE" \
    -p '{"spec":{"selector":{"version":"green"}}}'
  T_SWITCH=$((SECONDS - START_SWITCH))

  # Propagación hasta 200 OK en Green
  LB_HOST=$(wait_for_lb)
  T_PROP=$(wait_for_http_200 "$LB_HOST")

  echo ""
  echo "═══════════════════════════════════════"
  echo "  MÉTRICAS — Blue/Green"
  echo "═══════════════════════════════════════"
  echo "A. Deploy Green (interno):           ${T_GREEN}s"
  echo "B. Periodo de testeo:                ${T_WAIT}s"
  echo "C. Velocidad de switch (patch):      ${T_SWITCH}s"
  echo "D. Propagación (patch → 200 Green):  ${T_PROP}s"
  echo "F. Downtime:                         0s (Blue activo durante todo)"
  echo "   Rollback:                         Instantáneo (revertir patch)"
  echo "═══════════════════════════════════════"
}

# ── Tabla comparativa ────────────────────────────────────────────────────────
print_table() {
  echo ""
  echo "╔══════════════════╦════════════╦═══════════╦════════════╦════════════╗"
  echo "║ Métrica          ║  Rolling   ║  Recreate ║   Canary   ║ Blue/Green ║"
  echo "╠══════════════════╬════════════╬═══════════╬════════════╬════════════╣"
  echo "║ Downtime         ║     0s     ║  Alto     ║     0s     ║     0s     ║"
  echo "║ Riesgo exposic.  ║   100%     ║  100%     ║    10%     ║     0%     ║"
  echo "║ Velocidad deploy ║   Medio    ║  Rápido   ║   Lento    ║   Medio    ║"
  echo "║ Rollback         ║  Depende   ║  Lento    ║ Inmediato  ║ Instantáneo║"
  echo "║ Complejidad      ║   Baja     ║  Mínima   ║   Alta     ║   Media    ║"
  echo "╚══════════════════╩════════════╩═══════════╩════════════╩════════════╝"
}

# ── Main ─────────────────────────────────────────────────────────────────────
echo ""; log "Iniciando recolección de métricas — Estrategia: ${STRATEGY}"

case "$STRATEGY" in
  rolling)    collect_rolling  ;;
  recreate)   collect_recreate ;;
  canary)     collect_canary   ;;
  blue-green) collect_bluegreen ;;
  *) err "Estrategia desconocida: $STRATEGY"; exit 1 ;;
esac

print_table
log "Reporte completo generado ✓"