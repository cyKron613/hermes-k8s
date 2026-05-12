# Hermes K8s Deployment

这个仓库提供一套用于在 Kubernetes 中运行 Hermes 的部署清单，包含以下组件：

- hermes-agent
- hermes-dashboard
- hermes-webui
- chrome sidecar（为浏览器自动化工具提供 CDP）
- 3 个 PVC，用于持久化 Hermes Home、agent 源码目录和 workspace

仓库定位是“部署模板和初始化脚本”，方便你在自己的集群里快速拉起 Hermes 运行环境，而不是 Hermes 本体源码仓库。

## 特性

- 单 Pod 多容器部署，组件之间通过 localhost 通信
- 独立 PVC 持久化配置、工作目录和 agent 代码
- 支持从本地现有 Hermes 环境向 PVC 同步数据
- 支持 WebUI、Dashboard、Agent 分别通过 NodePort 暴露
- 内置 Chrome sidecar，便于启用浏览器相关工具

## 仓库结构

- k8s-deployment-prod.yaml：主 Deployment 与 Service 清单
- k8s-pvc.yaml：PVC 定义
- k8s-seed-env-pod.yaml：用于把本地 Hermes 数据同步到 PVC 的辅助 Pod
- seed-pvc-via-pod.sh：将本地 HERMES_HOME / workspace 拷贝到 PVC
- Dockerfile.hermes-webui-prebuilt：构建预装依赖的 hermes-webui 镜像
- prod-deploy.sh：通用的本地构建脚本，可直接生成预构建 WebUI 镜像
- .env.example：辅助脚本需要的示例环境变量
- OPEN_SOURCE_RELEASE.md：发布到 GitHub 前的检查清单

## 运行前提

- 已有可用的 Kubernetes 集群
- 本机已安装 kubectl，并且当前 context 指向目标集群
- 目标命名空间已存在，或者你会先创建它
- 集群中存在可用的 StorageClass
- 你准备好了可用镜像，或使用公开镜像，或将本地镜像导入本地集群

## 关于镜像

这个仓库不要求你把镜像上传到自己的镜像仓库。

你有 3 种常见用法：

1. 直接改成公开镜像地址
2. 在本地构建镜像并导入 kind / minikube / k3d 这类本地集群
3. 保持你自己的私有镜像地址

示例上游镜像可参考：

- hermes-agent：nousresearch/hermes-agent:latest
- hermes-webui：ghcr.io/nesquena/hermes-webui:0.50.236
- chrome：browserless/chrome:latest

如果你不想推送镜像仓库，推荐做法是：

- 将 Deployment 中对应镜像改为你本地构建的标签
- 把 imagePullPolicy 调整为 IfNotPresent
- 使用本地集群提供的镜像导入命令

示例：

```bash
# kind
kind load docker-image hermes-webui-prebuilt:local

# minikube
minikube image load hermes-webui-prebuilt:local

# k3d
k3d image import hermes-webui-prebuilt:local -c <cluster-name>
```

## 使用前需要修改的配置

当前 YAML 使用的是通用默认值，部署前请至少检查这些内容：

- namespace，例如 hermes
- storageClassName，例如 standard
- 所有镜像地址
- NodePort 端口，避免与现有服务冲突
- 资源 requests / limits，根据你的集群容量调整
- 如果你不需要 Dashboard 或 Chrome，可自行裁剪容器定义

## 快速开始

### 1. 创建命名空间

```bash
kubectl create namespace hermes
```

如果你不想使用 hermes 作为命名空间，请把所有 YAML 里的 namespace 一并改掉。

### 2. 调整 PVC

编辑 k8s-pvc.yaml：

- 修改 namespace
- 修改 storageClassName
- 按需调整容量

应用 PVC：

```bash
kubectl apply -f k8s-pvc.yaml
kubectl get pvc -n hermes
```

### 3. 调整 Deployment

编辑 k8s-deployment-prod.yaml：

- 修改 namespace
- 替换镜像地址
- 如果使用本地镜像，改成 IfNotPresent
- 按需修改 NodePort
- 按需修改资源配置

应用部署：

```bash
kubectl apply -f k8s-deployment-prod.yaml
kubectl rollout status deployment/hermes-stack -n hermes
```

### 4. 访问服务

默认暴露如下端口：

- hermes-agent：8642，对应 NodePort 30642
- hermes-dashboard：9119，对应 NodePort 31119
- hermes-webui：8787，对应 NodePort 31787

