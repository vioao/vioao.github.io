---
title: 在 Maven 中央仓库发布自己的开源项目
date: 2020-07-23 17:01:41
tags: [Maven]
categories: [Java]
---

写代码久了，一直在用别人提供的第三方包依赖，有时是不是也会想着有一天别人能够使用自己的开源出去的项目。让我们从最简单的开始，提取一个小项目，将其开源并发布到中央仓库让大伙可以直接通过配置 Maven 依赖来使用。

### 寻找项目方案

我相信应该是有不少人都有过开源并发布自己项目的想法的，但是其中最大的一个问题可能就是不知道该写点什么了、不知道有什么东西可以开源出去让别人使用的。没有关系，这边带你慢慢来提取出一个可行的项目方案。

开源项目的种类多种多样，来源更是不用多说，我们这里不整这些这么广泛复杂的项目，我们就是想体验下将自己的项目构建发布到 Maven 中央仓库的快感。那么其实有一个特别容易的项目可以立马自己就着手设计的：实现 API。

<!-- more -->

目前很多大平台都有开放自己的 API 接口，不少都是 HTTP 协议的接口，但是并不是所有的都有提供对应的 Java 客户端，那么这就是我们的机会啦，我们可以封装这些接口，提供对应的客户端，让其他用户可以开箱即用。目前一些开放接口的平台有：

