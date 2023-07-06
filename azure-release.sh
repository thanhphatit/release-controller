#!/bin/bash
## Author: Dang Thanh Phat
## Email: thanhphatit95@gmail.com
## Web/blogs: www.itblognote.com
## Description:
##      Script to deploy release service azure to aks or fa

#### GLOBAL VARIABLES

#### SHELL SETTING
set -o pipefail
# set -e ### When you use -e it will export error when logic function fail, example: grep "yml" if yml not found

#### VARIABLES
OPTION=${1:-k8s} ### Value is k8s or fa

STAGE_SYNTAX_DEV="DEV"
STAGE_SYNTAX_UAT="UAT"
STAGE_SYNTAX_DR="DR"
STAGE_SYNTAX_VNPRD="VNPRD"

### Used with echo have flag -e
RLC="\033[1;31m"    ## Use redlight color
GC="\033[0;32m"     ## Use green color
YC="\033[0;33m"     ## Use yellow color
BC="\033[0;34m"     ## Use blue color
EC="\033[0m"        ## End color with no color

#### FUNCTIONS

function check_var(){
    local VAR_LIST=(${1})
    
    for var in ${VAR_LIST[@]}; do
        if [[ -z "$(eval echo $(echo $`eval echo "${var}"`))" ]];then
            echo -e "${YC}[CAUTIONS] Variable ${var} not found!"
            exit 1
        fi
    done

    #### Example: check_var "DEVOPS THANHPHATIT"
}

function about(){
cat <<ABOUT

*********************************************************
* Author: DANG THANH PHAT                               *
* Email: thanhphat@itblognote.com                       *
* Blog: www.itblognote.com                              *
* Version: 0.5                                          *
* Purpose: Tools to release application to k8s or fa.   *
*********************************************************

Use --help or -h to check syntax, please !

ABOUT
    exit 1
}

function help(){
cat <<HELP

Usage: azure-release [options...]

[*] OPTIONS:
    -h, --help            Show help
    -v, --version         Show info and version
    k8s                   (This is default value) - Start deploy application to k8s
    fa                    Start deploy functions app to Azure 

HELP
    exit 1
}

function check_plugin(){
    local COMMAND_PLUGIN_LIST="${1}"
    local PLUGIN_LIST=(${2})

    local TOOLS_NAME="$(echo "${COMMAND_PLUGIN_LIST}" | awk '{print $1}')"

    for plugin in ${PLUGIN_LIST[@]}; do
        # If not found tools => exit
        if [[ ! $(${COMMAND_PLUGIN_LIST} 2>/dev/null | grep -i "^${plugin}") ]];then
cat << ALERTS
[x] Not found this ${TOOLS_NAME} plugin [${plugin}] on machine.

Exit.
ALERTS
            exit 1
        fi
    done

    #### Example: check_plugin "helm plugin list" "cm-push diff s3" 
}

function pre_check_dependencies(){
    ## All tools used in this script
    local TOOLS_LIST=(${1})

    for tools in ${TOOLS_LIST[@]}; do
        # If not found tools => exit
        if [[ ! $(command -v ${tools}) ]];then
cat << ALERTS
[x] Not found tool [${tools}] on machine.

Exit.
ALERTS
            exit 1
        fi
    done

    #### Example: pre_check_dependencies "helm" 
}

function download_file(){
    local DOWN_USER=${1}
    local DOWN_PASSWORD=${2}
    local DOWN_FILE_EXPORT_NAME=${3}
    local DOWN_URL=${4}

    curl -u ${DOWN_USER}:${DOWN_PASSWORD} -o ${DOWN_FILE_EXPORT_NAME} ${DOWN_URL} &
    wait

    if [[ -f ${DOWN_FILE_EXPORT_NAME} ]];then
        echo -e "${GC}[DOWNLOAD]: ${DOWN_FILE_EXPORT_NAME} SUCCESS ****"
    else
        echo -e "${RLC}[ERROR] not found download file!"
    fi
}

