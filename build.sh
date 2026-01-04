#!/bin/bash

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh
source ./login.sh

COMPONENT_NAME=`getComponentName`
BUILD_REPOSITORY_TAG=`getRepositoryTag`
IMAGE="${COMPONENT_NAME}:${BUILD_REPOSITORY_TAG}"

logInfoMessage "I'll check the docker image layers for ${COMPONENT_NAME} of tag ${BUILD_REPOSITORY_TAG}"
sleep  $SLEEP_DURATION


if docker image inspect "$IMAGE" >/dev/null 2>&1; then
    logInfoMessage "Image found locally: $IMAGE"
else
    logInfoMessage "Logging into configured registries"
    login_all_registries
    logWarningMessage "Image not found locally. Pulling $IMAGE"
    docker pull "$IMAGE"
    logInfoMessage "Image successful pull $IMAGE"
    if [[ $? -ne 0 ]]; then
        logErrorMessage "Failed to pull image: $IMAGE"
        exit 1
    fi
fi

SIZE=`docker image inspect ${COMPONENT_NAME}:${BUILD_REPOSITORY_TAG} --format='{{.Size}}'`
IMAGE_SIZE=`expr $SIZE / 1000000`
 
logInfoMessage "Image size is ${IMAGE_SIZE}MB"
logInfoMessage "Image size allowed is ${MAX_ALLOWED_IMAGE_SIZE}MB"

if [ "${IMAGE_SIZE}" -gt "${MAX_ALLOWED_IMAGE_SIZE}" ]
then
   	generateOutput IMAGE_LAYER_VALIDATOR false "Build failed please check!!!!!"
   if [ $VALIDATION_FAILURE_ACTION == "FAILURE" ]
   then
        logErrorMessage "Size of image is more then expected image size"
        logErrorMessage "Build unsucessfull"
        exit 1

   else
        logWarningMessage "Size of image is more then expected image size please check"
   fi
else
        generateOutput IMAGE_LAYER_VALIDATOR true "Congratulations build succeeded!!!"
        logInfoMessage "Size of a image is under expected image size"
        logInfoMessage "Build sucessfull"
fi
