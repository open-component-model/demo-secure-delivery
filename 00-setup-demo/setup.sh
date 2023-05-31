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

p "caching images..."
cache-images

p "check complete: all charts downloaded"

p "creating kind cluster"
create-cluster

p "side-loading images..."
preload-images aws-demo

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

p "create weave gitops component"
create-weave-gitops-component

p "initialise repository"
init-repository

p "bootstrapping flux"
bootstrap-flux

p "create webhook & receiver"
create-webhook

p "create pull request"
create-pull-request

echo -e "
Setup is complete!

You can access gitea at the following URL: https://gitea.ocm.dev/private-org/$PRIVATE_REPO_NAME

Username: ocm-admin
Password: password
"

if [ "$OS" == "Darwin" ];then
    open "https://gitea.ocm.dev/user/login?redirect_to=%2fprivate-org%2fapps"
else
    xdg-open "https://gitea.ocm.dev/user/login?redirect_to=%2fprivate-org%2fapps"
fi
