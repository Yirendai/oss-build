#!/usr/bin/env bash

set -e

#echo "SHELL: ${SHELL}, ZSH_VERSION: ${ZSH_VERSION}, BASH_VERSION: ${BASH_VERSION}"

if [ -z "${DOCKER_NETWORK}" ]; then
    DOCKER_NETWORK="oss-network"
fi
if [ -z "${OSS_WORKSPACE_NAME}" ]; then
    OSS_WORKSPACE_NAME="oss-workspace"
fi
if [ -z "${SHELL_PROFILE}" ]; then
    SHELL_PROFILE="${HOME}/.profile"
fi
if [ ! -f ${SHELL_PROFILE} ]; then
    touch ${SHELL_PROFILE}
    chmod 644 ${SHELL_PROFILE}
fi
if [ -z "${TMP}" ]; then
    TMP="/tmp"
fi

# arguments: lead_pattern, tail_pattern, snippet_file, target_file
append_or_replace() {
    local lead_pattern="$1"
    local tail_pattern="$2"
    local snippet_file="$3"
    local target_file="$4"
    local lead=$(echo "${lead_pattern}" | sed 's/^\^//' | sed 's/\$$//')
    local tail=$(echo "${tail_pattern}" | sed 's/^\^//' | sed 's/\$$//')
    if [[ -z $(grep -E "${lead_pattern}" ${target_file}) ]] || [[ -z $(grep -E "${tail_pattern}" ${target_file}) ]]; then
        if [ -w "${target_file}" ]; then
            echo "${lead}" >> ${target_file}
            cat ${snippet_file} >> ${target_file}
            echo "${tail}" >> ${target_file}
        else
            echo "需要在'${target_file}'文件中追加:"
            echo "${lead}"
            cat ${snippet_file}
            echo "${tail}"
            echo "如果出现提示请输入密码."
            sudo sh -c "echo '${lead}' >> ${target_file}"
            sudo sh -c "cat ${snippet_file} >> ${target_file}"
            sudo sh -c "echo '${tail}' >> ${target_file}"
        fi
    else
        local tmp_file=${TMP}/insert_or_replace.tmp
        # see: http://superuser.com/questions/440013/how-to-replace-part-of-a-text-file-between-markers-with-another-text-file
        /usr/local/opt/gnu-sed/libexec/gnubin/sed -e "/$lead_pattern/,/$tail_pattern/{ /$lead_pattern/{p; r ${snippet_file}
        }; /$tail_pattern/p; d }" ${target_file} > ${tmp_file}
        if [ -w "${target_file}" ]; then
            cat ${tmp_file} > ${target_file}
        else
            echo "需要在'${target_file}'文件中替换:"
            echo "${lead} ... ${tail}之间的内容为:"
            echo "${lead}"
            cat ${snippet_file}
            echo "${tail}"
            echo "如果出现提示请输入密码."
            sudo sh -c "cat ${tmp_file} > ${target_file}"
        fi
    fi
}

brew_install() {
    if [ ! -w /usr/local ]; then
        echo "sudo chown -R $(whoami):wheel /usr/local"
        sudo chown -R $(whoami):wheel /usr/local
    fi
    if ! type -p brew > /dev/null; then
        echo "Installing Homebrew"
        /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
        #brew cask install xquartz
        #brew install homebrew/x11/feh
        #brew install imagemagick
    fi
    if [ -z "$(brew list | grep "^$1$")" ]; then
        brew install $1
    fi
}

detect_ostype() {
    case "$OSTYPE" in
        bsd*)     echo "bsd" ;;
        darwin*)  echo "mac" ;;
        linux*)   echo "linux" ;;
        msys*)    echo "windows" ;;
        solaris*) echo "solaris" ;;
        *)        echo "unknown: $OSTYPE" ;;
    esac
}

find_java_home_on_mac() {
    local found=$(find /Library/Java/JavaVirtualMachines -type d -maxdepth 1 -name "jdk*.jdk" | sort -r | head -n 1)
    if [ -z "${found}" ]; then
        echo ""
    else
        echo "${found}/Contents/Home"
    fi
}

hostip_expression() {
    #echo "ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print \$2}'"
    echo "ipconfig getifaddr en0 || ipconfig getifaddr en1"
}

# arguments: version
install_docker_compose() {
    local version="$1"
    curl -L https://github.com/docker/compose/releases/download/${version}/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
}

