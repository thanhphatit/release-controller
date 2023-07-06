#!/bin/bash
IMAGE_NAME='nginx'
IMAGE_TAG_BUILD='latest'
if [[ ! $(docker images --format "{{.Repository}}:{{.Tag}}" | grep "${IMAGE_NAME}:${IMAGE_TAG_BUILD}") ]]; then
    echo "[*][WARNING] ${IMAGE_NAME}:${IMAGE_TAG_BUILD} not found"
    docker pull ${AZ_ACR_ACCOUNT_URL}/${IMAGE_NAME}:${IMAGE_TAG_BUILD}
fi