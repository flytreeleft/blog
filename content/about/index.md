---
layout: page
title: About me
date: 2017-05-14 18:29:18
tags:
copyright: false
---

## 个人展示

- 个人站点： https://flytreeleft.org、 https://flytreeleft.github.io
- Github： https://github.com/flytreeleft
- Twitter: https://twitter.com/flytreeleft
- Email： flytreeleft@126.com

## 自我评价

- 踏实肯干，具有较硬的技术基础。密切关注前沿技术，不断学习以充实自我
- 学以致用，在架构设计和研发过程中推陈出新，适当引入新的技术和设计理念
- 勤于思考，不固化观念，保持一颗年轻的心
- 善于解决问题，打破砂锅问到底，先分析问题本质，再有针对性地提出多种解决方案，权衡并选择最优的解决方案

## 专业技能

- 从事8年Java项目开发，具备J2EE项目开发、项目架构设计、代码优化与调试经验
- 熟悉Web前端和后端开发流程及相关技术：Spring、Spring MVC、Hibernate、MyBatis、jQuery、Vue.js、Node.js、Webpack、Electron、TypeScript、ES6等
- 熟悉MySQL、H2、Oracle等关系数据库，可熟练编写SQL代码进行简单或复杂的业务查询，具备MySQL主从架构部署经验
- 具备JVM调试与调优经验，能够通过jstack、jmap、Eclipse Memory Analyzer等工具定位堆栈溢出、线程死锁等问题
- 能够熟练编写JUnit单元测试，并具备Apache JMeter性能测试和脚本编写经验
- 具备良好的技术文档编写能力，对代码质量和规范的要求严格，同时乐于以文档形式与他人分享技术难点攻克技巧
- 熟悉Linux系统运维，能够熟练编写Bash、Ansible Playbooks等脚本，也具备一定的Python、Lua等编程基础
- 具备CI/CD、DevOps工具集的部署、维护和管理经验：Gitlab、Jenkins、Nexus3、Nginx、Sonar、MediaWiki、Keycloak、Rocket.Chat、ELK、Grafana等
- 具备Kubernetes高可用集群的部署和维护经验，能够在Kubernetes集群中部署、配置和管理各种应用，熟悉Helm的使用

## 开源项目

### [nexus3-keycloak-plugin](https://github.com/flytreeleft/nexus3-keycloak-plugin)

