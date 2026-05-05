#!/bin/bash

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh
source ./login.sh

# ---------------------------------------------------------------
# NOTE: ACTIVITY_SUB_TASK_CODE is managed by the BuildPiper
#       environment. Do NOT override it here to ensure events
#       appear correctly in the UI.
# ---------------------------------------------------------------

COMPONENT_NAME=$(getComponentName)
BUILD_REPOSITORY_TAG=$(getRepositoryTag)
IMAGE="${COMPONENT_NAME}:${BUILD_REPOSITORY_TAG}"

# ---------------------------------------------------------------
# 1. Initialization
# ---------------------------------------------------------------
logInfoMessage "> Starting step: image_size_validator"
logInfoMessage "> Target image : ${IMAGE}"
logInfoMessage "> Max allowed  : ${MAX_ALLOWED_IMAGE_SIZE}MB"

add_event "INITIALIZATION" "Successful" \
    "Image size validation initialized" \
    "Image: ${IMAGE} | Max allowed: ${MAX_ALLOWED_IMAGE_SIZE}MB"

sleep "$SLEEP_DURATION"

# ---------------------------------------------------------------
# 2. Image Availability Check
# ---------------------------------------------------------------
logInfoMessage "> Checking if image is available locally..."

if docker image inspect "$IMAGE" > /dev/null 2>&1; then
    logInfoMessage "> Image found locally: ${IMAGE}"
    add_event "IMAGE_AVAILABILITY" "Successful" \
        "Image found in local Docker cache" \
        "Image: ${IMAGE}"
else
    logWarningMessage "> Image not found locally. Initiating pull..."
    logInfoMessage "> Logging into configured registries"

    add_event "IMAGE_PULL_INITIATED" "Successful" \
        "Image not found locally — pulling from registry" \
        "Image: ${IMAGE}"

    login_all_registries
    docker pull "$IMAGE"

    if [[ $? -ne 0 ]]; then
        logErrorMessage "> Failed to pull image ${IMAGE} from registry."
        add_event "IMAGE_PULL_FAILED" "Failed" \
            "Could not pull image from registry" \
            "Image: ${IMAGE} | Verify auth, tag, and network connectivity"
        saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
        exit 1
    fi

    logInfoMessage "> Successfully pulled image: ${IMAGE}"
    add_event "IMAGE_PULL_COMPLETE" "Successful" \
        "Image pulled successfully from registry" \
        "Image: ${IMAGE}"
fi

# ---------------------------------------------------------------
# 3. Size Inspection
# ---------------------------------------------------------------
logInfoMessage "> Inspecting image size..."

RAW_SIZE=$(docker image inspect "${IMAGE}" --format='{{.Size}}')
IMAGE_SIZE=$(expr "$RAW_SIZE" / 1000000)

echo ""
echo "> Image Size Inspection Summary"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Parameter" "Value"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Image" "${IMAGE}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Actual Size (MB)" "${IMAGE_SIZE}MB"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Max Allowed Size (MB)" "${MAX_ALLOWED_IMAGE_SIZE}MB"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Utilization" "$((IMAGE_SIZE * 100 / MAX_ALLOWED_IMAGE_SIZE))% of limit"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
echo ""

logInfoMessage "> Image actual size : ${IMAGE_SIZE}MB"
logInfoMessage "> Image allowed size: ${MAX_ALLOWED_IMAGE_SIZE}MB"
logInfoMessage "> Utilization       : $((IMAGE_SIZE * 100 / MAX_ALLOWED_IMAGE_SIZE))% of allowed limit"

# ---------------------------------------------------------------
# 4. Validation Result
# ---------------------------------------------------------------
if [ "${IMAGE_SIZE}" -gt "${MAX_ALLOWED_IMAGE_SIZE}" ]; then

    logWarningMessage "> Image size ${IMAGE_SIZE}MB exceeds the configured limit of ${MAX_ALLOWED_IMAGE_SIZE}MB"

    generateOutput image_size_validator false \
        "Image size validation failed. Current size: ${IMAGE_SIZE}MB exceeds allowed limit: ${MAX_ALLOWED_IMAGE_SIZE}MB. Consider optimizing layers or removing unused dependencies."

    if [ "$VALIDATION_FAILURE_ACTION" == "FAILURE" ]; then
        logErrorMessage "> Action: Blocking build (VALIDATION_FAILURE_ACTION=FAILURE)"
        add_event "SIZE_LIMIT_EXCEEDED" "Failed" \
            "Image size ${IMAGE_SIZE}MB exceeds limit of ${MAX_ALLOWED_IMAGE_SIZE}MB — build blocked" \
            "Image: ${IMAGE} | Action: FAILURE | Reduce image size to proceed"
        saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
        exit 1
    else
        logWarningMessage "> Action: Proceeding with warning (VALIDATION_FAILURE_ACTION=${VALIDATION_FAILURE_ACTION})"
        add_event "SIZE_LIMIT_EXCEEDED_WARNING" "Failed" \
            "Image size ${IMAGE_SIZE}MB exceeds limit but build is allowed to continue" \
            "Image: ${IMAGE} | Action: ${VALIDATION_FAILURE_ACTION} | Review image optimization"
    fi

else
    logInfoMessage "> Validation passed: image size ${IMAGE_SIZE}MB is within the ${MAX_ALLOWED_IMAGE_SIZE}MB limit"

    generateOutput image_size_validator true \
        "Image size validation passed. Image: ${IMAGE} | Size: ${IMAGE_SIZE}MB | Build meets defined size constraints."

    add_event "IMAGE_SIZE_VALIDATION_PASSED" "Successful" \
        "Image ${IMAGE} size validated successfully: ${IMAGE_SIZE}MB within limit of ${MAX_ALLOWED_IMAGE_SIZE}MB" \
        "Utilization: $((IMAGE_SIZE * 100 / MAX_ALLOWED_IMAGE_SIZE))% of allowed size"

    logInfoMessage "> Build successful"
fi

sleep "$SLEEP_DURATION"
saveTaskStatus 0 "${ACTIVITY_SUB_TASK_CODE}"