function check_stage_used(){
    local STAGE_LOW="$(echo "${1}" | tr '[:upper:]' '[:lower:]')"
    if [[ $(echo "${STAGE}" | grep "${STAGE_LOW}") ]];then
        echo "true"
    fi
}

function check_stage_current(){
    local STAGE_DEV_USED=$(check_stage_used "${STAGE_SYNTAX_DEV}")
    local STAGE_UAT_USED=$(check_stage_used "${STAGE_SYNTAX_UAT}")
    local STAGE_DR_USED=$(check_stage_used "${STAGE_SYNTAX_DR}")
    local STAGE_VNPRD_USED=$(check_stage_used "${STAGE_SYNTAX_VNPRD}")

    if [[ ${STAGE_DEV_USED} == "true" ]];then
        STAGE_CURRENT="dev"
    fi

    if [[ ${STAGE_UAT_USED} == "true" ]];then
        STAGE_CURRENT="uat"
    fi

    if [[ ${STAGE_DR_USED} == "true" ]];then
        STAGE_CURRENT="dr"
    fi

    if [[ ${STAGE_VNPRD_USED} == "true" ]];then
        STAGE_CURRENT="vnprd"
    fi
    return 0
}

function change_var_with_stage(){
    check_stage_current
    K8S_CONTEXT=""
    K8S_NAMESPACE=""

    check_var "STAGE_CURRENT"

    if [[ ${STAGE_CURRENT} == "dev" ]];then
        K8S_CONTEXT="${K8S_CONTEXT_DEV}"
        K8S_NAMESPACE="${K8S_NS_DEV}"
    fi

    if [[ ${STAGE_CURRENT} == "uat" ]];then
        K8S_CONTEXT="${K8S_CONTEXT_UAT}"
        K8S_NAMESPACE="${K8S_NS_UAT}"
    fi

    if [[ ${STAGE_CURRENT} == "dr" ]];then
        K8S_CONTEXT="${K8S_CONTEXT_DR}"
        K8S_NAMESPACE="${K8S_NS_DR}"
    fi

    if [[ ${STAGE_CURRENT} == "vnprd" ]];then
        K8S_CONTEXT="${K8S_CONTEXT_VNPRD}"
        K8S_NAMESPACE="${K8S_NS_VNPRD}"
    fi

    if [[ ${BUILD_MULTI_ENV} != "false" || ${BUILD_MULTI_ENV} != "False" ]];then
        DOCKER_TAG="${STAGE_CURRENT}.${DOCKER_TAG}"
    fi

    check_var "K8S_CONTEXT K8S_NAMESPACE"
    echo ""
    echo "*******************************"
    echo "*        SHOW VARIABLES       *"
    echo "*******************************"
    echo ""
    echo "[*] SERVICE_NAME: ${SERVICE_NAME}"
    echo "[*] GIT_COMMIT_ID: ${GIT_COMMIT_ID}"
    echo "[*] APP_BUILD_NUMBER: ${APP_BUILD_NUMBER}"
    echo "[*] DOCKER_TAG: ${DOCKER_TAG}"
    echo "[*] DOCKER_URL: ${DOCKER_URL}"
    echo "[*] HELM_VERSION: ${HELM_VERSION}"
    echo "[*] BUILD_MULTI_ENV: ${BUILD_MULTI_ENV}"
    echo "[*] BUILD_ID: ${BUILD_ID}"
    echo "[*] DEPLOY_TYPE: ${DEPLOY_TYPE}"
    echo "[*] STAGE: ${STAGE}"
    echo "[*] K8S_CONTEXT: ${K8S_CONTEXT}"
    echo "[*] K8S_NAMESPACE: ${K8S_NAMESPACE}"
    echo ""
    return 0
}

