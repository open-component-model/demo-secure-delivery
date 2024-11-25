#!/bin/bash

# libary functions
# Version: v1.0.0
# Author: Piaras Hoban <piaras@weave.works>

source ./lib_vars.sh

function p {
    printf "\033[92mDEMO SETUP => \033[96m%s\033[39m\n" "$1"
}

function create-cluster {
    CLUSTER_NAME=ocm-demo
    kind create cluster --name $CLUSTER_NAME --config=./kind/config.yaml
    IP=$(docker exec -it $CLUSTER_NAME-control-plane cat /etc/hosts | grep 172.20 | cut -f1)
    docker exec -it $CLUSTER_NAME-control-plane sh -c "echo $IP gitea.ocm.dev >> /etc/hosts"
    kubectl patch configmap coredns -n kube-system --type merge --patch "$(cat ./kind/coredns.json)"
    kubectl rollout restart -n kube-system deploy coredns
}

function add-hosts {
    hosts=(gitea.ocm.dev gitea-ssh.gitea podinfo.ocm.dev weave-gitops.ocm.dev ci.ocm.dev events.ci.ocm.dev)
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
    kubectl create ns ocm-system
    CERT_MANAGER_VERSION=${CERT_MANAGER_VERSION:-v1.13.1}
    if [ ! -e 'manifests/cert-manager/cert-manager.yaml' ]; then
        echo "fetching cert-manager manifest for version ${CERT_MANAGER_VERSION}"
        curl -L https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml -o manifests/cert-manager/cert-manager.yaml
    fi

    mkdir -p ./certs && rm -f ./certs/*.pem
    echo -n 'installing cert-manager'
    kubectl apply -f manifests/cert-manager/cert-manager.yaml
    kubectl wait --for=condition=Available=True Deployment/cert-manager -n cert-manager --timeout=60s
    kubectl wait --for=condition=Available=True Deployment/cert-manager-webhook -n cert-manager --timeout=60s
    kubectl wait --for=condition=Available=True Deployment/cert-manager-cainjector -n cert-manager --timeout=60s
    echo 'done'

    echo -n 'applying root certificate issuer'
    kubectl apply -f manifests/cert-manager/cluster_issuer.yaml
    echo 'done'

    echo -n 'waiting for root certificate to be generated...'
    kubectl wait --for=condition=Ready=true Certificate/bootstrap-certificate -n ocm-system --timeout=60s
    echo 'done'

    kubectl get secret ocm-registry-tls-certs -n ocm-system -o jsonpath="{.data['tls\.crt']}" | base64 -d > ./certs/rootCA.pem
    kubectl get secret ocm-registry-tls-certs -n ocm-system -o jsonpath="{.data['tls\.crt']}" | base64 -d > ./certs/cert.pem
    kubectl get secret ocm-registry-tls-certs -n ocm-system -o jsonpath="{.data['tls\.key']}" | base64 -d > ./certs/key.pem
    echo -n 'installing root certificate into local trust store...'
    CAROOT=./certs mkcert -install 2>/dev/null

    echo 'done'
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
    MKCERT_CA="./certs/rootCA.pem"
    TMPFILE=$(mktemp)
    cat ./ca-certs/alpine-ca.crt "$MKCERT_CA" > $TMPFILE
    kubectl create namespace ocm-system || true
    kubectl create secret -n ocm-system generic ocm-signing --from-file=$SIGNING_KEY_NAME=./signing-keys/$SIGNING_KEY_NAME.rsa.pub
    kubectl create secret -n ocm-system generic ocm-dev-ca --from-file=ca-certificates.crt=$TMPFILE
    kubectl create secret -n default tls mkcert-tls --cert=./certs/cert.pem --key=./certs/key.pem

    kubectl apply -f ./manifests/ocm.yaml
    # kubectl apply -f ./manifests/replication.yaml
    rm $TMPFILE
}

function deploy-ingress {
    kubectl apply -f ./manifests/ingress.yaml
    kubectl wait --namespace ingress-nginx \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller \
      --timeout=90s
}

function deploy-tekton {
    MKCERT_CA="./certs/rootCA.pem"
    TMPFILE=$(mktemp)
    cat ./ca-certs/alpine-ca.crt "$MKCERT_CA" > $TMPFILE
    kubectl create ns tekton-pipelines
    kubectl create ns tekton-pipelines-resolvers

    kubectl create secret -n tekton-pipelines generic ocm-dev-ca --from-file=ca-certificates.crt=$TMPFILE
    kubectl create secret -n tekton-pipelines tls mkcert-tls --cert=./certs/cert.pem --key=./certs/key.pem
    kubectl create secret -n tekton-pipelines-resolvers tls mkcert-tls --cert=./certs/cert.pem --key=./certs/key.pem
    kubectl create secret -n tekton-pipelines-resolvers generic ocm-dev-ca --from-file=ca-certificates.crt=$TMPFILE

    flux create secret git -n tekton-pipelines git-credentials \
        --url ssh://git@gitea-ssh.gitea:2222/software-provider/podinfo-component.git \
        --private-key-file=$SSH_KEY_PATH

    kubectl apply -f ./tekton/crds.yaml
    kubectl apply -f ./tekton/triggers.yaml
    kubectl apply -f ./tekton/interceptors.yaml
    kubectl apply -f ./tekton/pipelines.yaml
    kubectl apply -f ./tekton/dashboard.yaml

    kubectl apply -f ./tekton/ingress.yaml
    kubectl apply -f ./tekton/git_clone_task.yaml
    kubectl apply -f ./tekton/publish_component_pipeline.yaml

    kubectl create secret generic -n tekton-pipelines signing-keys \
        --from-file=private-key.rsa=./signing-keys/$SIGNING_KEY_NAME.rsa.key \
        --from-file=public-key.rsa=./signing-keys/$SIGNING_KEY_NAME.rsa.pub \
        --from-file=ocm-config.yaml=./tekton/ocm-config.yaml
}

function configure-gitea {
    if [ "$os" == "Darwin" ]; then
        rm -rf $HOME/Library/Application\ Support/tea/config.yml
    else
        rm -rf $HOME/.config/tea/config.yml
    fi

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

    tea org create --login ocm software-provider
    tea org create --login ocm software-consumer
    tea repo create --login ocm --owner software-consumer --name $PRIVATE_REPO_NAME
    tea repo create --login ocm --owner software-provider --name podinfo-component

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

    docker tag ghcr.io/open-component-model/podinfo:6.3.5-static gitea.ocm.dev/software-provider/podinfo:6.3.5-static
    docker tag ghcr.io/open-component-model/podinfo:6.3.6-static gitea.ocm.dev/software-provider/podinfo:6.3.6-static
    docker push gitea.ocm.dev/software-provider/podinfo:6.3.5-static
    docker push gitea.ocm.dev/software-provider/podinfo:6.3.6-static
}

function init-repository {
    rm -rf ./flux-repo/ && mkdir ./flux-repo
    cp -R ./flux-repo-src/main-branch/. ./flux-repo
    git -C ./flux-repo init
    git -C ./flux-repo checkout -b main
    git -C ./flux-repo add .
    git -C ./flux-repo commit -m "initialise repository"
    git -C ./flux-repo remote add origin ssh://git@gitea-ssh.gitea:2222/software-consumer/$PRIVATE_REPO_NAME.git
    GIT_SSH_COMMAND="ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no" git -C ./flux-repo push origin --all
}

function init-component-repository {
    rm -rf ./component-repo/ && mkdir ./component-repo
    cp -R ./component-repo-src/main-branch/. ./component-repo
    git -C ./component-repo init
    git -C ./component-repo checkout -b main
    git -C ./component-repo add .
    git -C ./component-repo commit -m "initialise repository"
    git -C ./component-repo remote add origin ssh://git@gitea-ssh.gitea:2222/software-provider/podinfo-component.git
    GIT_SSH_COMMAND="ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no" git -C ./component-repo push origin --all
    git -C ./component-repo checkout -b new-release
    rm -rf ./component-repo/src ./component-repo/componentfile.yaml
    cp -R ./component-repo-src/new-release-branch/. ./component-repo
    git -C ./component-repo add .
    git -C ./component-repo commit -m "release podinfo version 6.3.6"
    GIT_SSH_COMMAND="ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no" git -C ./component-repo push origin -u new-release
}

function create-webhook {
    wait-for-endpoint https://gitea.ocm.dev/api/v1/users/ocm-admin
    TOKEN_REQ=$(curl "https://gitea.ocm.dev/api/v1/users/ocm-admin/tokens" \
        -s \
        --request POST \
        --header 'Content-Type: application/json' \
        --user "ocm-admin:password" \
        --data-raw '{ "name": "xxx-webhook-token", "scopes": [ "all" ] }')
    TOKEN=$(echo $TOKEN_REQ | jq -r '.sha1')
    echo $TOKEN
    RECEIVER_TOKEN=$(head -c 12 /dev/urandom | shasum | cut -d ' ' -f1)
    kubectl -n flux-system create secret generic receiver-token --from-literal=token=$RECEIVER_TOKEN
    kubectl apply -f ./manifests/webhook_receiver.yaml

    until [ ! -z $(kubectl get receiver gitea-receiver -n flux-system -ojsonpath="{.status.webhookPath}" | xargs) ]; do
        sleep 0.2
    done;

    WEB_HOOK_PATH=$(kubectl get receiver gitea-receiver -n flux-system -ojsonpath="{.status.webhookPath}" | xargs)

    wait-for-endpoint https://gitea.ocm.dev/api/v1/users/ocm-admin

    curl --location --request POST "https://gitea.ocm.dev/api/v1/repos/software-consumer/$PRIVATE_REPO_NAME/hooks" \
        --header "Content-Type: application/json" \
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

    kubectl -n tekton-pipelines create secret generic ci-webhook --from-literal=secret=$RECEIVER_TOKEN
    kubectl apply -f ./tekton/webhook_rbac.yaml
    kubectl apply -f ./tekton/webhook.yaml

    curl --location --request POST "https://gitea.ocm.dev/api/v1/repos/software-provider/podinfo-component/hooks" \
        --header "Content-Type: application/json" \
        --header "Authorization: token $TOKEN" \
        --data-raw '{
          "active": true,
          "branch_filter": "main",
          "config": {
            "content_type": "json",
            "url": "http://el-ocm-build-trigger.tekton-pipelines:8080/hooks",
            "http_method": "post",
            "secret": "'$RECEIVER_TOKEN'"
          },
          "events": [
            "push",
            "release"
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

    wait-for-endpoint https://gitea.ocm.dev/api/v1/users/ocm-admin

    TOKEN_REQ=$(curl "https://gitea.ocm.dev/api/v1/users/ocm-admin/tokens" \
        -s \
        --request POST \
        --header 'Content-Type: application/json' \
        --user "ocm-admin:password" \
        --data-raw '{ "name": "pr-token", "scopes": [ "all" ] }')
    TOKEN=$(echo $TOKEN_REQ | jq -r '.sha1')
    curl --location --request POST "https://gitea.ocm.dev/api/v1/repos/software-consumer/$PRIVATE_REPO_NAME/pulls" \
        --header 'Content-Type: application/json' \
        --header "Authorization: token $TOKEN" \
        --data-raw '{
          "title": "Component Install: podinfo",
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
    MKCERT_CA="./certs/rootCA.pem"
    TMPFILE=$(mktemp)
    cat ./ca-certs/alpine-ca.crt "$MKCERT_CA" > $TMPFILE
    kubectl create ns flux-system
    kubectl create secret -n flux-system generic ocm-dev-ca --from-file=ca-certificates.crt=$TMPFILE
    flux create secret git -n flux-system flux-system \
        --url ssh://git@gitea-ssh.gitea:2222/software-consumer/$PRIVATE_REPO_NAME.git \
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

function cache-images {
    if [ ! -d ./images ]; then
        mkdir ./images
    fi

    for image in "${images[@]}"; do
        if ! $(docker image inspect $image > /dev/null 2>&1 ) ; then
            echo "Caching image... $image"
            docker pull -q $image
        fi
    done
}


function preload-images {
    kind load docker-image --name $1 ${preloadimages[@]}
}
