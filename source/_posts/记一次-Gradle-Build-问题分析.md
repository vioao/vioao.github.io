---
title: 记一次 Gradle Build 问题分析
seo_title: solve-gradle-build-problem
date: 2019-08-24 10:48:26
tags: [Gradle,Java]
categories: [工作记录]
---

### 问题出现

一次项目更新后，发现项目无法正常 build 了，出现如下报错：

```bash
error: cannot access DoNotMock
  class file for com.google.errorprone.annotations.DoNotMock not found
```

### 问题定位

1. Review 代码更新，寻找可疑点
    
    这一步 review 没有发现什么特殊的改动，只是更改了几个 proto 文件的定义。但是回退代码后却又能正常 build，所以说明构建失败的确是此次更新引入的问题。

<!-- more -->

2. 根据报错信息寻找问题根源
    
    1. 寻找错误包
       
        看错误是类找不到的问题，那么首先确定这个类是哪个包的；Google 了下，该类出现在 [error-prone](https://github.com/google/error-prone) , 并且发现 `DoNotMock` 从 2.3.0 开始就被移除掉了，相关讨论见 [GITHUB](https://github.com/google/error-prone/issues/572)
        ```xml
          <dependency>
              <groupId>com.google.errorprone</groupId>
              <artifactId>error_prone_annotations</artifactId>
              <version>2.2.0</version>
         </dependency>    
        ```
    2. 分析包依赖
        
        从上面其实就可以看出这应该是一个依赖包不对带来的问题。那么此时就需要分析项目的依赖。重点查看 **error_prone_annotations** 的相关依赖。分析如下（本来在 console 中 **error_prone_annotations** 有高亮的，贴上来就没有了）：
        
        ```bash
        $ ./gradlew dependencies -q --configuration compile | grep error_prone_annotations --color -C 10
       compile - Dependencies for source set 'main' (deprecated, use 'implementation' instead).
       +--- net.xxxx.mshell:mshell-java-dropwizard-core:10.0.0
       |    +--- io.dropwizard:dropwizard-core:1.3.13
       |    |    +--- io.dropwizard:dropwizard-util:1.3.13
       |    |    |    +--- com.fasterxml.jackson.core:jackson-annotations:2.9.0 -> 2.9.9
       |    |    |    +--- com.google.guava:guava:24.1.1-jre -> 27.1-jre
       |    |    |    |    +--- com.google.guava:failureaccess:1.0.1
       |    |    |    |    +--- com.google.guava:listenablefuture:9999.0-empty-to-avoid-conflict-with-guava
       |    |    |    |    +--- com.google.code.findbugs:jsr305:3.0.2
       |    |    |    |    +--- org.checkerframework:checker-qual:2.5.2
       |    |    |    |    +--- com.google.errorprone:error_prone_annotations:2.2.0 -> 2.3.2 # here use error_prone_annotations 2.3.2
       |    |    |    |    +--- com.google.j2objc:j2objc-annotations:1.1
       |    |    |    |    \--- org.codehaus.mojo:animal-sniffer-annotations:1.17
       |    |    |    +--- com.google.code.findbugs:jsr305:3.0.2
       |    |    |    \--- joda-time:joda-time:2.10.1
       |    |    +--- io.dropwizard:dropwizard-jackson:1.3.13
       |    |    |    +--- com.google.guava:guava:24.1.1-jre -> 27.1-jre (*)
       |    |    |    +--- io.dropwizard:dropwizard-util:1.3.13 (*)
       |    |    |    +--- com.fasterxml.jackson.core:jackson-core:2.9.9
       |    |    |    +--- com.fasterxml.jackson.core:jackson-annotations:2.9.0 -> 2.9.9
       |    |    |    +--- com.fasterxml.jackson.core:jackson-databind:2.9.9.1
       --
       --
       |    |    |    |    +--- io.dropwizard:dropwizard-configuration:1.3.5 -> 1.3.13 (*)
       |    |    |    |    \--- org.apache.commons:commons-lang3:3.4 -> 3.8.1
       |    |    |    +--- com.google.protobuf:protobuf-java:3.6.0 -> 3.8.0
       |    |    |    \--- net.jodah:failsafe:2.0.1
       |    |    +--- net.xxxx.experimentation:java-mr-hyde-client:0.5.1 (*)
       |    |    +--- io.dropwizard:dropwizard-logging:1.3.13 (*)
       |    |    +--- io.dropwizard:dropwizard-configuration:1.3.13 (*)
       |    |    +--- io.dropwizard:dropwizard-metrics:1.3.13 (*)
       |    |    +--- io.dropwizard.metrics:metrics-healthchecks:4.0.2 -> 4.0.5 (*)
       |    |    +--- org.slf4j:jcl-over-slf4j:1.7.25 -> 1.7.26 (*)
       |    |    \--- com.google.errorprone:error_prone_annotations:2.0.12 -> 2.3.2  # here use error_prone_annotations 2.3.2
       |    +--- net.xxxx.mshell:mshell-java-secrets:10.0.0 (*)
       |    +--- net.xxxx.mshell:mshell-java-metrics:10.0.0 (*)
       |    +--- net.xxxx.mshell:mshell-java-async-client:10.0.0
       |    |    +--- org.asynchttpclient:async-http-client:2.4.9
       |    |    |    +--- org.asynchttpclient:async-http-client-netty-utils:2.4.9
       |    |    |    |    +--- io.netty:netty-buffer:4.1.25.Final
       |    |    |    |    |    \--- io.netty:netty-common:4.1.25.Final
       |    |    |    |    +--- org.slf4j:slf4j-api:1.7.25 -> 1.7.26
       |    |    |    |    \--- com.sun.activation:javax.activation:1.2.0
       |    |    |    +--- io.netty:netty-codec-http:4.1.25.Final
       --
       --
       |    |    |    +--- com.lightstep.tracer:java-common:0.15.8
       |    |    |    |    +--- io.opentracing:opentracing-api:0.31.0
       |    |    |    |    +--- io.opentracing:opentracing-util:0.31.0 (*)
       |    |    |    |    +--- com.google.protobuf:protobuf-java:3.5.1 -> 3.8.0
       |    |    |    |    \--- com.google.api.grpc:grpc-google-common-protos:1.12.0
       |    |    |    |         +--- io.grpc:grpc-stub:1.10.1 -> 1.13.2
       |    |    |    |         |    \--- io.grpc:grpc-core:1.13.2
       |    |    |    |         |         +--- io.grpc:grpc-context:1.13.2
       |    |    |    |         |         +--- com.google.code.gson:gson:2.7
       |    |    |    |         |         +--- com.google.guava:guava:20.0 -> 27.1-jre (*)
       |    |    |    |         |         +--- com.google.errorprone:error_prone_annotations:2.1.2 -> 2.3.2 # here use error_prone_annotations 2.3
       |    |    |    |         |         +--- com.google.code.findbugs:jsr305:3.0.0 -> 3.0.2
       |    |    |    |         |         +--- io.opencensus:opencensus-api:0.12.3
       |    |    |    |         |         \--- io.opencensus:opencensus-contrib-grpc-metrics:0.12.3
       |    |    |    |         |              \--- io.opencensus:opencensus-api:0.12.3
       |    |    |    |         +--- io.grpc:grpc-protobuf:1.10.1 -> 1.13.2
       |    |    |    |         |    +--- io.grpc:grpc-core:1.13.2 (*)
       |    |    |    |         |    +--- com.google.protobuf:protobuf-java:3.5.1 -> 3.8.0
       |    |    |    |         |    +--- com.google.guava:guava:20.0 -> 27.1-jre (*)
       |    |    |    |         |    +--- com.google.api.grpc:proto-google-common-protos:1.0.0 -> 1.12.0
       |    |    |    |         |    |    \--- com.google.protobuf:protobuf-java:3.5.1 -> 3.8.0
       --
       --
       |    |    +--- io.prometheus:simpleclient:0.6.0
       |    |    \--- io.dropwizard.metrics:metrics-core:3.1.2 -> 4.0.5 (*)
       |    \--- javax.xml.bind:jaxb-api:2.3.1
       |         \--- javax.activation:javax.activation-api:1.2.0
       \--- io.dropwizard.modules:dropwizard-protobuf:1.3.12-1
            +--- io.dropwizard:dropwizard-core:1.3.12 -> 1.3.13 (*)
            +--- com.google.protobuf:protobuf-java:3.8.0
            \--- com.google.protobuf:protobuf-java-util:3.8.0
                 +--- com.google.protobuf:protobuf-java:3.8.0
                 +--- com.google.guava:guava:26.0-android -> 27.1-jre (*)
                 +--- com.google.errorprone:error_prone_annotations:2.3.2    # here use error_prone_annotations 2.3
                 \--- com.google.code.gson:gson:2.7
       ```

     从上面可以看出，最终用的是 2.3.2 的 `error_prone_annotations` ，该版本中是没有 `DoNotMock` 注解的。而 2.3.2 版本的 `error_prone_annotations` 是由 `protobuf-java-util:3.8.0` 引入。至此找到问题所在。就是包依赖的问题

        
### 问题解决
在上一步中已已经确定问题点，就是包依赖导致的问题。那么我们便可以着手解决问题，该问题可以有**三个解决方案**：

1. 编译时强制使用含 `DoNotMock` 的  `error_prone_annotations`
    ```gradle
    implementation('com.google.errorprone:error_prone_annotations:2.2.0') {
        force = true
    }
    ```
2. 在依赖中移除 `error_prone_annotations:2.3.2`
    ```gradle
    compile ("io.dropwizard.modules:dropwizard-protobuf:${dropwizardProtobufVersion}") {
        exclude group: 'com.google.errorprone', module: 'error_prone_annotations'
    }
    ```
3. 升级所有依赖 `error_prone_annotations` 的包，升级到新版不使用  `DoNotMock`；该方案影响较大。需要先全局查找使用了 `DoNotMock` 的包。然后分析其使用依赖，再判断是否能升级。

### 问题回顾
问题是解决了，但是有个疑问。此次更新中，我们并没有更新相关的包依赖，为何以前 build 的时候没有出错，而这次却出错了呢？  
这边再次 Review 了下更新的代码，再结合此前对包依赖的分析，发现了问题所在。此次更新中，我们在 proto 文件中定义了 grpc 接口服务，而此服务的编译依赖包 `io.grpc` ；即编译 grpc 接口服务的包需要使用到相关的类，而这些类中有些使用了 `DoNotMock`。而不幸的是，我们引用的其他包中使用了更新的 `error_prone_annotations` ，然该包中又不含 `DoNotMock`，从而导致了编译错误。
```bash
error: cannot access DoNotMock
  class file for com.google.errorprone.annotations.DoNotMock not found
```
