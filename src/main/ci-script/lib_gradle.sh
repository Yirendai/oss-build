#!/usr/bin/env bash

set -e

if [ ! -z "${GRADLE_INIT_SCRIPT}" ]; then
    if [[ "${GRADLE_INIT_SCRIPT}" == http* ]]; then
        GRADLE_INIT_SCRIPT_FILE="${CI_CACHE}/$(basename $(echo ${GRADLE_INIT_SCRIPT}))"
        curl -H 'Cache-Control: no-cache' -t utf-8 -s -L -o ${GRADLE_INIT_SCRIPT_FILE} ${GRADLE_INIT_SCRIPT}
        echo "curl -H 'Cache-Control: no-cache' -t utf-8 -s -L -o ${GRADLE_INIT_SCRIPT_FILE} ${GRADLE_INIT_SCRIPT}"
        export GRADLE_PROPERTIES="${GRADLE_PROPERTIES} --init-script ${GRADLE_INIT_SCRIPT_FILE}"
    else
        export GRADLE_PROPERTIES="${GRADLE_PROPERTIES} --init-script ${GRADLE_INIT_SCRIPT}"
    fi
fi

export GRADLE_PROPERTIES="${GRADLE_PROPERTIES} -Pinfrastructure=${INFRASTRUCTURE}"
export GRADLE_PROPERTIES="${GRADLE_PROPERTIES} -PtestFailureIgnore=${BUILD_TEST_FAILURE_IGNORE}"
export GRADLE_PROPERTIES="${GRADLE_PROPERTIES} -Psettings=${MAVEN_SETTINGS_FILE}"

if [ -n "${MAVEN_SETTINGS_SECURITY_FILE}" ]; then
  export GRADLE_PROPERTIES="${GRADLE_PROPERTIES} -Psettings.security=${MAVEN_SETTINGS_SECURITY_FILE}"
fi
echo "gradle_properties: ${GRADLE_PROPERTIES}"
gradle -version

gradle_analysis() {
    echo "gradle_analysis no-op"
}

gradle_test_and_build() {
    if [ "true" == "${BUILD_TEST_SKIP}" ]; then
        gradle --refresh-dependencies ${GRADLE_PROPERTIES} clean build install -x test
    else
        gradle --refresh-dependencies ${GRADLE_PROPERTIES} clean build integrationTest install
    fi
}

gradle_publish_snapshot() {
    gradle ${GRADLE_PROPERTIES} uploadArchives -x test
}

gradle_publish_release() {
    gradle ${GRADLE_PROPERTIES} uploadArchives -x test
}
