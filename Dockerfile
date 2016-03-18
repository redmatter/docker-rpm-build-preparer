FROM alpine

COPY prepare-source.sh /

ENV SPEC_FILE= \
    APP_NAME= \
    VERSION=

VOLUME /source
VOLUME /output/SOURCES
VOLUME /output/SPECS

ENTRYPOINT [ "/prepare-source.sh" ]
