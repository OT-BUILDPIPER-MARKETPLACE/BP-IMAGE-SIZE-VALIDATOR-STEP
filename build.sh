#!/bin/bash

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh
source ./login.sh

debug=true

COMPONENT_NAME=`getComponentName`
BUILD_REPOSITORY_TAG=`getRepositoryTag`
IMAGE="${COMPONENT_NAME}:${BUILD_REPOSITORY_TAG}"

# Event: Starting the size check process
add_event "SIZE CHECK START" "Successful" \
            "Initializing size inspection" \
            "Target: $IMAGE"

logInfoMessage "I'll check the docker image SIZE for ${COMPONENT_NAME} of tag ${BUILD_REPOSITORY_TAG}"
sleep  $SLEEP_DURATION


if docker image inspect "$IMAGE" >/dev/null 2>&1; then
    logInfoMessage "Image found locally: $IMAGE"
else
    logWarningMessage "Image not found locally. Pulling $IMAGE"
    logInfoMessage "Logging into configured registries"
    
    # Event: Pulling from registry
    add_event "IMAGE PULL INITIATED" "Successful" \
                "Image not found locally" \
                "Pulling $IMAGE from registry"

    login_all_registries
    docker pull "$IMAGE"
    
    if [[ $? -ne 0 ]]; then
        # Event: Pull Failure
        add_event "IMAGE PULL FAILED" "Failed" \
                    "Failed to pull image: $IMAGE" \
                    "Check registry login or network"
        logErrorMessage "Failed to pull image: $IMAGE"
        exit 1
    fi
    logInfoMessage "Image successful pull $IMAGE"
fi

SIZE=`docker image inspect ${COMPONENT_NAME}:${BUILD_REPOSITORY_TAG} --format='{{.Size}}'`
IMAGE_SIZE=`expr $SIZE / 1000000`
 
logInfoMessage "Image size is ${IMAGE_SIZE}MB"
logInfoMessage "Image size allowed is ${MAX_ALLOWED_IMAGE_SIZE}MB"

if [ "${IMAGE_SIZE}" -gt "${MAX_ALLOWED_IMAGE_SIZE}" ]
then
    generateOutput IMAGE_SIZE_VALIDATOR false "Build failed please check!!!!!"
   if [ $VALIDATION_FAILURE_ACTION == "FAILURE" ]
   then
        # Event: Blocking Failure
        add_event "SIZE LIMIT EXCEEDED" "Failed" \
                    "Image size ${IMAGE_SIZE}MB exceeds limit ${MAX_ALLOWED_IMAGE_SIZE}MB" \
                    "Action: Blocking build"
        logErrorMessage "Size of image is more then expected image size"
        logErrorMessage "Build unsucessfull"
        exit 1

   else
        # Event: Non-blocking Warning
        add_event "SIZE LIMIT WARNING" "Warning" \
                    "Image size ${IMAGE_SIZE}MB is over the limit" \
                    "Action: Proceeding per config"
        logWarningMessage "Size of image is more then expected image size please check"
   fi
else
        # Event: Success
        add_event "SIZE LIMIT PASSED" "Successful" \
                    "Image size ${IMAGE_SIZE}MB is within limits" \
                    "Limit: ${MAX_ALLOWED_IMAGE_SIZE}MB"
        generateOutput IMAGE_SIZE_VALIDATOR true "Congratulations build succeeded!!!"
        logInfoMessage "Size of a image is under expected image size"
        logInfoMessage "Build sucessful"
fi