function pre_checking(){
    check_var "SERVICE_NAME GIT_COMMIT_ID DOCKER_TAG DOCKER_URL K8S_DOWNLOAD_CONFIG_URL K8S_CONTEXT_UAT K8S_CONTEXT_VNPRD K8S_NS_DEV K8S_NS_UAT K8S_NS_DR K8S_NS_VNPRD"
    pre_check_dependencies "helm kubectl docker"
    change_var_with_stage

    local RESULT_CHECK_PLUGIN_HELM_DIFF=$(check_plugin "helm plugin list" "diff")
    local RESULT_CHECK_PLUGIN_HELM_PUSH=$(check_plugin "helm plugin list" "cm-push")

    if [[ "${RESULT_CHECK_PLUGIN_HELM_DIFF}" != "" ]];then
        helm plugin install https://github.com/databus23/helm-diff &>/dev/null
    fi

    if [[ "${RESULT_CHECK_PLUGIN_HELM_PUSH}" != "" ]];then
        helm plugin install https://github.com/chartmuseum/helm-push.git &>/dev/null
    fi
    return 0
}

function kube_config(){
    check_var "DOWN_USER DOWN_PASSWORD"
    echo "Create ${HOME}/.kube"
    [ -d ${HOME}/.kube ] && rm -rf ${HOME}/.kube
    mkdir ${HOME}/.kube

    download_file "${DOWN_USER}" "${DOWN_PASSWORD}" "${HOME}/.kube/config" "${K8S_DOWNLOAD_CONFIG_URL}"
    kubectl config use-context ${K8S_CONTEXT}
    return 0
}

function docker_deploy_latest(){
    local AZ_ACR_ACCOUNT_URL="${ACR_NAME}.azurecr.io"
    local IMAGE_NAME="${SERVICE_NAME}" 
    local IMAGE_TAG_BUILD="${DOCKER_TAG}"
    
    check_var "STAGE_CURRENT IMAGE_NAME IMAGE_TAG_BUILD"

    docker login -u ${AZ_USER} -p ${AZ_PASSWORD} ${AZ_ACR_ACCOUNT_URL} 2> /dev/null

    if [[ ! $(docker images --format "{{.Repository}}:{{.Tag}}" | grep "${IMAGE_NAME}:${IMAGE_TAG_BUILD}") ]]; then
        echo "[>][WARNING] ${IMAGE_NAME}:${IMAGE_TAG_BUILD} not found"
        docker pull ${AZ_ACR_ACCOUNT_URL}/${IMAGE_NAME}:${IMAGE_TAG_BUILD}
    fi

    docker tag ${AZ_ACR_ACCOUNT_URL}/${IMAGE_NAME}:${IMAGE_TAG_BUILD} ${AZ_ACR_ACCOUNT_URL}/${IMAGE_NAME}:${STAGE_CURRENT}.latest
    docker push ${AZ_ACR_ACCOUNT_URL}/${IMAGE_NAME}:${STAGE_CURRENT}.latest

    return 0
}

