FROM dgupta9068/dind_base:1.0
RUN apk add --no-cache --upgrade bash
RUN apk add jq
COPY build.sh .
COPY BP-BASE-SHELL-STEPS/functions.sh .
ENV SLEEP_DURATION 5s
ENV IMAGE_SIZE 900
ENV COMPONENT_NAME BUILD_REPOSITORY_TAG
ENV ACTIVITY_SUB_TASK_CODE IMAGE_SIZE_VALIDATOR
CMD [ "./build.sh" ]
