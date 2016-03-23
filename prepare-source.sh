#!/usr/bin/env sh

if [ -z "${APP_NAME}" ]; then
    echo "APP_NAME is not specified"
    exit 1
fi

if [ -z "${VERSION}" ]; then
    echo "VERSION is not specified"
    exit 1
fi

# Volume locations in Docker image
SOURCE_DIR=/source
SOURCES_OUTPUT=/output/SOURCES
SPECS_OUTPUT=/output/SPECS

if [ -n $(ls -A ${SOURCE_DIR}) ]; then
    echo "${SOURCE_DIR} is empty, checking for VCS configuration"
    if [ -n "${SVN_URL}" ]; then
        echo "SVN_URL=${SVN_URL}, using this to get source"
        SVN_EXPORT_CMD="svn export"
        if [ -n "${SVN_OPTIONS}" ]; then
            SVN_EXPORT_CMD="${SVN_EXPORT_CMD} ${SVN_OPTIONS}"
        fi
        SVN_EXPORT_CMD="${SVN_EXPORT_CMD} ${SVN_URL} ${SOURCE_DIR}/export"

        echo "Executing: ${SVN_EXPORT_CMD}"
        ${SVN_EXPORT_CMD} || exit 1

        # Update the source directory to the location of the exported source
        SOURCE_DIR="${SOURCE_DIR}/export"
    else
        echo "${SOURCE_DIR} is empty but no VCS configuration was found"
        exit 1
    fi
fi

if [ -z "${SPEC_FILE}" ]; then
    NUM_SPEC_FILES=$(find ${SOURCE_DIR} -maxdepth 1 -name '*.spec' | wc -l)
    if [ "${NUM_SPEC_FILES}" != "1" ]; then
        echo "SPEC_FILE wasn't specified and ${NUM_SPEC_FILES} *.spec files were found"
        exit 1
    fi
    SPEC_FILE=$(find ${SOURCE_DIR} -maxdepth 1 -name '*.spec')
    echo "SPEC_FILE not specified, using ${SPEC_FILE}"
elif [ ! -e "${SPEC_FILE}" ]; then
    echo "SPEC_FILE ${SPEC_FILE} does not exist"
    exit 1
fi

cp "${SPEC_FILE}" "${SPECS_OUTPUT}"

# If the RELEASE environment variable is set, replace the value of the 'Release' spec file variable with the value from
# the environment variable.
if [ -n "${RELEASE}" ]; then
    sed "s/^Release: .*/Release: ${RELEASE}/" -i "${SPECS_OUTPUT}/$(basename ${SPEC_FILE})"
fi

PACKAGE_NAME="${APP_NAME}-${VERSION}"
TAR_PATH="${SOURCES_OUTPUT}/${PACKAGE_NAME}.tar.gz"

echo "Adding content of ${SOURCE_DIR} to ${TAR_PATH}"

cd /tmp
# Ensure the directory doesn't already exist.
if [ -d "${PACKAGE_NAME}" ]; then
    rm -rf "${PACKAGE_NAME}"
fi

mkdir "${PACKAGE_NAME}"

# Allow additional options to be specified via RSYNC_OPTIONS, this is most likely to be used with --exclude arguments.
rsync -az ${RSYNC_OPTIONS} -- "${SOURCE_DIR}/" "./${PACKAGE_NAME}" || exit 1
tar cfz "${TAR_PATH}" "${PACKAGE_NAME}"

exit 0
