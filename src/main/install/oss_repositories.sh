#!/usr/bin/env bash

declare -A OSS_REPOSITORIES_DICT
OSS_REPOSITORIES_DICT["oss-doc"]="/infra/oss-doc"
#OSS_REPOSITORIES_DICT["oss-internal"]="/infra/oss-internal"
OSS_REPOSITORIES_DICT["oss-local"]="/infra/oss-local"
OSS_REPOSITORIES_DICT["oss-build"]="/infra/oss-build"
OSS_REPOSITORIES_DICT["oss-lib"]="/infra/oss-lib"
OSS_REPOSITORIES_DICT["oss-platform"]="/infra/oss-platform"
OSS_REPOSITORIES_DICT["oss-environment"]="/infra/oss-environment"
OSS_REPOSITORIES_DICT["oss-eureka-sidecar"]="/infra/oss-eureka-sidecar"
OSS_REPOSITORIES_DICT["oss-samples"]="/infra/oss-samples"
OSS_REPOSITORIES_DICT["oss-archetype"]="/infra/oss-archetype"
OSS_REPOSITORIES_DICT["oss-incubator"]="/infra/oss-incubator"
OSS_REPOSITORIES_DICT["common-config"]="/configserver/common-config"
#OSS_REPOSITORIES_DICT["common-production-config"]="/configserver/common-production-config"
OSS_REPOSITORIES_DICT["oss-todomvc-app-config"]="/configserver/oss-todomvc-app-config"
OSS_REPOSITORIES_DICT["oss-todomvc-gateway-config"]="/configserver/oss-todomvc-gateway-config"
OSS_REPOSITORIES_DICT["oss-todomvc-thymeleaf-config"]="/configserver/oss-todomvc-thymeleaf-config"
#OSS_REPOSITORIES_DICT["oss-jenkins-pipline"]="/infra/oss-jenkins-pipline"
OSS_REPOSITORIES_DICT["oss-jenkins-todomvc"]="/infra/oss-jenkins-todomvc"

#echo "${!OSS_REPOSITORIES_DICT[@]}"
#echo "${OSS_REPOSITORIES_DICT["key"]}"
#for key in ${!OSS_REPOSITORIES_DICT[@]}; do echo ${key}; done
#for value in ${OSS_REPOSITORIES_DICT[@]}; do echo ${value}; done
#echo "OSS_REPOSITORIES_DICT has ${#OSS_REPOSITORIES_DICT[@]} elements"

# 将oss全套项目和配置repo逐个clone到当前目录下

# arguments: git_domain, source_group
function clone_oss_repositories() {
    local git_domain="${1}"
    local source_group="${2}"

    echo "clone_oss_repositories ${git_domain} ${source_group}"
    for repository in ${!OSS_REPOSITORIES_DICT[@]}; do
        original_repository_path=$(echo ${OSS_REPOSITORIES_DICT[${repository}]} | sed 's#^/##')

        if [ ! -z "${source_group}" ]; then
            source_repository_path="${source_group}/${repository}"
            repository_path="${source_repository_path}"
        else
            repository_path="${original_repository_path}"
        fi

        if [ -d ${repository} ] && [ -d ${repository}/.git ]; then
            if [ "${repository_path}" != "${original_repository_path}" ] && [ -z "$(cd ${repository}; git remote -v | grep -E 'upstream.+(fetch)')" ]; then
                (cd ${repository} && git remote add upstream git@${git_domain}:${original_repository_path}.git && git fetch upstream)
            fi
        else
            if [ ! -d ${repository}/.git ]; then
                rm -rf ${repository}
            fi
            echo clone repository ${repository}
            #echo http: ${git_domain}/${repository_path}
            #echo ssh: git@${git_domain}:${repository_path}
            git clone git@${git_domain}:${repository_path}.git
            if [ "${repository_path}" != "${original_repository_path}" ]; then
                (cd ${repository} && git remote add upstream git@${git_domain}:${original_repository_path}.git && git fetch upstream)
            fi
        fi
    done
}