支持[Keycloak](https://www.keycloak.org/)用户统一认证的[Sonatype Nexus3](https://www.sonatype.com/nexus-repository-oss)插件。

其支持并提供如下特性：
- 将Keycloak的Client Role、Realm Role、Realm Group三类角色/组映射为Nexus3的角色，以支持不同层级的用户权限控制需求
- 支持多个Keycloak Realm（至多4个），从而满足组织同时对内部和外部用户（两类用户隔离在不同的Realm中）的访问控制需求
- 在Nginx反向代理的配合下实现基于Keycloak的单点登录（SSO）和二次登录验证

### [docker-nginx-gateway](https://github.com/flytreeleft/docker-nginx-gateway)

[Nginx](https://www.nginx.com/)网关（反向代理）的Docker镜像构建脚本。

其提供特性如下：
- 可启用[Let’s Encrypt](https://letsencrypt.org/) HTTPS站点
- 支持通过[certbot](https://certbot.eff.org/docs/using.html)自动为域名创建和更新[Let’s Encrypt](https://letsencrypt.org/)证书
- 支持显示自定义的错误（500、404等）页面，且在有多个错误页面时能够做到随机展示
- 可加载并执行[Lua](https://github.com/openresty/lua-nginx-module)脚本
- 支持反向代理HTTP和TCP流量
- 每个域名采用独立的配置文件，根据实际需求以提供静态站点服务或反向代理至后端服务
- 支持在Kubernetes中以多个Pod副本运行
- 支持访问日志按天滚动写入日志文件，如，`access_2018-04-26.log`
- 支持通过OpenID（使用[lua-resty-openidc](https://github.com/zmartzone/lua-resty-openidc)实现）进行用户访问认证，并可将指定IP加入白名单
- 可在构建镜像时设定是否引入[GeoIp2](https://github.com/leev/ngx_http_geoip2_module)地址库
- 集成[Gixy](https://github.com/yandex/gixy)以分析和检查Nginx配置是否存在安全问题

### [GtkShot](https://github.com/flytreeleft/GtkShot)

基于[GTK2](https://developer.gnome.org/gtk2/)的Linux屏幕截图工具。

其具备如下特性：
- 支持快捷键撤销、保存、移动选取等操作
- 支持线、框、圈、文字等涂鸦
- 可保存截图至剪贴板或文件
- 提供友好的选区位置/大小、初始时的界面操作等辅助提示（支持中英文双语）

### 其他

向多个开源项目提交PR，贡献缺陷修复、功能改进、新增功能、文档修正等：
- [ansible/ansible](https://github.com/ansible/ansible)：对`vmware_*`相关模块的改进和缺陷修复（长期未被接受，导致修复代码过期，已关闭）
- [kubernetes/website](https://github.com/kubernetes/website)：提交对文档中有关MySQL主从配置示例中的错误修复和相关改进（已合并）
- [webpack-contrib/webpack-hot-middleware](https://github.com/webpack-contrib/webpack-hot-middleware)：缺陷修复和功能改进（已合并）
- [Semantic-Org/Semantic-UI](https://github.com/Semantic-Org/Semantic-UI)：改进和完善Slider组件（已合并，但似乎未进入主干）
- [erikw/tmux-powerline](https://github.com/erikw/tmux-powerline)：提供基于Yahoo天气的模块，并改进和修复其他多个模块（已合并）
- [docker-library/mysql](https://github.com/docker-library/mysql)：提交MySQL初始账号授权不生效的修复（未合并）
- [vuejs/vue](https://github.com/vuejs/vue)：提交缺陷修复代码，改进构建脚本等（已合并）
- [Activiti/Activiti](https://github.com/Activiti/Activiti)：提交缺陷修复和功能改进代码（已合并）
- [react-dnd/react-dnd](https://github.com/react-dnd/react-dnd)：添加新的场景使用示例（未被接受，已关闭）
- [mitre/HTTP-Proxy-Servlet](https://github.com/mitre/HTTP-Proxy-Servlet)：缺陷修复（已合并）
- [hawtio/hawtio-oauth](https://github.com/hawtio/hawtio-oauth)：缺陷修复（已合并）
- ...

## 项目经验

- 在部门内引入并推广Maven项目构建、CI/CD持续集成、Git源码管理、统一登录（SSO）、代码分支管理、Wiki文档管理、代码质量控制、缺陷管理等开发机制和流程，并独立搭建相关环境，进而提升部门产品的开发、测试、发布效率
- 将部门内的运维工具、产品演示服务、产品演示数据库等全部容器化部署和管理，从而降低运维难度和工作量
- 尝试部署高可用的[Kubernetes](https://kubernetes.io/)集群，并在其上搭建DevOps和日志分析平台，但由于机房环境和主机设备不稳定等因素影响而始终未能如愿
- 编写[Ansible Playbook](https://www.ansible.com/)脚本为客户搭建具备3个Master节点的高可用Kubernetes集群环境，并在其上部署和运行部门的产品，实现运维产品服务的高可用
- 负责分析并查找产品性能低下、高内存占用、数据库连接池耗尽等问题，通过JVM内存分析、接口调用监控等方式最终定位根源并有针对性地提出改进和规避方案
- 负责维护和开发部门的运维产品，设计并实现多个核心组件和功能模块，如，CI关系视图、数据归档、数据访问权限控制、Hibernate热加载/热更新BO Class等
- 自行设计并实现类似[Jenkins Pipeline](https://jenkins.io/doc/book/pipeline/syntax/)的任务调度和编排机制，支持任务调度、解析和执行Pipeline脚本（Groovy）、本地或远端执行Bash脚本、文件传输、运行Ansible Playbook等功能
- 基于[mxGraph](https://github.com/jgraph/mxgraph) JS图形库设计并开发CMDB资产生命周期（入库、出库、维护等）设计器
- 基于[Activiti](https://github.com/Activiti/Activiti) 5流程引擎做业务层封装，支持在不修改源码的基础上做业务功能扩展和增强：外部人员组织机构适配；流程跳转、委办、退回、会签等
- 基于[Apache Camel](https://camel.apache.org/)实现多类型接收端点的消息发送框架
- 基于[Vue.js](https://vuejs.org)设计并开发UI设计器，但由于设计的复杂度、个人整体把控能力不足等问题而最终被搁置
- 基于[YAVI Java API](https://github.com/yavijava/yavijava)开发VMware vCenter集群管理的组件库，支持对虚拟主机、网络等资源的管理
- 基于[fabric8io/kubernetes-client](https://github.com/fabric8io/kubernetes-client)设计并开发多租户平台，实现将部门的运维产品按租户部署至Kubernetes集群并独立运行和访问
- 基于[Electron](https://electronjs.org/)为客户开发自助服务终端App，支持身份证读取和二维码扫描功能