# arguments: version
install_waitforit() {
    if ! type -p aria2c > /dev/null; then
        brew_install "aria2"
    fi
    local version="$1"
    if [ -f /usr/local/bin/waitforit ] && [ "${version}" != "v$(/usr/local/bin/waitforit -v | awk '{print $3}')" ]; then
        rm -f /usr/local/bin/waitforit
    fi
    if [ ! -f /usr/local/bin/waitforit ]; then
        local os_name="$(uname -s | tr '[:upper:]' '[:lower:]')"
        local mh_name="amd64"
        local url="https://github.com/maxcnunes/waitforit/releases/download/${version}/waitforit-${os_name}_${mh_name}"
        aria2c --file-allocation=none -c -x 10 -s 10 -m 0 --console-log-level=notice --log-level=notice --summary-interval=0 -d /usr/local/bin -o waitforit "${url}"
        chmod 755 /usr/local/bin/waitforit
    fi
}

# see: http://stackoverflow.com/questions/16989598/bash-comparing-version-numbers
# arguments: first_version, second_version
# return: if first_version is greater than second_version
version_gt() {
    if [ ! -z "$(sort --help | grep GNU)" ]; then
        test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1";
    else
        test "$(printf '%s\n' "$@" | sort | head -n 1)" != "$1";
    fi
}

if [ "mac" != "$(detect_ostype)" ]; then
    ehco "not mac"
    exit 1
fi

# 需要Docker for Mac
if [ ! -d /Applications/Docker.app ]; then
    echo "Please download and install newest Docker for Mac from https://download.docker.com/mac/stable/Docker.dmg"
    exit 1
elif ! type -p docker > /dev/null; then
    echo "Please download and install newest Docker for Mac from https://download.docker.com/mac/stable/Docker.dmg"
    exit 1
elif ! version_gt "$(docker version | grep Version | sort | head -n 1 | awk '{print $2}')" "1.12"; then
    echo "Please download and install newest Docker for Mac from https://download.docker.com/mac/stable/Docker.dmg"
    exit 1
fi
# 创建docker网络
if [[ -z $(docker network ls | awk '{print $2}' | grep ${DOCKER_NETWORK}) ]]; then
    docker network create ${DOCKER_NETWORK}
fi

# 如果需要 单独安装docker-compose 1.9.0或更新的release版
if ! type -p docker-compose > /dev/null; then
    install_docker_compose "1.9.0"
elif ! version_gt "$(docker-compose -version | awk '{print $3}' | sed 's/,//')" "1.8.9"; then
    install_docker_compose "1.9.0"
fi
install_waitforit "v1.4.0"

if [ ! -f ${HOME}/.zshrc ]; then
    echo "Installing oh-my-zsh."
    echo "Note: You need to re-run this install script manually after oh-my-zsh installed."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
fi

##### 安装 Homebrew 和 GNU工具 (Linux用户请忽略这个)
if [ ! -f /usr/local/bin/bash ]; then
    brew_install "bash"
elif ! version_gt "$(/usr/bin/env bash -version | head -n 1 | awk '{print $4}')" "4.2.0(1)-release"; then
    brew_install "bash"
fi
if [ ! -f /usr/local/bin/git ]; then
    brew_install "git"
elif ! version_gt "$(git --version | awk '{print $3}')" "2.10.9"; then
    brew_install "git"
fi
brew_install "gnupg2"
brew_install "coreutils"
brew_install "findutils"
brew_install "gnu-sed"
brew_install "gnu-tar"

# Make zsh source ~/.bash_profile and ~/.profile
oss_dot_zshrc_lead='^### OSS DOT_ZSHRC BEGIN$'
oss_dot_zshrc_tail='^### OSS DOT_ZSHRC END$'
echo "if [ -f \${HOME}/.bash_profile ]; then source \${HOME}/.bash_profile; fi
if [ -f \${HOME}/.profile ]; then source \${HOME}/.profile; fi" > ${TMP}/dot_zshrc
append_or_replace "${oss_dot_zshrc_lead}" "${oss_dot_zshrc_tail}" "${TMP}/dot_zshrc" "${HOME}/.zshrc"

