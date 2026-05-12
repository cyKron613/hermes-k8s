#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${IMAGE_TAG:-local}"
WEBUI_IMAGE="${WEBUI_IMAGE:-hermes-webui-prebuilt:${IMAGE_TAG}}"
HERMES_WEBUI_BASE="${HERMES_WEBUI_BASE:-ghcr.io/nesquena/hermes-webui:0.50.236}"
HERMES_AGENT_BASE="${HERMES_AGENT_BASE:-nousresearch/hermes-agent:latest}"

docker build \
	-f Dockerfile.hermes-webui-prebuilt \
	--build-arg HERMES_WEBUI_BASE="${HERMES_WEBUI_BASE}" \
	--build-arg HERMES_AGENT_BASE="${HERMES_AGENT_BASE}" \
	-t "${WEBUI_IMAGE}" \
	.

cat <<EOF
[DONE] Built image: ${WEBUI_IMAGE}

If you are using a local Kubernetes cluster, import the image instead of pushing it:
	kind load docker-image ${WEBUI_IMAGE}
	minikube image load ${WEBUI_IMAGE}
	k3d image import ${WEBUI_IMAGE} -c <cluster-name>

If you use a remote registry, tag and push it yourself:
	docker tag ${WEBUI_IMAGE} <your-registry>/hermes-webui-prebuilt:${IMAGE_TAG}
	docker push <your-registry>/hermes-webui-prebuilt:${IMAGE_TAG}
EOF