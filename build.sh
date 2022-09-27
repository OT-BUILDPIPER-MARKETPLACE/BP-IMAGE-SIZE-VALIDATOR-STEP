#!/bin/bash
source functions.sh

COMPONENT_NAME=`cat /bp/data/environment_build | jq -r .build_detail.repository.name`
BUILD_REPOSITORY_TAG=`cat /bp/data/environment_build | jq -r .build_detail.repository.tag`

echo "I'll check the docker image size for ${COMPONENT_NAME} of tag ${BUILD_REPOSITORY_TAG}"
sleep $SLEEP_DURATION
IMAGE_SIZE=`docker  inspect -f "{{ .Size }}"  registry.buildpiper.in/gatekeeping/dev/dev:27-20220920T0420`

if [ $IMAGE_SIZE -gt $MAX_ALLOWED_IMAGE_SIZE ]
then 
      echo "Image size is not in expected limits"
	    exit 1
else
      echo "Image size is in limits"
      exit
fi