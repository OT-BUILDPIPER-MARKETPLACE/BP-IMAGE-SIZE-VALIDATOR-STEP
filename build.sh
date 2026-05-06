#!/usr/bin/env bash

set -euo pipefail

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh
source ./login.sh

# ---------------------------------------------------------------
# 🔧 CONFIG
# ---------------------------------------------------------------
COMPONENT_NAME=$(getComponentName)
BUILD_REPOSITORY_TAG=$(getRepositoryTag)
IMAGE="${COMPONENT_NAME}:${BUILD_REPOSITORY_TAG}"

MAX_SIZE_MB="${MAX_ALLOWED_IMAGE_SIZE:-200}"
VALIDATION_ACTION="${VALIDATION_FAILURE_ACTION:-FAILURE}"

logInfoMessage "> Starting step: image_size_validator"
logInfoMessage "> Target image : ${IMAGE}"
logInfoMessage "> Max allowed  : ${MAX_SIZE_MB}MB"

add_event "INITIALIZATION" "Successful" \
    "Image size validation initialized" \
    "Image: ${IMAGE} | Max allowed: ${MAX_SIZE_MB}MB"

sleep "${SLEEP_DURATION:-0}"

# ---------------------------------------------------------------
# 🔐 LOGIN
# ---------------------------------------------------------------
logInfoMessage "> Logging into registry"
login_all_registries

# ---------------------------------------------------------------
# 📦 FETCH MANIFEST (multi-arch aware)
# ---------------------------------------------------------------
logInfoMessage "> Fetching image manifest..."

MANIFEST_RAW=$(skopeo inspect --raw "docker://${IMAGE}" 2>/dev/null || true)

if [[ -z "$MANIFEST_RAW" ]]; then
    logErrorMessage "> Failed to fetch manifest"
    add_event "IMAGE_FETCH_FAILED" "Failed" \
        "Could not fetch manifest" \
        "Image: ${IMAGE}"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

# ---------------------------------------------------------------
# 🧠 DETECT MANIFEST TYPE
# ---------------------------------------------------------------
MANIFEST_TYPE=$(echo "$MANIFEST_RAW | jq -r '.mediaType // empty'" 2>/dev/null || true)

TOTAL_SIZE=0

# ---------------------------------------------------------------
# 🟢 CASE 1: MULTI-ARCH (manifest list)
# ---------------------------------------------------------------
if echo "$MANIFEST_RAW" | jq -e '.manifests' >/dev/null 2>&1; then
    logInfoMessage "> Multi-arch image detected"

    DIGESTS=$(echo "$MANIFEST_RAW" | jq -r '.manifests[].digest')

    for DIGEST in $DIGESTS; do
        logInfoMessage "> Processing platform digest: $DIGEST"

        CHILD_MANIFEST=$(skopeo inspect --raw "docker://${IMAGE%@*}@${DIGEST}" 2>/dev/null)

        SIZE=$(echo "$CHILD_MANIFEST" | jq '[.layers[].size // 0] | add')

        if [[ -z "$SIZE" || "$SIZE" == "null" ]]; then
            logWarningMessage "> Skipping invalid layer data for digest: $DIGEST"
            continue
        fi

        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
    done

# ---------------------------------------------------------------
# 🔵 CASE 2: SINGLE ARCH IMAGE
# ---------------------------------------------------------------
else
    logInfoMessage "> Single-arch image detected"

    TOTAL_SIZE=$(echo "$MANIFEST_RAW" | jq '[.layers[].size // 0] | add')
fi

# ---------------------------------------------------------------
# ❌ VALIDATION: SIZE FETCH
# ---------------------------------------------------------------
if [[ -z "$TOTAL_SIZE" || "$TOTAL_SIZE" -eq 0 ]]; then
    logErrorMessage "> Failed to compute image size"
    add_event "SIZE_COMPUTE_FAILED" "Failed" \
        "Unable to compute image size" \
        "Image: ${IMAGE}"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

# ---------------------------------------------------------------
# 📊 CONVERT SIZE
# ---------------------------------------------------------------
IMAGE_SIZE_MB=$(awk "BEGIN {printf \"%.0f\", $TOTAL_SIZE/1024/1024}")
UTILIZATION=$((IMAGE_SIZE_MB * 100 / MAX_SIZE_MB))

# ---------------------------------------------------------------
# 📊 OUTPUT
# ---------------------------------------------------------------
echo ""
echo "> Image Size Inspection Summary"
printf '| %-28s | %-48s |\n' "Image" "${IMAGE}"
printf '| %-28s | %-48s |\n' "Size (Compressed MB)" "${IMAGE_SIZE_MB}MB"
printf '| %-28s | %-48s |\n' "Max Allowed (MB)" "${MAX_SIZE_MB}MB"
printf '| %-28s | %-48s |\n' "Utilization" "${UTILIZATION}%"
echo ""

add_event "IMAGE_FETCH_SUCCESS" "Successful" \
    "Image metadata fetched and size calculated" \
    "Image: ${IMAGE} | Size: ${IMAGE_SIZE_MB}MB"

# ---------------------------------------------------------------
# 🚦 VALIDATION
# ---------------------------------------------------------------
if [[ "$IMAGE_SIZE_MB" -gt "$MAX_SIZE_MB" ]]; then

    logWarningMessage "> Image size ${IMAGE_SIZE_MB}MB exceeds limit ${MAX_SIZE_MB}MB"

    if [[ "$VALIDATION_ACTION" == "FAILURE" ]]; then
        add_event "SIZE_LIMIT_EXCEEDED" "Failed" \
            "Image exceeds allowed size" \
            "Image: ${IMAGE} | Size: ${IMAGE_SIZE_MB}MB"
        saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
        exit 1
    else
        add_event "SIZE_LIMIT_EXCEEDED_WARNING" "Failed" \
            "Image exceeds size but allowed" \
            "Image: ${IMAGE}"
    fi

else
    logInfoMessage "> Validation passed"

    add_event "IMAGE_SIZE_VALIDATION_PASSED" "Successful" \
        "Image size within limit" \
        "Image: ${IMAGE} | Size: ${IMAGE_SIZE_MB}MB"
fi

# ---------------------------------------------------------------
# ✅ COMPLETE
# ---------------------------------------------------------------
saveTaskStatus 0 "${ACTIVITY_SUB_TASK_CODE}"