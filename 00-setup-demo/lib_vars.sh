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
ghcr.io/open-component-model/replication-controller:v0.2.1
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

helm_mac_instructions="brew install helm"
flux_mac_instructions="brew install fluxcd/tap/flux"
kind_mac_instructions="brew install kind"
kubectl_mac_instructions="brew install kubectl"
jq_mac_instructions="brew install jq"
git_mac_instructions="brew install git"
curl_mac_instructions="brew install curl"
docker_mac_instructions="brew install docker"
gzip_mac_instructions="brew install gzip"
ocm_mac_instructions="brew install open-component-model/tap/ocm"
mkcert="brew install mkcert"
tea_mac_instructions="brew tap gitea/tap https://gitea.com/gitea/homebrew-gitea && brew install tea"