# 编辑 /etc/hosts
oss_hosts_lead='^### OSS HOSTS BEGIN$'
oss_hosts_tail='^### OSS HOSTS END$'
echo "127.0.0.1 localhost $(hostname)
::1 localhost $(hostname)
127.0.0.1 local-admin
127.0.0.1 local-cloudbus
127.0.0.1 local-configserver
127.0.0.1 local-eureka
127.0.0.1 local-eureka-peer1
127.0.0.1 local-eureka-peer2
127.0.0.1 local-eureka-peer3
$($(hostip_expression)) local-fileserver
127.0.0.1 local-git
127.0.0.1 local-mvnsite
127.0.0.1 local-mysql
127.0.0.1 nexus.local
127.0.0.1 local-postgresql
127.0.0.1 local-sonarqube
127.0.0.1 local-oss-todomvc-app
127.0.0.1 local-oss-todomvc-gateway
127.0.0.1 local-oss-todomvc-thymeleaf
127.0.0.1 mirror.docker.local
127.0.0.1 registry.docker.local" > ${TMP}/etc_hosts
append_or_replace "${oss_hosts_lead}" "${oss_hosts_tail}" "${TMP}/etc_hosts" "/etc/hosts"

# 将GNU标准工具配置到PATH靠前位置, 覆盖mac的非标准工具, 提高shell脚本兼容性
oss_brew_path_lead='^### OSS BREW PATH BEGIN$'
oss_brew_path_tail='^### OSS BREW PATH END$'
echo "export PATH=\"/usr/bin:/bin:/usr/sbin:/sbin\"
export PATH=\"/usr/local/bin:/usr/local/sbin:\$PATH\"
export PATH=\"\$(brew --prefix coreutils)/libexec/gnubin:\$PATH\"
export PATH=\"\$(brew --prefix findutils)/bin:\$PATH\"
export PATH=\"/usr/local/opt/gnu-tar/libexec/gnubin:\$PATH\"
export PATH=\"/usr/local/opt/gnu-sed/libexec/gnubin:\$PATH\"" > ${TMP}/brew_path
append_or_replace "${oss_brew_path_lead}" "${oss_brew_path_tail}" "${TMP}/brew_path" "${SHELL_PROFILE}"

# 要求安装JDK 1.8
java_found=$(find_java_home_on_mac)
if [ -z "${java_found}" ]; then
    echo "Please download and install JDK 1.8"
    echo "see: http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html"
    exit 1
fi
# 在${SHELL_PROFILE}中设置JAVA_HOME环境变量
oss_java_home_lead='^### OSS JAVA_HOME BEGIN$'
oss_java_home_tail='^### OSS JAVA_HOME END$'
echo "export JAVA_HOME=\"${java_found}\"" > ${TMP}/java_home
append_or_replace "${oss_java_home_lead}" "${oss_java_home_tail}" "${TMP}/java_home" "${SHELL_PROFILE}"

# 替换JCE策略文件以解禁高强度加密算法
if [ "dabfcb23d7bf9bf5a201c3f6ea9bfb2c" != $($(brew --prefix coreutils)/libexec/gnubin/md5sum ${JAVA_HOME}/jre/lib/security/local_policy.jar | awk '{print $1}') ] || [ "ef6e8eae7d1876d7f05d765d2c2e0529" != $($(brew --prefix coreutils)/libexec/gnubin/md5sum ${JAVA_HOME}/jre/lib/security/US_export_policy.jar | awk '{print $1}') ]; then
    echo "Install JCE Policy"
    curl -s -k -L -C - -b "oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip > /tmp/policy.zip
    sudo sh -c "unzip -p /tmp/policy.zip UnlimitedJCEPolicyJDK8/local_policy.jar > ${JAVA_HOME}/jre/lib/security/local_policy.jar"
    sudo sh -c "unzip -p /tmp/policy.zip UnlimitedJCEPolicyJDK8/US_export_policy.jar > ${JAVA_HOME}/jre/lib/security/US_export_policy.jar"
fi

if ! type -p mvn > /dev/null; then
    brew_install "maven"
elif ! version_gt "$(mvn -version | grep Apache | awk '{print $3}')" "3.3.8"; then
    brew_install "maven"
fi
if ! type -p ant > /dev/null; then
    brew_install "ant"
elif ! version_gt "$(ant -version | grep Apache | awk '{print $4}')" "1.9.6"; then
    brew_install "ant"
fi
# install gradle 2.14
#if ! type -p gradle > /dev/null; then
#    brew_install "gradle214"
#elif ! version_gt "$(gradle -version | grep Gradle | awk '{print $2}')" "2.1.3"; then
#    brew_install "gradle214"
#elif version_gt "$(gradle -version | grep Gradle | awk '{print $2}')" "3.0"; then
#    brew_install "gradle214"
#fi
# install gradle 3.3+
if ! type -p gradle > /dev/null; then
    brew_install "gradle"
