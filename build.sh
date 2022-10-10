#!/bin/bash
source functions.sh

COMPONENT_NAME=`getComponentName`
BUILD_REPOSITORY_TAG=`getRepositoryTag`
logInfoMessage "I'll check the docker image layers for ${COMPONENT_NAME} of tag ${BUILD_REPOSITORY_TAG}"
sleep  $SLEEP_DURATION

IMAGE_SIZE=`docker image inspect ${COMPONENT_NAME}:${BUILD_REPOSITORY_TAG} --format='{{.Size}}' | numfmt --to=iec | cut -b 1,2,3` 
 
logInfoMessage "Image size is ${IMAGE_SIZE}MB"
logInfoMessage "Image size allowed is ${MAX_ALLOWED_IMAGE_SIZE}MB"

if [ "${IMAGE_SIZE}" -gt "${MAX_ALLOWED_IMAGE_SIZE}" ]
then
   	generateOutput IMAGE_LAYER_VALIDATOR false "Build failed please check!!!!!"
   if [ $VALIDATION_FAILURE_ACTION == "FAILURE" ]
   then
        logErrorMessage "Size of image is more then expected image size"
        logErrorMessage "build unsucessfull"
        exit 1

   else
        logWarningMessage "Size of image is more then expected image size please check"
   fi
else
        generateOutput IMAGE_LAYER_VALIDATOR true "Congratulations build succeeded!!!"
        logInfoMessage "Size of a image is under expected image size"
        logInfoMessage "build sucessfull"
fi
