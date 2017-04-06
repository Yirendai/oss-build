#!/usr/bin/env bash

declare -A OSS_CDNS_DICT
OSS_CDNS_DICT["cdn-zhl"]="http://o9wbz99tz.bkt.clouddn.com"
OSS_CDNS_DICT["cdn-zzc"]="http://oe94ialfu.bkt.clouddn.com"

declare -A OSS_FILES_DICT
OSS_FILES_DICT["rancheros-v0.7.1.iso"]="https://github.com/rancher/os/releases/download/v0.7.1/rancheros.iso"
OSS_FILES_DICT["rancheros-v0.8.0-rc9.iso"]="https://github.com/rancher/os/releases/download/v0.8.0-rc9/rancheros.iso"
OSS_FILES_DICT["maven-3.3.9-bin.tar.gz"]="https://mirrors.tuna.tsinghua.edu.cn/apache/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz"
OSS_FILES_DICT["gradle-2.14.1-bin.zip"]="https://downloads.gradle.org/distributions/gradle-2.14.1-bin.zip"
OSS_FILES_DICT["apache-ant-1.9.9-bin.zip"]="http://mirrors.tuna.tsinghua.edu.cn/apache//ant/binaries/apache-ant-1.9.9-bin.zip"
OSS_FILES_DICT["gradle-3.3-bin.zip"]="https://downloads.gradle.org/distributions/gradle-3.3-bin.zip"
OSS_FILES_DICT["docker-machine-Linux-x86_64-v0.8.2"]="https://github.com/docker/machine/releases/download/v0.8.2/docker-machine-Linux-x86_64"
OSS_FILES_DICT["docker-machine-Linux-x86_64-v0.9.0"]="https://github.com/docker/machine/releases/download/v0.9.0/docker-machine-Linux-x86_64"
OSS_FILES_DICT["docker-compose-Linux-x86_64-1.10.0"]="https://github.com/docker/compose/releases/download/1.10.0/docker-compose-Linux-x86_64"
# https://circle-artifacts.com/gh/andyshinn/alpine-pkg-glibc/6/artifacts/0/home/ubuntu/alpine-pkg-glibc/packages/x86_64/glibc-2.21-r2.apk
OSS_FILES_DICT["glibc-2.23-r3.apk"]="https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.23-r3/glibc-2.23-r3.apk"
OSS_FILES_DICT["jdk-8u101-linux-x64.tar.gz"]="http://download.oracle.com/otn-pub/java/jdk/8u101-b13/jdk-8u101-linux-x64.tar.gz"
OSS_FILES_DICT["jce_policy-8.zip"]="http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip"
# H "Cookie: oraclelicense=accept-securebackup-cookie"
# -b "oraclelicense=accept-securebackup-cookie"
OSS_FILES_DICT["node-v6.9.2-linux-x64.tar.xz"]="https://nodejs.org/dist/v6.9.2/node-v6.9.2-linux-x64.tar.xz"
# see: https://github.com/maxcnunes/waitforit
OSS_FILES_DICT["waitforit-linux_amd64-v1.3.2"]="https://github.com/maxcnunes/waitforit/releases/download/v1.3.2/waitforit-linux_amd64"
OSS_FILES_DICT["waitforit-linux_amd64-v1.4.0"]="https://github.com/maxcnunes/waitforit/releases/download/v1.4.0/waitforit-linux_amd64"
OSS_FILES_DICT["docker-registry.crt"]="http://o9wbz99tz.bkt.clouddn.com/docker-registry.crt?v=fuck_cdn_cache_$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)"

DOWNLOAD_CACHE="${HOME}/.oss-cache"
mkdir -p ${DOWNLOAD_CACHE}

