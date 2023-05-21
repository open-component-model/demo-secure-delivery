#!/bin/bash

# cache charts
# Version: v1.0.0
# Author: Piaras Hoban <piaras@weave.works>

set -o errexit

CHART_DIR=./charts

if [ ! -d $CHART_DIR ]; then
    mkdir $CHART_DIR
fi

if [ ! -d $CHART_DIR/nginx-ingress ]; then
    helm repo add nginx-stable https://helm.nginx.com/stable || true
    helm pull nginx-stable/nginx-ingress --untar=true --untardir=$CHART_DIR
fi

if [ ! -d $CHART_DIR/telepresence ]; then
    helm repo add datawire https://app.getambassador.io || true
    helm pull datawire/telepresence --untar=true --untardir=$CHART_DIR
fi

if [ ! -d $CHART_DIR/gitea ]; then
    helm repo add gitea-charts https://dl.gitea.io/charts || true
    helm pull gitea-charts/gitea --untar=true --untardir=$CHART_DIR
fi
