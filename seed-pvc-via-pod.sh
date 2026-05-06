#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/.env}"
SEED_POD_YAML="${SEED_POD_YAML:-$SCRIPT_DIR/k8s-seed-env-pod.yaml}"

[ -f "$ENV_FILE" ] || { echo "[ERROR] env file not found: $ENV_FILE" >&2; exit 1; }
[ -f "$SEED_POD_YAML" ] || { echo "[ERROR] seed pod yaml not found: $SEED_POD_YAML" >&2; exit 1; }

while IFS= read -r line || [[ -n "$line" ]]; do
  case "$line" in
    ''|\#*) continue ;;
  esac
  if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    value="${value%$'\r'}"
    case "$value" in
      \"*\") value="${value:1:${#value}-2}" ;;
      \'*\') value="${value:1:${#value}-2}" ;;
    esac
    case "$key" in UID|EUID|PPID|SHELLOPTS|BASHOPTS) continue ;; esac
    printf -v "$key" '%s' "$value"
    export "$key"
  fi
done < "$ENV_FILE"

NAMESPACE="${NAMESPACE:-${K8S_NAMESPACE:-hermes}}"
POD="${POD:-hermes-seed-env}"
CONTAINER="${CONTAINER:-seed-env}"
DEPLOYMENT_NAME="${K8S_DEPLOYMENT:-hermes-stack}"
LOCAL_HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
LOCAL_WORKSPACE="${HERMES_WEBUI_DEFAULT_WORKSPACE:-$HOME/workspace}"
REMOTE_HERMES_HOME="${REMOTE_HERMES_HOME:-/home/hermes/.hermes}"
REMOTE_WORKSPACE="${REMOTE_WORKSPACE:-/home/hermes/workspace}"

[ -d "$LOCAL_HERMES_HOME" ] || { echo "[ERROR] local HERMES_HOME not found: $LOCAL_HERMES_HOME" >&2; exit 1; }
[ -f "$LOCAL_HERMES_HOME/.env" ] || { echo "[ERROR] local .env not found: $LOCAL_HERMES_HOME/.env" >&2; exit 1; }
[ -f "$LOCAL_HERMES_HOME/config.yaml" ] || { echo "[ERROR] local config.yaml not found: $LOCAL_HERMES_HOME/config.yaml" >&2; exit 1; }

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[ERROR] kubectl not found" >&2
  exit 1
fi

echo "[STEP] create/update seed pod"
kubectl -n "$NAMESPACE" delete pod "$POD" --ignore-not-found=true
kubectl apply -f "$SEED_POD_YAML"
kubectl -n "$NAMESPACE" wait --for=condition=Ready pod/"$POD" --timeout=180s

echo "[STEP] copy full HERMES_HOME to hermes-home PVC"
kubectl -n "$NAMESPACE" cp --no-preserve "$LOCAL_HERMES_HOME/." "$POD:$REMOTE_HERMES_HOME" -c "$CONTAINER"

if [[ -d "$LOCAL_WORKSPACE" ]]; then
  echo "[STEP] copy full workspace to hermes-workspace PVC"
  kubectl -n "$NAMESPACE" cp --no-preserve "$LOCAL_WORKSPACE/." "$POD:$REMOTE_WORKSPACE" -c "$CONTAINER"
else
  echo "[WARN] local workspace not found, skip: $LOCAL_WORKSPACE"
fi

echo "[STEP] verify copied files"
kubectl -n "$NAMESPACE" exec "$POD" -c "$CONTAINER" -- sh -c "ls -la '$REMOTE_HERMES_HOME' | head && test -f '$REMOTE_HERMES_HOME/.env' && test -f '$REMOTE_HERMES_HOME/config.yaml'"

echo "[STEP] restart deployment and wait"
kubectl -n "$NAMESPACE" rollout restart deployment/"$DEPLOYMENT_NAME"
kubectl -n "$NAMESPACE" rollout status deployment/"$DEPLOYMENT_NAME" --timeout=240s

echo "[DONE] PVC seed completed via $POD"
echo "[INFO] keep seed pod for inspection; delete it with: kubectl -n $NAMESPACE delete pod $POD"
