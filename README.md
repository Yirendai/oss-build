-----
如果你正在通过git服务查看此文档，请移步项目网站或gitbook查看文档，因为git服务生成的文档链接有问题。
+ [gitbook](http://mvn-site.internal/oss-build-develop/gitbook)
+ [RELEASE版网站](http://mvn-site.internal/oss-build/staging)
+ [SNAPSHOT版网站](http://mvn-site.internal/oss-build-develop/staging)
-----

# oss是什么
-----

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<big>**如**</big>果你只是想使用oss-build作为parent
pom进行静态代码检查，或只是使用它包含的其他软件工程工具，请参考[oss-build父pom](./INTRODUCTION.html)。<br/>
<br/>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<big>**o**</big>ss-build即宜人贷开源技术栈是由
很多功能各异的基于spring-boot的项目组成的，它们是基于spring的微服务架构的基石。这些项目有的负责控制软件工程质量，
有的提供依赖管理帮助你避免依赖地狱，有的提供库来帮助你加速开发，减少完成工作所需的代码，有的提供微服务架构所需的基础
服务等等。<br/>
<br/>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<big>**微**</big>服务架构需要的核心服务有 
服务注册发现, 配置中心；其它辅助服务有管理控制台等。oss已经提供这些服务。在公司办公网络和线上环境都有部署，可以直接
使用。无法访问内网服务的时候可以通过docker镜像在本地启动这些服务。
> 详情见[oss-environment](../oss-environment/)。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<big>**在**</big>微服务架构中服务和服务之间需要
经常传递一些信息，比如下层服务的异常/错误需要抛到上层服务甚至一直到达前端(客户端/页面应用)，关于用户身份和权限的安全信息
(Token)。此外还需要监控服务的，自动生成文档等功能。oss考虑到了这些需求，把它们包装在一些库里面，可以按需引入。
> 详情见[oss-lib](../oss-lib/)。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<big>**s**</big>pring-boot,spring-cloud
和spring-data是一个很大的项目家族，它们之间有版本依赖关系，而且还依赖很多第三方库。用错任何一个库的版本都会可能导致服务
无法启动或隐蔽的运行时错误。为了降低编写pom或build.gradle的难度，oss已经为你精心定义好了全部库的版本，只要在pom.xml
或build.gradle中引入我们提供的pom，就无需再关心版本冲突。
> 详情见[oss-platform](../oss-platform/)。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<big>**现**</big>代软件是复杂的，控制软件质量一直
都不是一件容易的事，oss不仅提供构建微服务架构需要的组件，还提供软件工程工具，以使你的服务更健壮。在代码质量方便，oss
提供了一系列基于maven的代码静态检查工具，它们已经精心配置过，可以直接在构建时使用；此外我们还选择了相应的IDE插件，并提供
配置方法让它们与maven使用同一套代码静态检查规则，在开发阶段实时检查代码质量，帮助IDE自动格式化或检查代码格式；oss会
自动生成测试覆盖度报告，依赖分析报告，软件包划分合理性报告等等。这些报告和项目相关文档都会聚合在这样的maven网站中, 非常便于
查看。
> 详情见[oss-build父pom](./INTRODUCTION.html)

## oss家族成员

+ [oss-build](./INTRODUCTION.html)技术栈的软件工程pom.
    - [oss-dependency](./oss-dependency/)技术栈依赖管理, 用户一般通过引入oss-platform使用.
    - [oss-environment](../oss-environment/)微服务运行时环境, 提供基础服务和小工具.
    - [oss-lib](../oss-lib/)微服务程序库, 用户一般通过引入oss-platform使用.
    - [oss-platform](../oss-platform/)整合技术栈依赖管理和微服务程序库.
    - [oss-samples](../oss-samples/)样例项目, 展示如何利用oss提供的服务和库.
    - [common-config](http://gitlab.internal/configserver/common-config)公共配置, 通过oss-configserver提供给微服务.
    - [oss-todomvc-app-config](http://gitlab.internal/configserver/oss-todomvc-app-config)todomvc样例项目的配置, 通过oss-configserver提供给样例服务.
    - [oss-todomvc-gateway-config](http://gitlab.internal/configserver/oss-todomvc-gateway-config)todomvc样例项目的配置, 通过oss-configserver提供给样例服务.
    - [oss-todomvc-thymeleaf-config](http://gitlab.internal/configserver/oss-todomvc-thymeleaf-config)todomvc样例项目的配置, 通过oss-configserver提供给样例服务.