- [WeChat](https://mp.weixin.qq.com/?token=&lang=zh_CN)
- [Pinterest](https://developers.pinterest.com/docs/getting-started/introduction/)
- [微博 API](https://open.weibo.com/wiki/%E5%BE%AE%E5%8D%9AAPI)
- [Medium’s API](https://github.com/Medium/medium-api-docs) 
- [Hacker News API](https://github.com/HackerNews/API)
- ......

可以参考：[国内外 API 总结](https://blog.csdn.net/Andrelia20171760/article/details/92441333)。选一个 GitHub 上还没人实现的，或者觉得实现的不好的，或者自己感兴趣的就可以了。

### GitHub 开源、版本管理

#### 版本号命名规则

项目选好后直接实现就好了。不过这肯定是一个持续的过程，过程中会有代码变更，会有版本变更，那么我们如何定义这个项目的版本号呢？这里给出一个版本号命名规则。

版本号的格式为一般遵循 A.B.C（又称 Major.Minor.Patch）这样的定义，其含义如下：

- A：主版本号，当实现有大改动，其兼容性发生变化时，A 需要递增。
- B：次版本号，当增加新功能，但兼容性不变时，B 需要递增。
- C：修订号，当进行了 Bug 修复时，C 需要递增。

除了版本号之外还会有一些修饰的词，比如：

- Alpha：内部版本
- Beta：测试版
- Rc：即将作为正式版发布
- Lts：长期维护

> 参考：[Semantic Versioning 2.0.0](https://semver.org/lang/zh-CN/)

#### GitHub 项目版本控制

个人简单项目的话，这边推荐直接使用的 GitHub 的 Tag 来进行控制，每当我发布一个版本的 Jar 到 Maven 仓库时，我就对该稳定版本进行 Tag 设置。这样用户可以在 Tag 中找到对应的版本设置和说明。

{% asset_img set-tags.png Github repo tags %}

设置 Tag：
```
git tag -a [version] -m [commit message]
```
推送到服务器：
```
git push origin [version]
```


### 打包、发布到中央仓库

代码完成实现并开源到 GitHub 后，进行 Maven 发布管理。发布到中央仓库的话，我们需要使用 Sonatype 为开源项目提供托管服务。可以通过它发布快照或是稳定版到 Maven 中央仓库。我们只要注册一个 Sonatype 的 JIRA 账号、创建一个 Jira 任务，然后添加对应的 pom.xml 配置。


#### OSSRH 发布准备 

**1.** 注册账号：[注册地址](https://issues.sonatype.org/secure/Signup!default.jspa)

**2.** 创建 Jira 工单

{% asset_img create-jira-1.png 创建 Jira 工单-1 %}
{% asset_img create-jira-2.png 创建 Jira 工单-2 %}
    
这里有两个注意点：

- 填写 groupId 的时候，如果需要对应的域名真实且属于你，不过我们可以使用 GitHub 的 com.github.*username* 或 io.github.*username*。
- 当你发布了你的第一个 release 版本的时候，记得要在这个任务上回复 comment 告知 OSSRH。
- 工单进程可以看工单的状态和对应的 comment 信息，按照他们的说明走即可，工单状态变为 **RESOLVED** 时可提交 Jar。

#### 生成密钥
 
- Linux：可以参考 [Working with PGP Signatures](https://central.sonatype.org/pages/working-with-pgp-signatures.html)
- Windows：使用 Kleopatra，[下载地址](https://gpg4win.org/download.html)
  
创建流程如下：
  
> 文件 -> 新建密钥对 -> 创建个人 OpenPGP 密钥对  -> 填写个人信息 -> 输入密码密码 -> 上传到目录服务
  
  {% asset_img create-secret.png 生成秘钥 %}

#### Maven 项目调整

**1.** 修改 pom.xml

添加项目已经开发者信息    
```xml
    <licenses>
        <license>
            <name>The Apache Software License, Version 2.0</name>
            <url>http://www.apache.org/licenses/LICENSE-2.0.txt</url>
        </license>
    </licenses>
    <scm>
        <url>https://github.com/vioao/wechat-sdk.git</url>
        <connection>scm:https://github.com/vioao/wechat-sdk.git</connection>
    </scm>
    <developers>
        <developer>
            <name>vioao</name>
            <email>vioao91@gmail.com</email>
            <url>http://blog.vioao.site</url>
    </developer>    
    
```
    
添加打包构建相关信息
```xml
         <build>
            <plugins>
            <!-- ... 省略部分配置 -->
            <!-- ... 必须要有 source ！！！ -->
                    <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-resources-plugin</artifactId>
                    <version>${maven-resources-plugin.version}</version>
                </plugin>
            </plugins>
        </build>
```
添加发布相关配置信息
```xml
        <profiles>
            <profile>
                <id>release</id>
                <build>
                    <plugins>
                        <!-- Source -->
                        <plugin>
                            <groupId>org.apache.maven.plugins</groupId>
                            <artifactId>maven-source-plugin</artifactId>
                            <version>${maven-source-plugin.version}</version>
                            <executions>
                                <execution>
                                    <phase>package</phase>
                                    <goals>
                                        <goal>jar-no-fork</goal>
                                    </goals>
                                </execution>
                            </executions>
                        </plugin>
                        <!-- Javadoc -->
                        <plugin>
                            <groupId>org.apache.maven.plugins</groupId>
                            <artifactId>maven-javadoc-plugin</artifactId>
                            <version>${maven-javadoc-plugin.version}</version>
                            <executions>
                                <execution>
                                    <phase>package</phase>
                                    <goals>
                                        <goal>jar</goal>
                                    </goals>
                                </execution>
                            </executions>
                        </plugin>
                        <!-- deploy -->
                        <plugin>
                            <groupId>org.sonatype.plugins</groupId>
                            <artifactId>nexus-staging-maven-plugin</artifactId>
                            <version>${nexus-staging-maven-plugin.version}</version>
                            <extensions>true</extensions>
                            <configuration>
                                <serverId>oss</serverId>
                                <nexusUrl>https://oss.sonatype.org/</nexusUrl>
                                <autoReleaseAfterClose>true</autoReleaseAfterClose>
                            </configuration>
                        </plugin>
                        <plugin>
                            <groupId>org.apache.maven.plugins</groupId>
                            <artifactId>maven-release-plugin</artifactId>
                            <version>${maven-release-plugin.version}</version>
                            <configuration>
                                <autoVersionSubmodules>true</autoVersionSubmodules>
                                <useReleaseProfile>false</useReleaseProfile>
                                <releaseProfiles>release</releaseProfiles>
                                <goals>deploy</goals>
                            </configuration>
                        </plugin>
                        <!-- Gpg Signature -->
                        <plugin>
                            <groupId>org.apache.maven.plugins</groupId>
                            <artifactId>maven-gpg-plugin</artifactId>
                            <version>${maven-gpg-plugin.version}</version>
                            <executions>
                                <execution>
                                    <id>sign-artifacts</id>
                                    <phase>verify</phase>
                                    <goals>
                                        <goal>sign</goal>
                                    </goals>
                               </execution>
                            </executions>
                        </plugin>
                    </plugins>
                </build>
            </profile>
        </profiles>

         <distributionManagement>
            <snapshotRepository>
                <id>oss</id>
                <url>https://oss.sonatype.org/content/repositories/snapshots/</url>
            </snapshotRepository>
            <repository>
                <id>oss</id>                <url>https://oss.sonatype.org/service/local/staging/deploy/maven2/</url>
            </repository>
        </distributionManagement>
    
```
添加 settings.xml 配置
```xml
        <!-- oss 配置 -->
        <servers>
            <server>
                <id>oss</id>
                <username> Jira 用户名</username>
                <password> Jira 密码</password>
            </server>
        </servers>
        
        <!-- gpg 配置 -->
        <profiles>
            <profile>
                <id>oss</id>
                <activation>
                    <activeByDefault>true</activeByDefault>
                </activation>
               <properties>
                   <gpg.executable>gpg</gpg.executable>
                   <gpg.passphrase>${ 上一步的密钥密码 }</gpg.passphrase>
               </properties>
            </profile>
        </profiles>    
```

#### 发布

**发布 Snapshot 版本：**

**1.** 修改 pom.xml 的 version 添加 -SNAPSHOT 后缀
       
```xml
        <version>1.2.0-SNAPSHOT</version>
```
**2.**  `mvn clean deploy`
 
**3.** 发布后可以上[该地址](https://oss.sonatype.org/content/repositories/snapshots/)查找你发布的 Jar

**发布 Release 版本：**

**1.** 修改 pom.xml 的 version 移除 -SNAPSHOT 后缀，或手动设置版本号 `mvn versions:set -DnewVersion=1.2.0`
```xml
        <version>1.2.0</version>
```
        
**2.**  `mvn clean deploy -P release`
    
**3.** 正式版发布后就可以在[中央仓库](https://mvnrepository.com)查找到了

参考：

- [Deploying to OSSRH with Apache Maven](https://central.sonatype.org/pages/apache-maven.html#gpg-signed-components)

---

本文首发于 GitChat，[在 Maven 中央仓库发布自己的开源项目](https://gitbook.cn/gitchat/activity/5d06fcb235ea8c7df069fbb2)

---