elif ! version_gt "$(gradle -version | grep Gradle | awk '{print $2}')" "3.2"; then
    brew_install "gradle"
fi

# 编辑 ~/.ssh/config
if [ ! -d ${HOME}/.ssh ]; then
    mkdir ${HOME}/.ssh
    chmod 700 ${HOME}/.ssh
fi
if [[ ! -f ${HOME}/.ssh/config ]] || [[ -z "$(grep 'Host \*' ${HOME}/.ssh/config)" ]]; then
    touch ${HOME}/.ssh/config
    chmod 644 ${HOME}/.ssh/config
    echo "Host *
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
        Protocol 2
        ServerAliveInterval 30
        ControlMaster auto
        ControlPath ~/.ssh/master-%r@%h:%p
        ControlPersist yes
    " >> ${HOME}/.ssh/config
fi
oss_ssh_config_lead='^### OSS SSH CONFIG BEGIN$'
oss_ssh_config_tail='^### OSS SSH CONFIG END$'
echo "
Host local-git
        HostName local-git
        Port     20022
        User     git
        PreferredAuthentications publickey
        IdentityFile ~/.ssh/local-git

#Host <公司内部git域名>
#        HostName     <公司内部git服务域名>
#        User         git
#        PreferredAuthentications publickey
#        IdentityFile ~/.ssh/internal-git
" > ${TMP}/ssh_config
append_or_replace "${oss_ssh_config_lead}" "${oss_ssh_config_tail}" "${TMP}/ssh_config" "${HOME}/.ssh/config"

# TODO user input
echo "TODO user input"
INTERNAL_DOCKER_REGISTRY="registry.docker.internal"
INTERNAL_FILESERVER="http://nexus2.internal"
INTERNAL_GIT_SERVICE="http://gitlab.internal"
INTERNAL_JIRA="http://jira7.internal"
INTERNAL_MVNSITE_DOMAIN="mvn-site.internal"
INTERNAL_NEXUS="http://nexus2.internal/nexus"
INTERNAL_SONAR="http://sonarqube.internal"
# TODO 要求 fork 项目
echo "TODO 要求 fork 项目"
INTERNAL_GIT_DOMAIN="$(echo ${INTERNAL_GIT_SERVICE} | awk -F/ '{print $3}')"

# 编辑${SHELL_PROFILE}
oss_shell_profile_lead='^### OSS SHELL PROFILE BEGIN$'
oss_shell_profile_tail='^### OSS SHELL PROFILE END$'
echo "# 同步运行docker的host系统时钟, 防止便携电脑休眠/唤醒造成时钟不同步
alias tsync='docker run -it --rm --privileged --pid=host debian nsenter -t 1 -m -u -n -i date -u \$(date -u +%m%d%H%M%Y)'
# 获取docker container ip
alias containerip=\"docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'\"

# HOST_IP_ADDRESS: 取本机内网IP的方法因平台和网络环境而异, 这里以macos为例
export HOST_IP_ADDRESS=\"\$($(hostip_expression))\"

# 配置maven选项
# frontend.nodeDownloadRoot
# https://nodejs.org/dist/v6.9.1/node-v6.9.1-darwin-x64.tar.gz
# https://npm.taobao.org/mirrors/node/v6.9.1/node-v6.9.1-darwin-x64.tar.gz
#
# frontend.npmDownloadRoot
# http://registry.npmjs.org/npm/-/npm-3.10.8.tgz
# http://registry.npm.taobao.org/npm/-/npm-3.10.8.tgz

# 基础设施选项, 指定使用本地(local)或公司内部(internal)基础设施
export INFRASTRUCTURE=\"local\"

export BUILD_PUBLISH_CHANNEL=\"snapshot\"
export BUILD_SITE=\"true\"
export BUILD_TEST_FAILURE_IGNORE=\"false\"

export INTERNAL_DOCKER_REGISTRY=\"${INTERNAL_DOCKER_REGISTRY}\"
export INTERNAL_FILESERVER=\"${INTERNAL_FILESERVER}\"
export INTERNAL_GIT_SERVICE=\"${INTERNAL_GIT_SERVICE}\"
export INTERNAL_JIRA=\"${INTERNAL_JIRA}\"
export INTERNAL_MVNSITE=\"scpexe://${INTERNAL_MVNSITE_DOMAIN}:22/opt/mvn-sites\"
export INTERNAL_NEXUS=\"${INTERNAL_NEXUS}\"
export LOCAL_DOCKER_REGISTRY=\"registry.docker.local\"
export LOCAL_FILESERVER=\"http://local-fileserver:80\"
export LOCAL_GIT_SERVICE=\"http://local-git:20080\"
export LOCAL_MVNSITE=\"dav:http://local-mvnsite:28081/nexus/repository/mvnsite\"
export LOCAL_NEXUS=\"http://nexus.local:28081/nexus\"
export LOCAL_SONAR=\"http://local-sonarqube:9000\"