查看实际服务：

```bash
kubectl get svc -n hermes
```

## 从本地 Hermes 环境初始化 PVC

如果你本地已经有可用的 Hermes Home 和 workspace，可以直接同步到 PVC。

### 1. 准备本地目录

seed-pvc-via-pod.sh 默认会读取当前目录下的 .env，并从其中解析：

- HERMES_HOME
- HERMES_WEBUI_DEFAULT_WORKSPACE
- NAMESPACE 或 K8S_NAMESPACE

本地 HERMES_HOME 目录至少需要包含：

- .env
- config.yaml

### 2. 检查辅助 Pod 清单

根据你的环境修改 k8s-seed-env-pod.yaml 中的：

- namespace
- 镜像地址

### 3. 执行同步

```bash
bash seed-pvc-via-pod.sh
```

脚本会自动完成这些步骤：

1. 创建或更新辅助 Pod
2. 将本地 HERMES_HOME 拷贝到 hermes-home PVC
3. 将本地 workspace 拷贝到 hermes-workspace PVC
4. 重启 hermes-stack Deployment
5. 等待 Deployment 就绪

## 构建 hermes-webui-prebuilt

如果你想减少容器启动时在线安装依赖，可以使用仓库中的 Dockerfile 构建一个预装依赖的 WebUI 镜像。

```bash
docker build -f Dockerfile.hermes-webui-prebuilt -t hermes-webui-prebuilt:local .
```

Dockerfile 当前默认使用公开基础镜像。你也可以通过 build-arg 覆盖为自己测试过的镜像版本。

示例：

```bash
docker build \
	-f Dockerfile.hermes-webui-prebuilt \
	--build-arg HERMES_WEBUI_BASE=ghcr.io/nesquena/hermes-webui:0.50.236 \
	--build-arg HERMES_AGENT_BASE=nousresearch/hermes-agent:latest \
	-t hermes-webui-prebuilt:local \
	.
```

## 常用排查命令

```bash
NS=hermes

kubectl -n $NS get pods -o wide
kubectl -n $NS get pods -w
kubectl -n $NS get deploy
kubectl -n $NS rollout status deployment/hermes-stack
kubectl -n $NS get svc
kubectl -n $NS get pvc

POD=$(kubectl -n $NS get pod -l app=hermes -o jsonpath='{.items[0].metadata.name}')

kubectl -n $NS describe pod $POD
kubectl -n $NS logs deployment/hermes-stack -c hermes-agent --tail=200
kubectl -n $NS logs deployment/hermes-stack -c hermes-dashboard --tail=200
kubectl -n $NS logs deployment/hermes-stack -c hermes-webui --tail=200
kubectl -n $NS logs deployment/hermes-stack -c chrome --tail=200
```

## Chrome CDP 检查

浏览器工具依赖 chrome sidecar 提供的 CDP 端口。默认通过 http://127.0.0.1:9222 连接。

检查方法：

```bash
NS=hermes
POD=$(kubectl -n $NS get pod -l app=hermes -o jsonpath='{.items[0].metadata.name}')

kubectl -n $NS exec $POD -c hermes-agent -- sh -lc 'echo CHROME_CDP_URL=$CHROME_CDP_URL'
kubectl -n $NS exec $POD -c hermes-agent -- sh -lc 'if command -v curl >/dev/null 2>&1; then curl -fsS http://127.0.0.1:9222/json/version; elif command -v wget >/dev/null 2>&1; then wget -qO- http://127.0.0.1:9222/json/version; else /opt/hermes/.venv/bin/python -c "import urllib.request; print(urllib.request.urlopen(\"http://127.0.0.1:9222/json/version\", timeout=5).read().decode())"; fi'
```

如果返回结果中包含 HeadlessChrome 和 webSocketDebuggerUrl，说明 CDP 正常可用。

## 开源发布前建议

正式开源前建议至少做一次完整检查：

- 搜索是否仍残留 token、内网域名或私有地址
- 根据你的集群修改命名空间、存储类和 NodePort
- 验证本地镜像导入流程是否可用
- 检查 .env 没有被提交，只保留 .env.example
- 按需补充截图、版本说明和变更记录

更细的发布前检查见 OPEN_SOURCE_RELEASE.md。

## License

仓库当前附带 MIT License。如需更严格的专利授权或 copyleft 约束，可改为 Apache-2.0 或 GPL-3.0。