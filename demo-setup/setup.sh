#!/bin/bash

# demo environment setup
# Version: v1.0.0
# Author: Piaras Hoban <piaras@weave.works>

set -o errexit

OS=$(uname -s)

source ./lib.sh

p "updating /etc/hosts... may prompt for password if host entries do not exist"
add-hosts

p "running pre-check for tools..."
. install-tools.sh
p "check complete: all tools installed"

p "running pre-check for charts..."
. install-charts.sh
p "check complete: all charts downloaded"

p "creating kind cluster"
kind create cluster --name aws-demo -q --config=./kind/config.yaml

p "side-loading images..."
# . load-images.sh aws-demo

p "caching manifests..."
. cache-manifests.sh

p "creating tls certs"
mkcerts

p "deploying gitea"
deploy-gitea

p "deploying ingress"
deploy-ingress

p "configuring gitea"
configure-gitea

p "configuring ssh"
configure-ssh

p "bootstrapping flux"
bootstrap-flux

p "deploying ocm-controller"
kubectl apply -f ./manifests/ocm.yaml

echo -e "
Setup is complete!

You can access gitea at the following URL: https://gitea.ocm.dev/private-org/podinfo-private

Username: ocm-admin
Password: password
"

if [ "$OS" == "Darwin" ];then
    open https://gitea.ocm.dev/private-org/podinfo-private
else
    xdg-open https://gitea.ocm.dev/private-org/podinfo-private
fi