# 根据 INFRASTRUCTURE 设置服务地址
DOCKER_REGISTRY_VARNAME=\"\$(echo \${INFRASTRUCTURE} | tr '[:lower:]' '[:upper:]')_DOCKER_REGISTRY\"
if [ -n \"\${ZSH_VERSION}\" ]; then
   export DOCKER_REGISTRY=\"\${(P)DOCKER_REGISTRY_VARNAME}\"
elif [ -n \"\$BASH_VERSION\" ]; then
   export DOCKER_REGISTRY=\"\${!DOCKER_REGISTRY_VARNAME}\"
else
   echo \"unsupported shell \${SHELL}\"
fi
FILESERVER_VARNAME=\"\$(echo \${INFRASTRUCTURE} | tr '[:lower:]' '[:upper:]')_FILESERVER\"
if [ -n \"\${ZSH_VERSION}\" ]; then
   export BUILD_FILESERVER=\"\${(P)FILESERVER_VARNAME}\"
elif [ -n \"\$BASH_VERSION\" ]; then
   export BUILD_FILESERVER=\"\${!FILESERVER_VARNAME}\"
else
   echo \"unsupported shell \${SHELL}\"
fi
GIT_SERVICE_VARNAME=\"\$(echo \${INFRASTRUCTURE} | tr '[:lower:]' '[:upper:]')_GIT_SERVICE\"
if [ -n \"\${ZSH_VERSION}\" ]; then
   export GIT_SERVICE=\"\${(P)GIT_SERVICE_VARNAME}\"
elif [ -n \"\$BASH_VERSION\" ]; then
   export GIT_SERVICE=\"\${!GIT_SERVICE_VARNAME}\"
else
   echo \"unsupported shell \${SHELL}\"
fi
# Always use internal jira, no local jira
export JIRA=\"\${INTERNAL_JIRA}\"
NEXUS_VARNAME=\"\$(echo \${INFRASTRUCTURE} | tr '[:lower:]' '[:upper:]')_NEXUS\"
if [ -n \"\${ZSH_VERSION}\" ]; then
   export NEXUS=\"\${(P)NEXUS_VARNAME}\"
elif [ -n \"\$BASH_VERSION\" ]; then
   export NEXUS=\"\${!NEXUS_VARNAME}\"
else
   echo \"unsupported shell \${SHELL}\"
fi

export MAVEN_OPTS=\"\"
export MAVEN_OPTS=\"\${MAVEN_OPTS} -Dbuild.publish.channel=\${BUILD_PUBLISH_CHANNEL}\"
# 此处GIT_SERVICE相关设置 假设公司内部和本地git服务访问raw文件的方式相同, 即 <项目>/raw/<ref>/<文件路径>, 如假设不满足需单独设置
export MAVEN_OPTS=\"\${MAVEN_OPTS} -Dcheckstyle.config.location=\${GIT_SERVICE}/infra/oss-build/raw/master/src/main/checkstyle/google_checks_6.19.xml\"
export MAVEN_OPTS=\"\${MAVEN_OPTS} -Ddocker.registry=\${DOCKER_REGISTRY}\"
# 此处frontend设置 假设公司内部和本地都使用nexus3, 并且contextPath都为nexus, 如假设不满足需单独设置
export MAVEN_OPTS=\"\${MAVEN_OPTS} -Dfrontend.nodeDownloadRoot=\${NEXUS}/nexus/repository/npm-dist/\"
export MAVEN_OPTS=\"\${MAVEN_OPTS} -Dfrontend.npmDownloadRoot=\${NEXUS}/nexus/repository/npm-public/npm/-/\"
export MAVEN_OPTS=\"\${MAVEN_OPTS} -Dinternal-mvnsite.prefix=\${INTERNAL_MVNSITE}\"
export MAVEN_OPTS=\"\${MAVEN_OPTS} -Dinternal-nexus.mirror=\${INTERNAL_NEXUS}/content/groups/public/\"
export MAVEN_OPTS=\"\${MAVEN_OPTS} -Dinternal-nexus.repositories=\${INTERNAL_NEXUS}/content/repositories\"
export MAVEN_OPTS=\"\${MAVEN_OPTS} -Dinternal-sonar.host.url=\${INTERNAL_SONAR}\"
export MAVEN_OPTS=\"\${MAVEN_OPTS} -Dlocal-mvnsite.prefix=\${LOCAL_MVNSITE}\"
export MAVEN_OPTS=\"\${MAVEN_OPTS} -Dnexus.local.mirror=\${LOCAL_NEXUS}/repository/maven-public/\"
export MAVEN_OPTS=\"\${MAVEN_OPTS} -Dnexus.local.repositories=\${LOCAL_NEXUS}/repository\"
export MAVEN_OPTS=\"\${MAVEN_OPTS} -Dlocal-sonar.host.url=\${LOCAL_SONAR}\"
export MAVEN_OPTS=\"\${MAVEN_OPTS} -Dmaven.test.failure.ignore=\${BUILD_TEST_FAILURE_IGNORE}\"
# 此处GIT_SERVICE相关设置 假设公司内部和本地git服务访问raw文件的方式相同, 即 <项目>/raw/<ref>/<文件路径>, 如假设不满足需单独设置
export MAVEN_OPTS=\"\${MAVEN_OPTS} -Dpmd.ruleset.location=\${GIT_SERVICE}/infra/oss-build/raw/master/src/main/pmd/pmd-ruleset-5.3.5.xml\"
export MAVEN_OPTS=\"\${MAVEN_OPTS} -Dinfrastructure=\${INFRASTRUCTURE}\"
export MAVEN_OPTS=\"\${MAVEN_OPTS} -Dsite=\${BUILD_SITE}\"
export MAVEN_OPTS=\"\${MAVEN_OPTS} -Duser.language=zh -Duser.region=CN -Dfile.encoding=UTF-8 -Duser.timezone=Asia/Shanghai\"

function oss_vm_options() {
    local vm_options=""
    vm_options=\"\${vm_options} -Dbuild.publish.channel=snapshot\"
    vm_options=\"\${vm_options} -Dcheckstyle.config.location=\${GIT_SERVICE}/infra/oss-build/raw/master/src/main/checkstyle/google_checks_6.19.xml\"
    vm_options=\"\${vm_options} -Ddocker.registry=\${DOCKER_REGISTRY}\"
    vm_options=\"\${vm_options} -Dfrontend.nodeDownloadRoot=\${NEXUS}/nexus/repository/npm-dist/\"
    vm_options=\"\${vm_options} -Dfrontend.npmDownloadRoot=\${NEXUS}/nexus/repository/npm-public/npm/-/\"
    vm_options=\"\${vm_options} -Dinternal-mvnsite.prefix=\${INTERNAL_MVNSITE}\"
    vm_options=\"\${vm_options} -Dinternal-nexus.mirror=\${INTERNAL_NEXUS}/content/groups/public/\"
    vm_options=\"\${vm_options} -Dinternal-nexus.repositories=\${INTERNAL_NEXUS}/content/repositories\"
    vm_options=\"\${vm_options} -Dlocal-mvnsite.prefix=\${LOCAL_MVNSITE}\"
    vm_options=\"\${vm_options} -Dnexus.local.mirror=\${LOCAL_NEXUS}/repository/maven-public/\"
    vm_options=\"\${vm_options} -Dnexus.local.repositories=\${LOCAL_NEXUS}/repository\"
    vm_options=\"\${vm_options} -Dpmd.ruleset.location=\${GIT_SERVICE}/infra/oss-build/raw/master/src/main/pmd/pmd-ruleset-5.3.5.xml\"
    vm_options=\"\${vm_options} -Dinfrastructure=\${INFRASTRUCTURE}\"
    echo \"\${vm_options}\"
}
alias oss-vmopts=\"oss_vm_options\"

function oss_npmrc() {
    echo \"Execute following commands
npm config set registry \${NEXUS}/nexus/repository/npm-public/
npm config set cache \${HOME}/.npm/.cache/npm
npm config set disturl \${NEXUS}/nexus/repository/npm-dist/
npm config set sass_binary_site \${NEXUS}/nexus/repository/npm-sass/
or edit \${HOME}/.npmrc file
registry=\${NEXUS}/nexus/repository/npm-public/
cache=\${HOME}/.npm/.cache/npm
disturl=\${NEXUS}/nexus/repository/npm-dist/
sass_binary_site=\${NEXUS}/nexus/repository/npm-sass/\"
}
alias oss-npmrc=\"oss_npmrc\"" > ${TMP}/shell_profile
append_or_replace "${oss_shell_profile_lead}" "${oss_shell_profile_tail}" "${TMP}/shell_profile" "${SHELL_PROFILE}"
source ${SHELL_PROFILE}

while [[ ! -w ${HOME}/.ssh/internal-git ]] || [[ -z $(grep -E "^[^#].*internal-git" ${HOME}/.ssh/config) ]]; do
    echo "请完成下列操作:"
    echo "1. 手动替换 ${HOME}/.ssh/config中的 '<公司内部git域名>', 解除相关注释"
    echo "2. 将internal-git主机的配置移出从### OSS SSH CONFIG BEGIN至### OSS SSH CONFIG END的范围"
    echo "3. 将访问公司内部git的私钥放到'${HOME}/.ssh/internal-git'"
    echo "请注意: '${HOME}/.ssh/internal-git'应只属于用户'$(whoami)', 权限应为'600', 其他用户和其他用户组无权访问"
    read -p "操作完成后按 ENTER 键继续"
done
chown $(whoami) ${HOME}/.ssh/internal-git && chmod 600 ${HOME}/.ssh/internal-git

OSS_MAVEN_SETTINGS_LOCATION="${INTERNAL_GIT_SERVICE}/infra/oss-build/raw/master/src/main/maven/settings.xml"
if [ ! -f ${HOME}/.m2/settings.xml ]; then
    echo "未找到'${HOME}/.m2/settings.xml'文件, 自动从'${OSS_MAVEN_SETTINGS_LOCATION}'下载."
    curl -H 'Cache-Control: no-cache' -s -o ${HOME}/.m2/settings.xml -L ${OSS_MAVEN_SETTINGS_LOCATION}
else
    echo "发现'${HOME}/.m2/settings.xml'文件, 请确保其内容与'${OSS_MAVEN_SETTINGS_LOCATION}'等效."
    read -p "检查'${HOME}/.m2/settings.xml'完成后按 ENTER 键继续"
fi
OSS_MAVEN_SETTINGS_SECURITY_LOCATION="${INTERNAL_GIT_SERVICE}/infra/oss-build/raw/master/src/main/maven/settings-security.xml"
if [ ! -f ${HOME}/.m2/settings-security.xml ]; then
    echo "未找到'${HOME}/.m2/settings-security.xml'文件, 自动从'${OSS_MAVEN_SETTINGS_SECURITY_LOCATION}'下载."
    echo "注意: 下载得到的settings-security.xml文件不包含有效的主密码."
    curl -H 'Cache-Control: no-cache' -s -o ${HOME}/.m2/settings-security.xml -L ${OSS_MAVEN_SETTINGS_SECURITY_LOCATION}
    echo "请编辑'${HOME}/.m2/settings-security.xml', 填写有效的master密码, 可以找组织内部知晓该密码的人询问."
else
    echo "发现'${HOME}/.m2/settings-security.xml'文件, 请确填写了有效的master密码(可以找组织内部知晓该密码的人询问)."
    echo "如果在'mvn deploy'时遇到认证错误(如401错误), 这很可能是settings-security.xml内容不正确导致的."
    read -p "检查'${HOME}/.m2/settings-security.xml'完成后按 ENTER 键继续"
fi
# mvn: command not found
#MAVEN_HOME="$(mvn -version | grep 'Maven home' | awk '{print $3}')"
MAVEN_HOME="$(brew --prefix maven)/libexec"
if [ -f ${MAVEN_HOME}/conf/settings.xml ]; then
    echo "发现'${MAVEN_HOME}/conf/settings.xml'文件, 请检查其内容, 以免其与'${HOME}/.m2/settings.xml'的内容冲突, 出现隐蔽的错误."
    read -p "检查'${MAVEN_HOME}/conf/settings.xml'完成后按 ENTER 键继续"
fi

$(brew --prefix)/opt/bash/bin/bash -c "
set -e

if [ -z \"\${INFRASTRUCTURE}\" ]; then
    echo \"在${SHELL_PROFILE}中设置的环境变量在这里可能没生效, 为避免造成隐蔽的错误, 终止执行.\"
    exit 1
fi

if [ ! -f oss_repositories.sh ]; then
    eval \$(curl -H 'Cache-Control: no-cache' -s -L ${INTERNAL_GIT_SERVICE}/infra/oss-build/raw/develop/src/main/install/oss_repositories.sh)
else
    . oss_repositories.sh
fi

if [ \"${OSS_WORKSPACE_NAME}\" != \"\$(basename \$(pwd))\" ]; then
    mkdir -p ${OSS_WORKSPACE_NAME}
    cd ${OSS_WORKSPACE_NAME}
fi

echo \"为了保证构建工作的速度, 请设置docker mirror和registry\"
echo \"例如: 在Mac上需要 设置Preferences... -> Advanced -> Insecure registries: 和 Registry mirrors:\"
echo \"Insecure registries 需要设置 <公司内部docker-registry域名>\"
echo \"Registry mirrors 建议中国用户使用 http://hub-mirror.c.163.com, 启动nexus.local以后可以设置为http://registry.docker.local:5001\"
read -p \"检查Docker设置完成后按 ENTER 键继续\"

# 将oss全套项目和配置repo逐个clone到当前目录下
for repository in \${!OSS_REPOSITORIES_DICT[@]}; do
    repository_path=\$(echo \${OSS_REPOSITORIES_DICT[\${repository}]} | sed 's#^/##')
    #rm -rf \${repository}
    if [ ! -d \${repository} ]; then
        echo clone repository \${repository}
        #echo http: ${INTERNAL_GIT_SERVICE}/\${repository_path}
        #echo ssh: git@${INTERNAL_GIT_DOMAIN}:\${repository_path}
        git clone git@${INTERNAL_GIT_DOMAIN}:\${repository_path}
    elif [ ! -d \${repository}/.git ]; then
        echo clone repository \${repository}
        #echo http: ${INTERNAL_GIT_SERVICE}/\${repository_path}
        #echo ssh: git@${INTERNAL_GIT_DOMAIN}:\${repository_path}
        rm -rf \${repository}
        git clone git@${INTERNAL_GIT_DOMAIN}:\${repository_path}
    fi
    # TODO git checkout master
    (cd \${repository}; if ! git rev-parse --verify master > /dev/null; then git fetch; git branch --track master origin/master; fi)
done

#(cd oss-environment/oss-docker/nexus3 && docker-compose build && docker-compose up -d)
#eval \$(curl -H 'Cache-Control: no-cache' -s -L ${INTERNAL_GIT_SERVICE}/infra/oss-build/raw/develop/src/main/install/files.sh)
#(cd oss-environment/oss-docker/gogs && docker-compose build && docker-compose up -d)
#waitforit -full-connection=tcp://local-git:20080 -timeout=600
#waitforit -full-connection=tcp://local-git:20022 -timeout=600
sleep 10
docker exec local-git /app/gogs/entrypoint.sh export_git_admin_key > ~/.ssh/local-git && chmod 600 ~/.ssh/local-git;
#waitforit -full-connection=tcp://nexus.local:28081 -timeout=600
#waitforit -full-connection=tcp://nexus.local:5000 -timeout=600
sleep 10

#(cd oss-build && mvn clean install deploy)
#(cd oss-build && mvn site site:stage site:stage-deploy)
#(cd oss-lib && mvn clean install deploy)
#(cd oss-lib && mvn site site:stage site:stage-deploy)
#(cd oss-platform && mvn clean install deploy)
#(cd oss-platform && mvn site site:stage site:stage-deploy)
#(cd oss-environment && mvn clean install deploy)
#(cd oss-environment && mvn site site:stage site:stage-deploy)

echo Start local-eureka
#(cd oss-environment/oss-eureka && docker-compose up -d)
#waitforit -full-connection=tcp://local-eureka:8761 -timeout=600
echo Start local-cloudbus
#(cd oss-environment/oss-cloudbus && docker-compose up -d)
#waitforit -full-connection=tcp://local-cloudbus:5672 -timeout=600
#waitforit -full-connection=tcp://local-cloudbus:15672 -timeout=600
echo Start local-configserver
#(cd oss-environment/oss-configserver && docker-compose up -d)
#waitforit -full-connection=tcp://local-configserver:8888 -timeout=600
"

echo
echo "请在所有开启的终端窗口内 手动执行 source ${SHELL_PROFILE}"
echo "注意: ${SHELL_PROFILE} 中配置的环境变量不影响 IDE, IDE必须单独配置, 具体方法请参考'CONTRIBUTION.md'文档"
echo "如果需要构建gitbook或node/npm项目, 建议配置'~/.npmrc'以加速下载, 执行'oss-npmrc'命令, 并按提示设置."