for filename in ${!OSS_FILES_DICT[@]}; do
    original_url="${OSS_FILES_DICT[${filename}]}"
    #original_url_status=$(curl --head --silent ${original_url} | head -n 1 | awk '{print $2}')
    #if [ "200" == "${original_url_status}" ] || [ "302" == "${original_url_status}" ]; then
    #    echo "ok ${original_url}"
    #else
    #    echo "${original_url_status} ${original_url}"
    #fi

    original_protocol=$(echo ${original_url} | awk -F:// '{print $1}')
    original_host_port=$(echo ${original_url} | awk -F/ '{print $3}')
    original_fileserver="${original_protocol}://${original_host_port}"

    download_url="${original_url}"
    for cdn in ${!OSS_CDNS_DICT[@]}; do
        cdn_server="${OSS_CDNS_DICT[${cdn}]}"
        cdn_url=$(echo ${original_url} | sed "s#${original_fileserver}#${cdn_server}#")
        cdn_url_status=$(curl --head --silent ${cdn_url} | head -n 1)
        if echo "${cdn_url_status}" | grep -q 200; then
            download_url="${cdn_url}"
            break
        #else
        #    echo "cdn_url ${cdn_url}, status ${cdn_url_status}"
        fi
    done
    #echo "download_url ${download_url}"

    original_path=$(dirname ${original_url} | sed "s#${original_fileserver}##" | sed 's#^/##')
    original_file=$(basename ${original_url} | sed 's/\?.*//' | sed 's/#.*//')
    if [ ! -z "${original_path}" ]; then
        download_path="${DOWNLOAD_CACHE}/${original_path}"
    else
        download_path="${DOWNLOAD_CACHE}"
    fi
    mkdir -p ${download_path}
    download_target="${download_path}/${original_file}"

    if [ ! -f "${download_target}" ] || [ ! -f "${download_target}.sha1" ] || [ "$(cat ${download_target}.sha1)" != "$(sha1sum ${download_target} | awk '{print $1}')" ]; then
        echo "download ${download_url} into ${download_target}"
        aria2c --header="Cookie: oraclelicense=accept-securebackup-cookie" \
            --file-allocation=none \
            -c -x 10 -s 10 -m 0 \
            --console-log-level=notice --log-level=notice --summary-interval=0 \
            -d "${download_path}" -o "${original_file}" "${download_url}"
        sha1sum=$(sha1sum ${download_target} | awk '{print $1}')
        echo "${sha1sum}" > ${download_target}.sha1
    else
        echo "found cached at ${download_target}"
    fi
done


if [ -z "${BUILD_FILESERVER}" ]; then
    BUILD_FILESERVER="http://local-fileserver:80"
fi
FOUND_FILES=($(find ${DOWNLOAD_CACHE} -type f | grep -Ev ".sha1$"))
for found_file in "${FOUND_FILES[@]}"; do
    if [ -f "${found_file}.sha1" ] && [ "$(cat ${found_file}.sha1)" == "$(sha1sum ${found_file} | awk '{print $1}')" ]; then
        upload_path=$(echo ${found_file} | sed "s#${DOWNLOAD_CACHE}##" | sed 's#^/##')
        echo "found_file ${found_file}"

        upload_url="${BUILD_FILESERVER}/${upload_path}"
        upload_url_status=$(curl --head --silent ${upload_url}.sha1 | head -n 1 | awk '{print $2}')
        if [ "404" == "${upload_url_status}" ] || [ "$(cat ${found_file}.sha1)" != "$(curl --silent ${upload_url}.sha1)" ]; then
            echo "${upload_url_status} upload_url ${upload_url}"
            # TODO 从文件读取用户名密码
            curl --silent --user "deployment:deployment" -T "${found_file}" "${upload_url}"
            curl --silent --user "deployment:deployment" -T "${found_file}.sha1" "${upload_url}.sha1"
            if [ "$(cat ${found_file}.sha1)" == "$(curl --silent ${upload_url}.sha1)" ]; then
                echo "upload done $(curl --silent ${upload_url}.sha1)"
            fi
        else
            echo "${upload_url_status} skip upload_url ${upload_url}"
        fi
    else
        echo "incomplete download ${found_file}"
    fi
done
