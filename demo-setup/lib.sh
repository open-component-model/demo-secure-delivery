#!/bin/bash

# libary functions
# Version: v1.0.0
# Author: Piaras Hoban <piaras@weave.works>

function p {
    printf "\033[92mDEMO SETUP => \033[96m%s\033[39m\n" "$1"
}

function add-hosts {
    hosts=(gitea.ocm.dev gitea-ssh.gitea)
    for host in "${hosts[@]}"; do
        if ! grep -qF $host /etc/hosts; then
          echo "127.0.0.1        $host" | sudo tee -a /etc/hosts >/dev/null
        fi
    done
}

function wait-for-endpoint {
    until $(curl --output /dev/null --silent --fail $1); do
        sleep 0.1
    done
}

function mkcerts {
    mkdir -p ./certs && rm -f ./certs/*.pem
    mkcert -install 2>/dev/null
    mkcert -cert-file=./certs/cert.pem -key-file=./certs/key.pem gitea.ocm.dev
}

function deploy-gitea {
    helm install gitea ./charts/gitea \
        -f ./gitea/values.yaml \
        -n gitea --create-namespace \
        --atomic
    kubectl create secret -n gitea tls mkcert-tls --cert=./certs/cert.pem --key=./certs/key.pem
}

function deploy-ingress {
    kubectl apply -f ./manifests/ingress.yaml
    kubectl wait --namespace ingress-nginx \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller \
      --timeout=90s
}

function configure-gitea {
    rm -rf $HOME/.config/tea/config.yml

    wait-for-endpoint https://gitea.ocm.dev/api/v1/users/ocm-admin

    TOKEN=$(curl "https://gitea.ocm.dev/api/v1/users/ocm-admin/tokens" \
        --request POST \
        --header 'Content-Type: application/json' \
        --user "ocm-admin:password" \
        --data '{ "name": "ocm-admin-token", "scopes": [ "all" ] }')

    tea login add -i \
        --name ocm \
        --user ocm-admin \
        --password password \
        --token $(echo $TOKEN | jq -r '.sha1') \
        --url https://gitea.ocm.dev

    tea org create --login ocm public-org
    tea org create --login ocm private-org
    tea repo create --login ocm --owner public-org --name podinfo-public
    tea repo create --login ocm --owner private-org --name podinfo-private

    echo password | docker login gitea.ocm.dev -u ocm-admin --password-stdin
}

function configure-ssh {
    SSH_KEY_NAME=aws-demo-key
    SSH_KEY_PATH=$HOME/.ssh/$SSH_KEY_NAME
    if [ ! -f $SSH_KEY_PATH ];then
        ssh-keygen -q -t ed25519 -C $SSH_KEY_NAME -f $SSH_KEY_PATH -P "" -y
    fi
    SSH_PUBLIC_KEY=$(cat $SSH_KEY_PATH.pub)
    curl https://gitea.ocm.dev/api/v1/user/keys -XPOST --silent \
        --header 'Content-Type: application/json' \
        --user "ocm-admin:password" \
        --data '{ "title": "access-key", "key": "'"$SSH_PUBLIC_KEY"'"}'
}

function bootstrap-flux {
    SSH_KEY_PATH=$HOME/.ssh/aws-demo-key
    kubectl apply -f ./manifests/flux.yaml
    kubectl port-forward -n gitea svc/gitea-ssh 2222:2222 &
    sleep 5
    flux bootstrap git --silent \
        --url ssh://git@gitea-ssh.gitea:2222/private-org/podinfo-private.git \
        --path=clusters/kind \
        --private-key-file=$SSH_KEY_PATH
}
