#!/bin/bash

# libary functions
# Version: v1.0.0
# Author: Piaras Hoban <piaras@weave.works>

source ./lib_vars.sh

function p {
    printf "\033[92mDEMO SETUP => \033[96m%s\033[39m\n" "$1"
}

function create-cluster {
    kind create cluster --name aws-demo --config=./kind/config.yaml
    kubectl patch configmap coredns -n kube-system --type merge --patch "$(cat ./kind/coredns.json)"
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

function deploy-ocm-controller {
    kubectl create namespace ocm-system
    kubectl create secret -n ocm-system tls mkcert-tls --cert=./certs/cert.pem --key=./certs/key.pem
    kubectl apply -f ./manifests/ocm.yaml
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

function init-repository {
    rm -rf ./flux-repo/.git
    git -C ./flux-repo init
    git -C ./flux-repo add .
    git -C ./flux-repo commit -m "initialise repository"
    git -C ./flux-repo remote add origin ssh://git@gitea-ssh.gitea:2222/private-org/podinfo-private.git
    GIT_SSH_COMMAND="ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no" git -C ./flux-repo push origin --all
}

function configure-ssh {
    if [ ! -f $SSH_KEY_PATH ];then
        ssh-keygen -q -t ed25519 -C $SSH_KEY_NAME -f $SSH_KEY_PATH -P "" -y
    fi
    SSH_PUBLIC_KEY=$(cat $SSH_KEY_PATH.pub)
    curl https://gitea.ocm.dev/api/v1/user/keys -XPOST --silent \
        --header 'Content-Type: application/json' \
        --user "ocm-admin:password" \
        --data '{ "title": "access-key", "key": "'"$SSH_PUBLIC_KEY"'"}'
    kubectl port-forward -n gitea svc/gitea-ssh 2222:2222 &
    sleep 5
}

function bootstrap-flux {
    SSH_KEY_PATH=$HOME/.ssh/aws-demo-key
    kubectl apply -f ./manifests/flux.yaml
    flux bootstrap git --silent \
        --url ssh://git@gitea-ssh.gitea:2222/private-org/podinfo-private.git \
        --path=clusters/kind \
        --private-key-file=$SSH_KEY_PATH
}

function cache-charts {
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
}

function cache-images {
    if [ ! -d ./images ]; then
        mkdir ./images
    fi

    for image in "${images[@]}"; do
        name=$(echo $image | rev | cut -d '/' -f1 | rev | cut -d ':' -f1)
        echo "Caching image... $image"
        docker pull -q $image
        docker save $image | gzip > ./images/$name.tar.gz
    done
}

function cache-manifests {
    if [ ! -d ./manifests ];then
        mkdir -p ./manifests
    fi

    if [ ! -f ./manifests/flux.yaml ];then
        flux install --components="source-controller,kustomize-controller" --export > ./manifests/flux.yaml
    fi

    if [ ! -f ./manifests/ocm.yaml ];then
        ocm controller install --dry-run > ./manifests/ocm.yaml
    fi
}

function install_tool {
    local tool=$1
    local install_instructions_mac=$2

    echo -e "\033[1;31mWarning:\033[0m \033[1;36m$tool\033[0m is not installed."

    if [ "$os" == "Darwin" ]; then
        read -p "Do you want to install $tool automatically? (Y/N): " choice
        case $choice in
            [Yy])
                echo "Installing $tool..."
                    eval "${install_instructions_mac}"
                ;;
            [Nn])
                echo -e "To install \033[1;36m$tool\033[0m on macOS:"
                echo -e "  $ ${install_instructions_mac}"
                exit 1
                ;;
            *)
                echo "Invalid choice. Skipping $tool installation."
                exit 1
                ;;
        esac
    else
        echo -e "Please install \033[1;36m$tool\033[0m before continuing"
        exit 1
    fi
}

function install-tools {
    for i in "${tools[@]}"; do
        if ! command -v $i &> /dev/null; then
            install_tool "$i" "${install_instructions[$i"_mac"]}"
        fi
    done
}

function preload-images {
    for image in "${preloadimages[@]}"; do
        name=$(echo $image | rev | cut -d '/' -f1 | rev | cut -d ':' -f1)
        echo "Loading image $image"
        gzip -d -k ./images/$name.tar.gz
        kind load image-archive --name $1 ./images/$name.tar
        rm ./images/$name.tar
    done
}
