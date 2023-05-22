#!/bin/bash

# libary function vars
# Version: v1.0.0
# Author: Piaras Hoban <piaras@weave.works>

SSH_KEY_NAME=aws-demo-key
SSH_KEY_PATH=$HOME/.ssh/$SSH_KEY_NAME

os=$(uname -s)

tools=(helm flux kind jq kubectl ocm mkcert tea git curl docker gzip)

images=(
ghcr.io/fluxcd/kustomize-controller:v1.0.0-rc.2
ghcr.io/fluxcd/source-controller:v1.0.0-rc.2
gitea/gitea:1.19.3
registry.k8s.io/coredns/coredns:v1.9.3
registry.k8s.io/etcd:3.5.4-0
docker.io/kindest/kindnetd:v20221004-44d545d1
docker.io/kindest/node:v1.25.3
registry.k8s.io/kube-apiserver:v1.25.3
registry.k8s.io/kube-controller-manager:v1.25.3
registry.k8s.io/kube-proxy:v1.25.3
registry.k8s.io/kube-scheduler:v1.25.3
docker.io/kindest/local-path-provisioner:v0.0.22-kind.0
datawire/telepresence:2.13.2
docker.io/datawire/ambassador-telepresence-manager:2.13.2
docker.io/ambassador/ambassador-agent:1.0.14
)

preloadimages=(
ghcr.io/fluxcd/kustomize-controller:v1.0.0-rc.2
ghcr.io/fluxcd/source-controller:v1.0.0-rc.2
gitea/gitea:1.19.3
registry.k8s.io/coredns/coredns:v1.9.3
registry.k8s.io/etcd:3.5.4-0
docker.io/kindest/kindnetd:v20221004-44d545d1
registry.k8s.io/kube-apiserver:v1.25.3
registry.k8s.io/kube-controller-manager:v1.25.3
registry.k8s.io/kube-proxy:v1.25.3
registry.k8s.io/kube-scheduler:v1.25.3
docker.io/kindest/local-path-provisioner:v0.0.22-kind.0
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
install_instructions["gzip_mac"]="brew install curl"
install_instructions["ocm_mac"]="brew install open-component-model/tap/ocm"
install_instructions["mkcert"]=" brew install mkcert"
install_instructions["tea_mac"]="brew tap gitea/tap https://gitea.com/gitea/homebrew-gitea && brew install tea"

