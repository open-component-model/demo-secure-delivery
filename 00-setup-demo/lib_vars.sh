#!/bin/bash
# libary function vars
# Version: v1.0.0
# Author: Piaras Hoban <piaras@weave.works>

SIGNING_KEY_NAME=ocm-signing

SSH_KEY_NAME=ocm-private-demo-key
SSH_KEY_PATH=$HOME/.ssh/$SSH_KEY_NAME

os=$(uname -s)

tools=(helm flux kind jq kubectl ocm mkcert tea git curl docker gzip)

images=(
ghcr.io/phoban01/podinfo:6.3.6-static
ghcr.io/fluxcd/helm-controller:v0.33.0
ghcr.io/fluxcd/kustomize-controller:v1.0.0-rc.3
ghcr.io/fluxcd/notification-controller:v1.0.0-rc.3
ghcr.io/fluxcd/source-controller:v1.0.0-rc.3
gitea/gitea:1.19.3
registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20230312-helm-chart-4.5.2-28-g66a760794@sha256:01d181618f270f2a96c04006f33b2699ad3ccb02da48d0f89b22abce084b292f
registry.k8s.io/ingress-nginx/controller:v1.7.1@sha256:7244b95ea47bddcb8267c1e625fb163fc183ef55448855e3ac52a7b260a60407
registry.k8s.io/coredns/coredns:v1.10.1
registry.k8s.io/etcd:3.5.7-0
docker.io/kindest/kindnetd:v20230511-dc714da8
registry.k8s.io/kube-apiserver:v1.27.1
registry.k8s.io/kube-controller-manager:v1.27.1
registry.k8s.io/kube-proxy:v1.27.1
registry.k8s.io/kube-scheduler:v1.27.1
docker.io/kindest/local-path-provisioner:v20230511-dc714da8
ghcr.io/open-component-model/ocm-controller:v0.8.1
ghcr.io/open-component-model/replication-controller:v0.2.0
registry:2
)

preloadimages=(
ghcr.io/phoban01/podinfo:6.3.6-static
ghcr.io/fluxcd/helm-controller:v0.33.0
ghcr.io/fluxcd/kustomize-controller:v1.0.0-rc.3
ghcr.io/fluxcd/notification-controller:v1.0.0-rc.3
ghcr.io/fluxcd/source-controller:v1.0.0-rc.3
gitea/gitea:1.19.3
registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20230312-helm-chart-4.5.2-28-g66a760794@sha256:01d181618f270f2a96c04006f33b2699ad3ccb02da48d0f89b22abce084b292f
registry.k8s.io/ingress-nginx/controller:v1.7.1@sha256:7244b95ea47bddcb8267c1e625fb163fc183ef55448855e3ac52a7b260a60407
registry.k8s.io/coredns/coredns:v1.10.1
docker.io/kindest/local-path-provisioner:v20230511-dc714da8
ghcr.io/open-component-model/ocm-controller:v0.8.1
ghcr.io/open-component-model/replication-controller:v0.2.0
registry:2
)

declare -A install_instructions
install_instructions["helm_mac"]="brew install helm"
install_instructions["flux_mac"]="brew install fluxcd/tap/flux"
install_instructions["kind_mac"]="brew install kind"
install_instructions["kubectl_mac"]="brew install kubectl"
install_instructions["jq_mac"]="brew install jq"
install_instructions["git_mac"]="brew install git"
install_instructions["curl_mac"]="brew install curl"
install_instructions["docker_mac"]="brew install docker"
install_instructions["gzip_mac"]="brew install gzip"
install_instructions["ocm_mac"]="brew install open-component-model/tap/ocm"
install_instructions["mkcert"]=" brew install mkcert"
install_instructions["tea_mac"]="brew tap gitea/tap https://gitea.com/gitea/homebrew-gitea && brew install tea"

