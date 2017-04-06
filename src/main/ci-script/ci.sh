#!/usr/bin/env bash

if [ -z "${BUILD_DEPENDENCY_CHECK}" ]; then BUILD_DEPENDENCY_CHECK="false"; fi
if [ -z "${BUILD_PUBLISH_DEPLOY_SEGREGATION}" ]; then BUILD_PUBLISH_DEPLOY_SEGREGATION="false"; fi
if [ -z "${BUILD_SITE}" ]; then BUILD_SITE="false"; fi
if [ -z "${BUILD_TEST_FAILURE_IGNORE}" ]; then BUILD_TEST_FAILURE_IGNORE="false"; fi
if [ -z "${BUILD_TEST_SKIP}" ]; then BUILD_TEST_SKIP="false"; fi

echo "MAVEN_SETTINGS_SECURITY_FILE: ${MAVEN_SETTINGS_SECURITY_FILE}"

echo "pwd: $(pwd)"
echo "whoami: $(whoami)"

if [ -f ~/.bashrc ]; then source ~/.bashrc; fi

COMMIT_ID="$(git rev-parse HEAD)"
CI_CACHE="${HOME}/.ci-cache/${COMMIT_ID}"
mkdir -p ${CI_CACHE}

# see: https://gitlab.com/help/ci/variables/README.md
# ${CI_BUILD_REF_NAME} show branch or tag since GitLab-CI 5.2
# ${CI_PROJECT_URL} example: "https://example.com/gitlab-org/gitlab-ce"
if [ -n "${CI_BUILD_REF_NAME}" ] && ([ "${CI_BUILD_REF_NAME}" == "master" ] || [ "${CI_BUILD_REF_NAME}" == "develop" ]); then BUILD_SCRIPT_REF="${CI_BUILD_REF_NAME}"; else BUILD_SCRIPT_REF="develop"; fi
if [ -z "${GIT_SERVICE}" ]; then
    if [ -n "${CI_PROJECT_URL}" ]; then INFRASTRUCTURE="internal"; GIT_SERVICE=$(echo "${CI_PROJECT_URL}" | sed 's,/*[^/]\+/*$,,' | sed 's,/*[^/]\+/*$,,'); else INFRASTRUCTURE="local"; GIT_SERVICE="${LOCAL_GIT_SERVICE}"; fi
fi
BUILD_SCRIPT_LOC="${GIT_SERVICE}/infra/oss-build/raw/${BUILD_SCRIPT_REF}";
BUILD_CONFIG_LOC="${GIT_SERVICE}/infra/oss-${INFRASTRUCTURE}/raw/${BUILD_SCRIPT_REF}"
echo "INFRASTRUCTURE: ${INFRASTRUCTURE}, BUILD_SCRIPT_LOC: ${BUILD_SCRIPT_LOC}, BUILD_CONFIG_LOC: ${BUILD_CONFIG_LOC}"

echo "eval \$(curl -H 'Cache-Control: no-cache' -H \"PRIVATE-TOKEN: \${GIT_SERVICE_TOKEN}\" -s -L ${BUILD_CONFIG_LOC}/src/main/jira/jira-${INFRASTRUCTURE}.sh)"
eval "$(curl -H 'Cache-Control: no-cache' -H "PRIVATE-TOKEN: ${GIT_SERVICE_TOKEN}" -s -L ${BUILD_CONFIG_LOC}/src/main/jira/jira-${INFRASTRUCTURE}.sh)"

# for internal docker auth
if [ "internal" == "${INFRASTRUCTURE}" ]; then
    curl -H 'Cache-Control: no-cache' -H "PRIVATE-TOKEN: ${GIT_SERVICE_TOKEN}" -t utf-8 -s -L -o ~/.docker/config.json ${BUILD_CONFIG_LOC}/src/main/docker/config.json
fi

echo "eval \$(curl -H 'Cache-Control: no-cache' -s -L ${BUILD_SCRIPT_LOC}/src/main/ci-script/lib_java.sh)"
eval "$(curl -H 'Cache-Control: no-cache' -s -L ${BUILD_SCRIPT_LOC}/src/main/ci-script/lib_java.sh)"
echo "eval \$(curl -H 'Cache-Control: no-cache' -s -L ${BUILD_SCRIPT_LOC}/src/main/ci-script/lib_maven.sh)"
eval "$(curl -H 'Cache-Control: no-cache' -s -L ${BUILD_SCRIPT_LOC}/src/main/ci-script/lib_maven.sh)"
echo "eval \$(curl -H 'Cache-Control: no-cache' -s -L ${BUILD_SCRIPT_LOC}/src/main/ci-script/lib_gradle.sh)"
eval "$(curl -H 'Cache-Control: no-cache' -s -L ${BUILD_SCRIPT_LOC}/src/main/ci-script/lib_gradle.sh)"

analysis() {
    echo "analysis @ $(pwd)";
    if [ -f pom.xml ]; then maven_analysis; fi
}

test_and_build() {
    echo "test_and_build @ $(pwd)";
    if [ -f pom.xml ]; then maven_test_and_build; fi
    if [ -f build.gradle ]; then gradle_test_and_build; fi
}

publish_snapshot() {
    echo "publish_snapshot @ $(pwd)";
    export BUILD_PUBLISH_CHANNEL="snapshot"
    if [ -f pom.xml ]; then maven_publish_snapshot; fi
    if [ -f build.gradle ]; then gradle_publish_snapshot; fi
}

publish_release() {
    echo "publish_release @ $(pwd)";
    export BUILD_PUBLISH_CHANNEL="release"
    if [ -f pom.xml ]; then maven_publish_release; fi
    if [ -f build.gradle ]; then gradle_publish_release; fi
}

publish_release_tag() {
    echo "publish_release_tag @ $(pwd)";
}
