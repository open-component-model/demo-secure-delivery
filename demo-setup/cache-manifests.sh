#!/bin/bash

# cache kubernetes manifests
# Version: v1.0.0
# Author: Piaras Hoban <phoban01@gmail.com>

set -o errexit

if [ ! -d ./manifests ];then
    mkdir -p ./manifests
fi

if [ ! -f ./manifests/flux.yaml ];then
    flux install --components="source-controller,kustomize-controller" --export > ./manifests/flux.yaml
fi

if [ ! -f ./manifests/ocm.yaml ];then
    ocm controller install --dry-run > ./manifests/ocm.yaml
fi
