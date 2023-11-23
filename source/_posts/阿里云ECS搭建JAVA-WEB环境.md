---
title: 阿里云ECS搭建JAVA WEB环境
seo_title: build-java-web-env-in-aliyun-ecs
date: 2017-06-17 09:46:02
tags: [ECS,环境搭建]
categories: [Java]
---

## 购买配置阿里云服务器ECS
[阿里云服务器ECS](https://www.aliyun.com/product/ecs/)
> 云服务器（Elastic Compute Service，简称 ECS）是一种简单高效、处理能力可弹性伸缩的计算服务，帮助您快速构建更稳定、安全的应用，提升运维效率，降低 IT 成本，使您更专注于核心业务创新。

### 选购服务器
从产品主页直接进入到选购页面就可以了。选择自己需要的服务器就好。主要有如下可选项:
- 计费方式
- 地域(服务器所在地域,考虑翻墙的请选择境外的)
- 网络(这个比较坑，有经典网络和专有网络两种，默认的是专有网络，经典网络和专有网络部互通。 如果自己只是弄一个服务器玩玩的话选经典网络就好)
- 实例(服务器的硬件配置)
- 带宽
- 镜像(服务器的操作系统)
- 存储(默认已经有40G硬盘,不够可可以额外购买)
- 安全设置(主要设置SSH远程连接时的用户密码)

<!--more-->

### 服务器网络设置
购买成功后进入控制台可以看到自己服务器的基本信息和可操作项,主要有以下两点需要注意:
1. 分配的公网IP和私网IP (随后需要使用公网IP远程SSH到服务器)
2. 右侧的功能选项(管理 远程连接等)

当我们直接使用公网IP访问我们服务器的时候发现是无法连通的。通过`telnet ip port`的时候会提示无法连接
```bat
D:\Users\Vioao\Desktop>telnet 39.108.129.25 80
正在连接39.108.129.25...无法打开到主机的连接。 在端口 80: 连接失败
```
这是由于阿里云ECS的安全策略的导致的，默认的安全策略只开放了TCP的22端口和3389端口(用于给Linux/Windows 系统的远程连接)以及全部ICMP。
不过一般我们可能会需要能通过公网IP访问服务器的web应用服务，这时候就需要开启TCP 的80端口或443端口了(这边还打开了8080端口)。官方提供了对应的配置文档:
[允许公网通过 HTTP、HTTPS 等服务访问实例](https://help.aliyun.com/document_detail/25475.html?spm=5176.2020520101.121.1.fKFdDZ#allowHttp)

---

## 搭建JAVA WEB环境
这边是想将一个开源的电商系统 [Shopizer](http://www.shopizer.com/) 部署到服务器上，所需需要搭建配置一个JAVA WEB环境。
> **Shopizer** 是一个基于Web的销售管理和电子商务内容管理系统（CMS）。主要功能包括：购物车，库存管理，付款和运输，订单管理，在线发票和订单跟踪。

我的系统的CentOs 7, 64 Bit, 需要的环境依赖有:
- JDK
- MySql
- Tomcat
- ElasticSearch

### 安装JDK
使用yum直接安装openjdk 简单方便

#### yum list/yum search 查找需要安装的软件
```
[root@iZwz9en2rvi1v3yo0vkhouZ ~]# yum list java*
Loaded plugins: fastestmirror
Loading mirror speeds from cached hostfile
Installed Packages
java-1.8.0-openjdk.x86_64                    1:1.8.0.131-3.b12.el7_3    @updates
java-1.8.0-openjdk-headless.x86_64           1:1.8.0.131-3.b12.el7_3    @updates
javamail.noarch                              1.4.6-8.el7                @base
javapackages-tools.noarch                    3.4.1-11.el7               @base
Available Packages
java-1.6.0-openjdk.x86_64                    1:1.6.0.41-1.13.13.1.el7_3 updates
java-1.6.0-openjdk-demo.x86_64               1:1.6.0.41-1.13.13.1.el7_3 updates
java-1.6.0-openjdk-devel.x86_64              1:1.6.0.41-1.13.13.1.el7_3 updates
...
```

#### yum install jdk
这里选择的是64位的JDK8，执行如下命令即可：
```
yum install java-1.8.0-openjdk.x86_64
```

#### 查看jdk是否安装成功
安装后执行java命令看看是否安装成功
```
[root@iZwz9en2rvi1v3yo0vkhouZ ~]# java -version
openjdk version "1.8.0_131"
OpenJDK Runtime Environment (build 1.8.0_131-b12)
OpenJDK 64-Bit Server VM (build 25.131-b12, mixed mode)
```

#### 查看安装目录
安装后可以通过whereis命令查找对应的安装目录
```
[root@iZwz9en2rvi1v3yo0vkhouZ ~]# whereis java
java: /usr/bin/java /usr/lib/java /etc/java /usr/share/java /usr/share/man/man1/java.1.gz
```

### 安装启动MySql
本来打算按照安装jdk的步骤来安装MySql，结果发现查找不到mysql服务的安装包。于是只能去官网下载安装包自己安装了。步骤如下:

#### 下载安装Mysql
官网下载mysql的rpm安装包:[下载页面](https://dev.mysql.com/downloads/repo/yum/)
```
wget https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm
rpm -ivh mysql-community-release-el7-5.noarch.rpm
yum install mysql-community-server
```

#### 启动操作MySql
新版的Mysql安装后默认root用户的密码是随机生成的，需要去对应的日志文件中查找。这个在我之前的一篇博文中有说过: [MySql 5.7.18免安装版安装使用](http://blog.vioao.site/MySql-5-7-18%E5%85%8D%E5%AE%89%E8%A3%85%E7%89%88%E5%AE%89%E8%A3%85%E4%BD%BF%E7%94%A8/)

##### 启动Mysql服务
```
[root@iZwz9en2rvi1v3yo0vkhouZ ~]# systemctl start mysqld.service
```

##### 获取初始密码
```
[root@iZwz9en2rvi1v3yo0vkhouZ ~]# cat /var/log/mysqld.log | grep "temporary password"
2017-06-13T09:23:32.288905Z 1 [Note] A temporary password is generated for root@localhost: 5-?fTL&+.khz
```

##### 登陆并修改初始密码
获取初始密码后就可以使用root/{初始密码}登陆了
```
[root@test ～]# mysql -p
Enter password:
Welcome to the MySQL monitor.
...
mysql> show databases;
ERROR 1820 (HY000): You must reset your password using ALTER USER statement before executing this statement.
```
初始使用会让你修改初始密码，否则不会让你操作，而且对新密码的复杂度也是有要求的，需要有(字母 数字 字符),那么修改密码就好了,命令如下:
```
mysql> alter user 'root'@'localhost' identified by '{yourpassword}';
mysql> flush privileges;
```
OK,接下来就可以愉快的操作mysql了。


### 安装启动Tomcat
起初是按照安装JDK的方式安装Tomcat的。后来启动发现这个版本比较旧，对3.0的支持不是太好，启动项目会报错，于是就自己上官网下载最新的压缩包解压缩部署了
```
wget http://apache.fayea.com/tomcat/tomcat-8/v8.5.15/bin/apache-tomcat-8.5.15.zip
yum install unzip
unzip apache-tomcat-8.5.15.zip
cd apache-tomcat-8.5.15/bin
./startup
```

#### Bad Luck
`./startip`启动tomcat后无法成功访问对应的程序，但是 `telnet ip 8080` 端口可以成功。一开始以为是自己的应用有问题导致的，于是想关闭tomcat后查找下问题，结果却提示无法关闭,报如下错误:
```
Using CATALINA_BASE:   /opt/program/apache-tomcat-8.5.15
Using CATALINA_HOME:   /opt/program/apache-tomcat-8.5.15
Using CATALINA_TMPDIR: /opt/program/apache-tomcat-8.5.15/temp
Using JRE_HOME:        /usr
Using CLASSPATH:       /opt/program/apache-tomcat-8.5.15/bin/bootstrap.jar:/opt/program/apache-tomcat-8.5.15/bin/tomcat-juli.jar
Jun 13, 2017 2:28:55 PM org.apache.catalina.startup.Catalina stopServer
SEVERE: Could not contact [localhost:[8005]]. Tomcat may not be running.
Jun 13, 2017 2:28:55 PM org.apache.catalina.startup.Catalina stopServer
SEVERE: Catalina.stop:
java.net.ConnectException: Connection refused (Connection refused)
        at java.net.PlainSocketImpl.socketConnect(Native Method)
        at java.net.AbstractPlainSocketImpl.doConnect(AbstractPlainSocketImpl.java:350)
        at java.net.AbstractPlainSocketImpl.connectToAddress(AbstractPlainSocketImpl.java:206)
        at java.net.AbstractPlainSocketImpl.connect(AbstractPlainSocketImpl.java:188)
        at java.net.SocksSocketImpl.connect(SocksSocketImpl.java:392)
        at java.net.Socket.connect(Socket.java:589)
        at java.net.Socket.connect(Socket.java:538)
        at java.net.Socket.<init>(Socket.java:434)
        at java.net.Socket.<init>(Socket.java:211)
        at org.apache.catalina.startup.Catalina.stopServer(Catalina.java:477)
        at sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
        at sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
        at sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
        at java.lang.reflect.Method.invoke(Method.java:498)
        at org.apache.catalina.startup.Bootstrap.stopServer(Bootstrap.java:408)
        at org.apache.catalina.startup.Bootstrap.main(Bootstrap.java:497)

```
无奈只好使用 `ps aux | grep tomcat` 查找对应的pid后使用 `kill -9 pid` 强制将tomcat结束。
然后，进入到tomcat的logs目录追踪日志， `tail -f catalina.2017-06-13.log` ，重启tomcat。之后就发现一个蛋疼的问题了，tomcat启动日志一直卡在
> Deploying web application directory [/opt/program/apache-tomcat-8.5.15/webapps/manager...

之后百度到了解决方法: [Tomcat启动时卡在“INFO: Deploying web application directory ”](http://www.cnblogs.com/vinozly/p/5011138.html)]
按照博文中的操作才成功启动了Tomcat

### 安装启动ElasticSearch

#### 下载解压ElasticSearch
由于 **Shopizer** 使用的依然是2.x版本的ElasticSearch，所以这边就安装2.4.4版本的。
```
wget https://download.elastic.co/elasticsearch/release/org/elasticsearch/distribution/zip/elasticsearch/2.4.4/elasticsearch-2.4.4.zip
unzip -ivh elasticsearch-2.4.4.zip

```

#### 启动ElasticSearch
启动过程不太顺利,总共遇到了两个问题
- 不能使用root用户启动
```
[root@iZwz9en2rvi1v3yo0vkhouZ program]# cd elasticsearch-2.4.4/bin/
[root@iZwz9en2rvi1v3yo0vkhouZ bin]# ./elasticsearch
OpenJDK 64-Bit Server VM warning: If the number of processors is expected to increase from one, then you should configure the number of parallel GC threads appropriately using -XX:ParallelGCThreads=N
Exception in thread "main" java.lang.RuntimeException: don't run elasticsearch as root.
        at org.elasticsearch.bootstrap.Bootstrap.initializeNatives(Bootstrap.java:94)
        at org.elasticsearch.bootstrap.Bootstrap.setup(Bootstrap.java:160)
        at org.elasticsearch.bootstrap.Bootstrap.init(Bootstrap.java:286)
        at org.elasticsearch.bootstrap.Elasticsearch.main(Elasticsearch.java:45)
```
- 系统内存不够(Mysql占用了比较多的内存空间,系统剩余内存不够elasticsearch的默认配置大小)
```
[root@iZwz9en2rvi1v3yo0vkhouZ bin]# ./elasticsearch
OpenJDK 64-Bit Server VM warning: INFO: os::commit_memory(0x0000000085330000, 2060255232, 0) failed; error='Cannot allocate memory' (errno=12)
```

[elasticsearch文档](https://www.elastic.co/guide/en/elasticsearch/reference/2.4/setup-configuration.html)说明节选:
> Within the scripts, Elasticsearch comes with built in JAVA_OPTS passed to the JVM started. The most important setting for that is the -Xmx to control the maximum allowed memory for the process, and -Xms to control the minimum allocated memory for the process (in general, the more memory allocated to the process, the better).
Most times it is better to leave the default JAVA_OPTS as they are, and use the ES_JAVA_OPTS environment variable in order to set / change JVM settings or arguments.
The ES_HEAP_SIZE environment variable allows to set the heap memory that will be allocated to elasticsearch java process. It will allocate the same value to both min and max values, though those can be set explicitly (not recommended) by setting ES_MIN_MEM (defaults to 256m), and ES_MAX_MEM (defaults to 1g).


解决方案:
配置允许使用root用户启动，并调小elasticsearch可以使用的内存大小:
```
./elasticsearch -Des.insecure.allow.root=true -Xmx256m -Xms256m
```

注: 生产环境中最好不要使用root用户启动elasticsearch，官方文档中不推荐这么做，会有安全问题；还是就是最好将elasticsearch单独部署，不然需要针对当前系统的内存使用情况来配置调整elasticsearch可使用的内存。