function helm_deploy(){
    echo "**************************************"
    echo "*     Helm: Add Helm Repository      *"
    echo "**************************************"
    echo ""

    #### We will check variable before
    check_var "HELM_PRIVATE_REPO_NAME ACR_NAME AZ_USER AZ_PASSWORD"

    echo "[+] Helm client version"
    helm version 2> /dev/null

    echo ""
    echo "[+] Check helm plugin exist again !"
    helm plugin list 2> /dev/null

    echo ""
    echo "[+] Helm add repository of company"
    echo "HELM_PRIVATE_REPO_NAME: ${HELM_PRIVATE_REPO_NAME}"
    echo "AZ_ACR_ACCOUNT_URL: ${ACR_NAME}.azurecr.io"

    if [[ "$(helm repo list 2> /dev/null | grep -i "${HELM_PRIVATE_REPO_NAME}")" ]];then
        # Remove current setting Helm Repo to add new
        helm repo remove ${HELM_PRIVATE_REPO_NAME} 2> /dev/null
    fi

    echo ""
    helm repo add ${HELM_PRIVATE_REPO_NAME} https://${ACR_NAME}.azurecr.io/helm/v1/repo --username ${AZ_USER} --password ${AZ_PASSWORD} 2> /dev/null
    helm registry login ${ACR_NAME}.azurecr.io --username ${AZ_USER} --password ${AZ_PASSWORD} 2> /dev/null

    helm repo update 2> /dev/null
    echo ""
    helm repo list 2> /dev/null
    
    local HELM_NAMESPACE_NAME="${K8S_NAMESPACE}"
    local HELM_RELEASE_NAME="${SERVICE_NAME}"
    local HELM_CHART_NAME="general-application"
    local AZ_ACR_ACCOUNT_URL="${ACR_NAME}.azurecr.io"
    local IMAGE_NAME="${SERVICE_NAME}"
    local IMAGE_TAG_BUILD="${DOCKER_TAG}"

    echo ""
    echo "[+] List active Charts in Helm Chart Repository: ${HELM_PRIVATE_REPO_NAME}"
    helm search repo ${HELM_PRIVATE_REPO_NAME} 2> /dev/null
    echo ""
    echo "**************************************"
    echo "*      Helm: Deploy Application      *"
    echo "**************************************"
    echo -e "\n[+] Start deployment with helm"
    echo "HELM_NAMESPACE_NAME: ${HELM_NAMESPACE_NAME}"
    echo "HELM_RELEASE_NAME: ${HELM_RELEASE_NAME}"
    echo "HELM_CHART_NAME: ${HELM_PRIVATE_REPO_NAME}/${HELM_CHART_NAME}"
    echo "IMAGE_URL: ${AZ_ACR_ACCOUNT_URL}/${IMAGE_NAME}"
    echo "IMAGE_TAG_BUILD: ${IMAGE_TAG_BUILD}"

    # We upgrade helm only, no install helm release from app-repo
    # We define all settings for helm release application in other repository
    CURRENT_UNIXTIME=$(date +%s)
    
    upgrade_helm(){
        if [[ "${HELM_VERSION}" == "latest" || "${HELM_VERSION}" == "" ]];then
            echo "Upgrade with application version: ${HELM_VERSION}"
            helm upgrade ${HELM_RELEASE_NAME} ${HELM_PRIVATE_REPO_NAME}/${HELM_CHART_NAME} \
                --reuse-values \
                --namespace ${HELM_NAMESPACE_NAME} \
                --set image.repository="${AWS_ECR_ACCOUNT_URL}/${IMAGE_NAME}" \
                --set image.tag="${IMAGE_TAG_BUILD}" \
                --set timestamp="${CURRENT_UNIXTIME}" 2> /dev/null
        else
            echo "Upgrade with application version: ${HELM_VERSION}"
            helm upgrade ${HELM_RELEASE_NAME} ${HELM_PRIVATE_REPO_NAME}/${HELM_CHART_NAME} \
                --version ${HELM_VERSION} \
                --reuse-values \
                --namespace ${HELM_NAMESPACE_NAME} \
                --set image.repository="${AWS_ECR_ACCOUNT_URL}/${IMAGE_NAME}" \
                --set image.tag="${IMAGE_TAG_BUILD}" \
                --set timestamp="${CURRENT_UNIXTIME}" 2> /dev/null
        fi
    }

    check_helm(){
        helmReleaseName=$(helm list -n ${HELM_NAMESPACE_NAME} 2> /dev/null | awk '{print $1}' | grep -i ${HELM_RELEASE_NAME} | tr -d ' ' | head -n1)
        if [[ "${helmReleaseName}" == "${HELM_RELEASE_NAME}" ]];then
            upgrade_helm
        else
            echo ""
            echo "[>][WARNING] Sorry, The helm ${HELM_RELEASE_NAME} doesn't exist in list !"
            exit 1
        fi 
    }    

    check_helm
    return 0
}
#### START

function main(){
    # Option based on ${OPTION} arg
    case ${OPTION} in
    "-v" | "--version")
        about
        ;;
    "-h" | "--help")
        help
        ;;
    *)
        pre_checking
        kube_config
        
        if [[ ! helm_deploy ]];then
            exit 1
        fi
        
        docker_deploy_latest
        ;;
    esac
}

main "${@}"

exit 0