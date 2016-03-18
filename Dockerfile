FROM alpine

RUN apk update && \
    apk add subversion openssh-client

COPY prepare-source.sh /

VOLUME /source
VOLUME /output/SOURCES
VOLUME /output/SPECS

ENTRYPOINT [ "/prepare-source.sh" ]
