#!/bin/bash
source functions.sh

echo "I'll check the docker image size for ${COMPONENT_NAME} of tag ${BUILD_REPOSITORY_TAG}"
COMPONENT_NAME=`cat /bp/data/environment_build | jq -r .build_detail.repository.name`
BUILD_REPOSITORY_TAG=`cat /bp/data/environment_build | jq -r .build_detail.repository.tag`
sleep $SLEEP_DURATION
dockersize() { docker manifest inspect -v "$1" | jq -c 'if type == "array" then .[] else . end' |  jq -r '[ ( .Descriptor.platform | [ .os, .architecture, .variant, ."os.version" ] | del(..|nulls) | join("/") ), ( [ .SchemaV2Manifest.layers[].size ] | add ) ] | join(" ")' | numfmt --to iec --format '%.2f' --field 2 | column -t ; }
image_category=`dockersize $COMPONENT_NAME:$BUILD_REPOSITORY_TAG`
echo $image_category
statuses=`dockersize $COMPONENT_NAME:$BUILD_REPOSITORY_TAG | awk '$2 <=${IMAGE_SIZE}M {printf "OK\n" ;} $2 > ${IMAGE_SIZE}M {printf "FAILED\n";}'`
echo $statuses
flag=0
for status in $statuses
do
  if [ "${status}" == "FAILED" ]
  then
    flags=$(($flag+1))
  fi
done
echo $flags
if (($flags > 0))
then
  echo "stage failed"
  exit 1
else
  echo "staged passed"
  exit 0
fi
