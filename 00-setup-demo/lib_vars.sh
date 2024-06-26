#!/bin/bash
# libary function vars
# Version: v1.0.0
# Author: Piaras Hoban <piaras@weave.works>

PRIVATE_REPO_NAME=ocm-applications
SIGNING_KEY_NAME=ocm-signing

SSH_KEY_NAME=ocm-private-demo-key
SSH_KEY_PATH=$HOME/.ssh/$SSH_KEY_NAME

HOSTS=(gitea.ocm.dev gitea-ssh.gitea podinfo.ocm.dev weave-gitops.ocm.dev)

os=$(uname -s)

tools=(helm flux kind jq kubectl ocm mkcert tea git curl docker gzip)

images=(
ghcr.io/open-component-model/podinfo:6.3.5-static
ghcr.io/open-component-model/podinfo:6.3.6-static
ghcr.io/open-component-model/ocm-controller:v0.23.9-dev
ghcr.io/open-component-model/ocm/ocm.software/ocmcli/ocmcli-image:latest
ghcr.io/weaveworks/wego-app:v0.24.0
ghcr.io/fluxcd/helm-controller:v1.0.1
ghcr.io/fluxcd/kustomize-controller:v1.3.0
ghcr.io/fluxcd/notification-controller:v1.3.0
ghcr.io/fluxcd/source-controller:v1.3.0
gitea/gitea:1.19.3
registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20230312-helm-chart-4.5.2-28-g66a760794
registry.k8s.io/ingress-nginx/controller:v1.7.1
registry.k8s.io/coredns/coredns:v1.10.1
registry.k8s.io/etcd:3.5.7-0
docker.io/kindest/kindnetd:v20230511-dc714da8
registry.k8s.io/kube-apiserver:v1.27.1
registry.k8s.io/kube-controller-manager:v1.27.1
registry.k8s.io/kube-proxy:v1.27.1
registry.k8s.io/kube-scheduler:v1.27.1
docker.io/kindest/local-path-provisioner:v20230511-dc714da8
registry:2
cgr.dev/chainguard/busybox
docker.io/library/alpine:latest
gcr.io/tekton-releases/github.com/tektoncd/dashboard/cmd/dashboard:v0.36.0
gcr.io/tekton-releases/github.com/tektoncd/pipeline/cmd/controller:v0.48.0
gcr.io/tekton-releases/github.com/tektoncd/pipeline/cmd/entrypoint:v0.48.0
gcr.io/tekton-releases/github.com/tektoncd/pipeline/cmd/events:v0.48.0
gcr.io/tekton-releases/github.com/tektoncd/pipeline/cmd/git-init:v0.40.2
gcr.io/tekton-releases/github.com/tektoncd/pipeline/cmd/webhook:v0.48.0
gcr.io/tekton-releases/github.com/tektoncd/triggers/cmd/controller:v0.24.0
gcr.io/tekton-releases/github.com/tektoncd/triggers/cmd/eventlistenersink:v0.24.0
gcr.io/tekton-releases/github.com/tektoncd/triggers/cmd/interceptors:v0.24.0
gcr.io/tekton-releases/github.com/tektoncd/triggers/cmd/webhook:v0.24.0
)

preloadimages=(
ghcr.io/open-component-model/podinfo:6.3.5-static
ghcr.io/open-component-model/podinfo:6.3.6-static
ghcr.io/weaveworks/wego-app:v0.24.0
ghcr.io/fluxcd/helm-controller:v0.33.0
ghcr.io/fluxcd/kustomize-controller:v1.0.0-rc.3
ghcr.io/fluxcd/notification-controller:v1.0.0-rc.3
ghcr.io/fluxcd/source-controller:v1.0.0-rc.3
gitea/gitea:1.19.3
registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20230312-helm-chart-4.5.2-28-g66a760794
registry.k8s.io/ingress-nginx/controller:v1.7.1
registry.k8s.io/coredns/coredns:v1.10.1
docker.io/kindest/local-path-provisioner:v20230511-dc714da8
ghcr.io/open-component-model/ocm-controller:v0.19.0
ghcr.io/open-component-model/replication-controller:v0.13.0
registry:2
cgr.dev/chainguard/busybox
docker.io/library/alpine:latest
gcr.io/tekton-releases/github.com/tektoncd/dashboard/cmd/dashboard:v0.36.0
gcr.io/tekton-releases/github.com/tektoncd/pipeline/cmd/controller:v0.48.0
gcr.io/tekton-releases/github.com/tektoncd/pipeline/cmd/entrypoint:v0.48.0
gcr.io/tekton-releases/github.com/tektoncd/pipeline/cmd/events:v0.48.0
gcr.io/tekton-releases/github.com/tektoncd/pipeline/cmd/git-init:v0.40.2
gcr.io/tekton-releases/github.com/tektoncd/pipeline/cmd/webhook:v0.48.0
gcr.io/tekton-releases/github.com/tektoncd/triggers/cmd/controller:v0.24.0
gcr.io/tekton-releases/github.com/tektoncd/triggers/cmd/eventlistenersink:v0.24.0
gcr.io/tekton-releases/github.com/tektoncd/triggers/cmd/interceptors:v0.24.0
gcr.io/tekton-releases/github.com/tektoncd/triggers/cmd/webhook:v0.24.0
ghcr.io/open-component-model/ocm/ocm.software/ocmcli/ocmcli-image:latest
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
mkcert_mac_instructions="brew install mkcert"
tea_mac_instructions="brew tap gitea/tap https://gitea.com/gitea/homebrew-gitea && brew install tea"
