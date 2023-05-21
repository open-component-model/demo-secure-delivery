#!/bin/bash

# cache images
# Version: v1.0.0
# Author: Piaras Hoban <phoban01@gmail.com>

set -o errexit

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

if [ ! -d ./images ]; then
    mkdir ./images
fi

for image in "${images[@]}"; do
    name=$(echo $image | rev | cut -d '/' -f1 | rev | cut -d ':' -f1)
    echo "Caching image... $image"
    docker pull -q $image
    docker save $image | gzip > ./images/$name.tar.gz
done

