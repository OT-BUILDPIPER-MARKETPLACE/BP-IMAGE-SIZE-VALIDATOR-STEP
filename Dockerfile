FROM alpine
RUN apk add --no-cache --upgrade bash
RUN apk add jq
RUN apk add docker-cli
RUN apk add coreutils
COPY build.sh .
RUN chmod +x build.sh
COPY BP-BASE-SHELL-STEPS/functions.sh .
COPY BP-BASE-SHELL-STEPS/log-functions.sh .
ENV SLEEP_DURATION 5s
ENV MAX_ALLOWED_IMAGE_SIZE 180
ENV VALIDATION_FAILURE_ACTION FAILURE
ENV ACTIVITY_SUB_TASK_CODE IMAGE_SIZE_VALIDATOR
CMD [ "./build.sh" ]
