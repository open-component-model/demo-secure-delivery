#!/bin/bash

# install tools
# Version: v1.0.0
# Author: Piaras Hoban <piaras@weave.works>

tools=(helm flux kind jq kubectl ocm mkcert tea git curl docker gzip)
os=$(uname -s)

declare -A install_instructions

install_instructions["helm_mac"]="brew install helm"
install_instructions["flux_mac"]="brew install fluxcd/tap/flux"
install_instructions["kind_mac"]="brew install kind"
install_instructions["kubectl_mac"]="brew install kubectl"
install_instructions["jq_mac"]="brew install jq"
install_instructions["git_mac"]="brew install git"
install_instructions["curl_mac"]="brew install curl"
install_instructions["docker_mac"]="brew install docker"
install_instructions["gzip_mac"]="brew install curl"
install_instructions["ocm_mac"]="brew install open-component-model/tap/ocm"
install_instructions["mkcert"]=" brew install mkcert"
install_instructions["tea_mac"]="brew tap gitea/tap https://gitea.com/gitea/homebrew-gitea && brew install tea"

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

for i in "${tools[@]}"; do
    if ! command -v $i &> /dev/null; then
        install_tool "$i" "${install_instructions[$i"_mac"]}"
    fi
done
