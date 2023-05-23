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
install-tools
p "check complete: all tools installed"

p "running pre-check for charts..."
cache-charts

p "check complete: all charts downloaded"

p "creating kind cluster"
create-cluster

# p "side-loading images..."
# preload-images aws-demo

p "caching manifests..."
cache-manifests

p "creating tls certs"
configure-tls

p "creating signing keys"
configure-signing-keys

p "deploying gitea"
deploy-gitea

p "deploying ingress"
deploy-ingress

p "deploying ocm-controller"
deploy-ocm-controller

p "configuring gitea"
configure-gitea

p "configuring ssh"
configure-ssh

p "initialise repository"
init-repository

p "bootstrapping flux"
bootstrap-flux

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
