#!/usr/bin/env sh

if [[ -z ${APP_NAME} ]]; then
    echo "APP_NAME is not specified"
    exit 1
fi

if [[ -z ${VERSION} ]]; then
    echo "VERSION is not specified"
    exit 1
fi

# Volume locations in Docker image
SOURCE_DIR=/source
SOURCES_OUTPUT=/output/SOURCES
SPECS_OUTPUT=/output/SPECS

if [[ -z ${SPEC_FILE} ]]; then
    NUM_SPEC_FILES=$(find ${SOURCE_DIR} -maxdepth 1 -name '*.spec' | wc -l)
    if [[ ${NUM_SPEC_FILES} != "1" ]]; then
        echo "SPEC_FILE wasn't specified and ${NUM_SPEC_FILES} *.spec files were found"
        exit 1
    fi
    SPEC_FILE=$(find ${SOURCE_DIR} -maxdepth 1 -name '*.spec')
    echo "SPEC_FILE not specified, using ${SPEC_FILE}"
fi

cp ${SPEC_FILE} ${SPECS_OUTPUT}

PACKAGE_NAME=${APP_NAME}-${VERSION}
TAR_PATH=${SOURCES_OUTPUT}/${PACKAGE_NAME}.tar.gz

echo "Adding content of ${SOURCE_DIR} to ${TAR_PATH}"

cd /tmp
# Ensure the directory doesn't already exist.
if [[ -d ${PACKAGE_NAME} ]]; then
    rm -rf ${PACKAGE_NAME}
fi

mkdir ${PACKAGE_NAME}

cp -r ${SOURCE_DIR}/* ./${PACKAGE_NAME}/
tar cfz ${TAR_PATH} ${PACKAGE_NAME}

exit 0
