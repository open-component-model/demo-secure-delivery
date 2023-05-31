#!/bin/bash

# libary functions
# Version: v1.0.0
# Author: Piaras Hoban <piaras@weave.works>

source ./lib_vars.sh

function p {
    printf "\033[92mDEMO SETUP => \033[96m%s\033[39m\n" "$1"
}

function create-cluster {
    CLUSTER_NAME=aws-demo
    kind create cluster --name $CLUSTER_NAME --config=./kind/config.yaml
    IP=$(docker exec -it $CLUSTER_NAME-control-plane cat /etc/hosts | grep 172.20 | cut -f1)
    docker exec -it $CLUSTER_NAME-control-plane sh -c "echo $IP gitea.ocm.dev >> /etc/hosts"
    kubectl patch configmap coredns -n kube-system --type merge --patch "$(cat ./kind/coredns.json)"
    kubectl rollout restart -n kube-system deploy coredns
}

function add-hosts {
    hosts=(gitea.ocm.dev gitea-ssh.gitea podinfo.ocm.dev weave-gitops.ocm.dev)
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

function configure-tls {
    mkdir -p ./certs && rm -f ./certs/*.pem
    mkcert -install 2>/dev/null
    mkcert -cert-file=./certs/cert.pem -key-file=./certs/key.pem gitea.ocm.dev weave-gitops.ocm.dev podinfo.ocm.dev
}

function configure-signing-keys {
    mkdir -p ./signing-keys && rm -f ./signing-keys/*.rsa.*
    ocm create rsakeypair ./signing-keys/$SIGNING_KEY_NAME.rsa.key ./signing-keys/$SIGNING_KEY_NAME.rsa.pub
}

function deploy-gitea {
    helm install gitea ./charts/gitea \
        -f ./gitea/values.yaml \
        -n gitea --create-namespace \
        --atomic
    kubectl create secret -n gitea tls mkcert-tls --cert=./certs/cert.pem --key=./certs/key.pem
}

function create-weave-gitops-component {
    cd weave-gitops/
    make build
    make sign
    make push
    cd ../
}

function deploy-ocm-controller {
    MKCERT_CA="$(mkcert -CAROOT)/rootCA.pem"
    TMPFILE=$(mktemp)
    cat ./ca-certs/alpine-ca.crt "$MKCERT_CA" > $TMPFILE
    kubectl create namespace ocm-system
    kubectl create secret -n ocm-system generic ocm-signing --from-file=$SIGNING_KEY_NAME=./signing-keys/$SIGNING_KEY_NAME.rsa.pub
    kubectl create secret -n ocm-system generic ocm-dev-ca --from-file=ca-certificates.crt=$TMPFILE
    kubectl create secret -n default tls mkcert-tls --cert=./certs/cert.pem --key=./certs/key.pem
    kubectl apply -f ./manifests/ocm.yaml
    kubectl apply -f ./manifests/replication.yaml
    rm $TMPFILE
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

    TOKEN_REQ=$(curl "https://gitea.ocm.dev/api/v1/users/ocm-admin/tokens" \
        --request POST \
        --header 'Content-Type: application/json' \
        --user "ocm-admin:password" \
        --data '{ "name": "ocm-admin-token", "scopes": [ "all" ] }')

    TOKEN=$(echo $TOKEN_REQ | jq -r '.sha1')

    tea login add -i \
        --name ocm \
        --user ocm-admin \
        --password password \
        --token $TOKEN \
        --url https://gitea.ocm.dev

    tea org create --login ocm public-org
    tea org create --login ocm private-org
    tea repo create --login ocm --owner private-org --name $PRIVATE_REPO_NAME

    echo password | docker login gitea.ocm.dev -u ocm-admin --password-stdin

    kubectl create secret -n ocm-system generic \
        gitea-registry-credentials \
            --from-literal=username=ocm-admin \
            --from-literal=password=$TOKEN

    kubectl create secret -n default docker-registry \
        gitea-registry-credentials \
            --docker-server=gitea.ocm.dev \
            --docker-username=ocm-admin \
            --docker-password=$TOKEN
}

function init-repository {
    rm -rf ./flux-repo/ && mkdir ./flux-repo
    cp -R ./flux-repo-src/main-branch/. ./flux-repo
    git -C ./flux-repo init
    git -C ./flux-repo add .
    git -C ./flux-repo commit -m "initialise repository"
    git -C ./flux-repo remote add origin ssh://git@gitea-ssh.gitea:2222/private-org/$PRIVATE_REPO_NAME.git
    GIT_SSH_COMMAND="ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no" git -C ./flux-repo push origin --all
}

function create-webhook {
    TOKEN_REQ=$(curl "https://gitea.ocm.dev/api/v1/users/ocm-admin/tokens" \
        -s \
        --request POST \
        --header 'Content-Type: application/json' \
        --user "ocm-admin:password" \
        --data-raw '{ "name": "webhook-token", "scopes": [ "all" ] }')
    TOKEN=$(echo $TOKEN_REQ | jq -r '.sha1')
    RECEIVER_TOKEN=$(head -c 12 /dev/urandom | shasum | cut -d ' ' -f1)
    kubectl -n flux-system create secret generic receiver-token --from-literal=token=$RECEIVER_TOKEN
    kubectl apply -f ./manifests/webhook_receiver.yaml

    until [ ! -z $(kubectl get receiver gitea-receiver -n flux-system -ojsonpath="{.status.webhookPath}" | xargs) ]; do
        sleep 0.1
    done;

    WEB_HOOK_PATH=$(kubectl get receiver gitea-receiver -n flux-system -ojsonpath="{.status.webhookPath}" | xargs)

    curl --location --request POST 'https://gitea.ocm.dev/api/v1/repos/private-org/$PRIVATE_REPO_NAME/hooks' \
        --header 'Content-Type: application/json' \
        --header "Authorization: token $TOKEN" \
        --data-raw '{
          "active": true,
          "branch_filter": "main",
          "config": {
            "content_type": "json",
            "url": "http://webhook-receiver.flux-system'$WEB_HOOK_PATH'",
            "http_method": "post",
            "secret": "'$RECEIVER_TOKEN'"
          },
          "events": [
            "push"
          ],
          "type": "gitea"
        }'
}

function create-pull-request {
    GIT_SSH_COMMAND="ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no" git -C ./flux-repo pull origin main --rebase=true
    git -C ./flux-repo checkout -b ops-install-podinfo
    cp -R ./flux-repo-src/pr-branch/. ./flux-repo
    git -C ./flux-repo add .
    git -C ./flux-repo commit -m "add podinfo component"
    GIT_SSH_COMMAND="ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no" git -C ./flux-repo push origin --all
    TOKEN_REQ=$(curl "https://gitea.ocm.dev/api/v1/users/ocm-admin/tokens" \
        -s \
        --request POST \
        --header 'Content-Type: application/json' \
        --user "ocm-admin:password" \
        --data-raw '{ "name": "pr-token", "scopes": [ "all" ] }')
    TOKEN=$(echo $TOKEN_REQ | jq -r '.sha1')
    curl --location --request POST "https://gitea.ocm.dev/api/v1/repos/private-org/$PRIVATE_REPO_NAME/pulls" \
        --header 'Content-Type: application/json' \
        --header "Authorization: token $TOKEN" \
        --data-raw '{
          "title": "Deploy podinfo application",
          "body": "Adds manifests for podinfo and values.yaml for application configuration.",
          "base": "main",
          "head": "ops-install-podinfo"
        }'
}


function configure-ssh {
    echo "creating private key... $SSH_KEY_PATH"
    if [ ! -f $SSH_KEY_PATH ];then
        ssh-keygen -q -t ed25519 -C $SSH_KEY_NAME -f $SSH_KEY_PATH -P ""
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
    MKCERT_CA="$(mkcert -CAROOT)/rootCA.pem"
    TMPFILE=$(mktemp)
    cat ./ca-certs/alpine-ca.crt "$MKCERT_CA" > $TMPFILE
    kubectl create ns flux-system
    kubectl create secret -n flux-system generic ocm-dev-ca --from-file=ca-certificates.crt=$TMPFILE
    flux create secret git -n flux-system flux-system \
        --url ssh://git@gitea-ssh.gitea:2222/private-org/$PRIVATE_REPO_NAME.git \
        --private-key-file=$SSH_KEY_PATH
    kubectl apply -f ./manifests/flux.yaml
    kubectl apply -f ./flux-repo-src/main-branch/clusters/kind/flux-system/gotk-sync.yaml
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
                    eval "${!install_instructions_mac}"
                ;;
            [Nn])
                echo -e "To install \033[1;36m$tool\033[0m on macOS:"
                echo -e "$ ${install_instructions_mac}"
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
            install_tool "$i" "${i}_mac_instructions"
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
