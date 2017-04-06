
# oss-build父pom

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<big>**要**</big>更好地实现微服务, 要控制好软件质量, 
oss-build父pom是用于管理软件工程的, 它不定义依赖版本.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<big>**o**</big>ss-build父pom通过为子项目设置maven插件来管理软件工程。
目前oss-build父pom定义了你使用的maven的最低版本,java版本(java8),字符编码(UTF-8),常见的插件等内容。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<big>**o**</big>ss-build之下的所有项目都有一个网站, 
这些网站是使用maven自动生成的. 在每次push代码的时候, gitlab-ci都会进行构建并发布网站. 网站中包含项目的基本信息和软件工程方面的报告.
这些网站都是借助oss-build父pom生成的, [详见](MVNSITE.html).

## 如何使用oss-build父pom

在maven的pom中设置parent为oss-build:

        <parent>
            <groupId>com.yirendai.oss</groupId>
            <artifactId>oss-build</artifactId>
            <version>1.0.8.OSS-SNAPSHOT</version>
        </parent>

这不会引入任何依赖, oss-build只管理软件工程, 不会干扰项目依赖管理.

我们做了代码和环境分离以及发布和部署分离，好处是我们的项目可以非常安全地开源，并且很容易切换环境，
缺点就是你需要设置一些环境变量来告诉我们:

+ 使用哪个nexus
+ 使用哪个docker-registry
+ checkstyle配置文件在哪里
+ pmd配置文件在哪里

等诸如此类的信息.
如何在命令行环境和IDE中设置这些环境变量请参考[CONTRIBUTION](./CONTRIBUTION.html)

## oss-build引入的重要插件有

+ docker-maven-plugin
    > 为应用或服务构建docker镜像,并且可以push到registry

+ git-commit-id-plugin
    > 在构建项目时生成src/main/resources/git.properties文件,这样在运行时可以知道项目的版本

+ jacoco-maven-plugin
    > 非常好的测试覆盖度报告插件

+ maven-compiler-plugin
    > 定义java源码和编译目标的版本,源码字符编码等默认编译设置

+ maven-enforcer-plugin
    > 通过此插件来避免隐蔽的依赖冲突

+ maven-source-plugin
    > 用来构建项目的源码包,使项目用户更容易debug

+ gitflow-maven-plugin
    > 实践gitflow版本控制模型(如何进行release, feature, hotfix)时用到的maven插件,使用方法详见[GITFLOW](GITFLOW.html)

## oss-build定义的profile

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<big>**除**</big>了上述插件,oss-build父pom还定义了几个profile,可以按需激活或禁用.

+ dependency-check
    > 生成详细的项目依赖分析报告,使用`mvn -Ddependency-check=true`激活,需要与后面的`site`profile配合使用.
    这个操作耗时较长,不建议在构建SNAPSHOT版本时开启,所以默认是不启用的.

+ git-commit-id
    > 当检测到项目存在.git时自动启用,使用git-commit-id-plugin生成src/main/resources/git.properties文件

+ jacoco
    > 默认激活,使用jacoco-maven-plugin生成项目测试覆盖度报告.当使用`-Djacoco=false`运行maven构建时禁用.

+ local_nexus
    > 使用用户本地的nexus服务(详见[oss-environment/oss-docker/nexus3](../oss-environment/OSS_DOCKER_LOCALNEXUS.html)),
    并且将网站发布到本地的maven网站(详见[oss-environment/oss-docker/mvn-site](../oss-environment/OSS_DOCKER_MVNSITE.html))上.

+ site
    > 生成项目的网站,使用`mvn -Dsite=true site site:stage site:stage-deploy`激活并构建网站,使用`-Dsite.path=oss-build-snapshot`指定网站在目标服务器上的目录名.我们通常将网站发布到一台打开列目录选项的nginx服务器上.

+ internal_nexus
    > 使用公司内部的nexus服务,并且将网站发布到公司内部的maven网站上
