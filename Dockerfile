FROM alpine

RUN apk update && \
    apk add --no-cache --upgrade \
        bash \
        jq \
        docker-cli \
        coreutils


RUN addgroup -g 65522 buildpiper && \
    adduser -D -u 65522 -G buildpiper -h /home/buildpiper buildpiper && \
    chown -R buildpiper:buildpiper /home/buildpiper

ENV SLEEP_DURATION=5s


RUN mkdir -p \
        /src/reports \
        /bp/data \
        /bp/execution_dir \
        /opt/buildpiper/shell-functions \
        /opt/buildpiper/data \
        /bp/workspace && \
    chown -R buildpiper:buildpiper /src /bp /opt
    
COPY --chown=buildpiper:buildpiper build.sh /home/buildpiper/build.sh

COPY --chown=buildpiper:buildpiper BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/

RUN chmod +x /home/buildpiper/build.sh && \
    chown -R buildpiper:buildpiper /bp/workspace && \
    mkdir -p /home/buildpiper/reports && \
    chown -R buildpiper:buildpiper /home/buildpiper

USER buildpiper

ENV INFRACOST_API_KEY xxxx

WORKDIR /home/buildpiper

ENV SLEEP_DURATION 5s
ENV MAX_ALLOWED_IMAGE_SIZE 180
ENV VALIDATION_FAILURE_ACTION FAILURE
ENV ACTIVITY_SUB_TASK_CODE IMAGE_SIZE_VALIDATOR

ENTRYPOINT [ "./build.sh" ]