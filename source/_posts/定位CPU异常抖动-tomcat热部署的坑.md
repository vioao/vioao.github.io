---
title: '定位CPU异常抖动---tomcat热部署的坑 '
seo_title: how-to-find-the-cpu-problem-caused-by-tomcat-hot-reload
date: 2018-04-29 14:34:30
tags: [Java, Tomcat, 热部署, CPU]
categories: [工作记录]
---

# 问题及其罪魁祸首

**WEB服务器: apache-tomcat-8.0.33**
**JDK: jdk1.8.0_66**
**操作系统: Linux SHB-L0064049 2.6.32-642.6.2.el6.x86_6 **

运维反馈CPU抖动异常，如下。
{% asset_img cpu.jpg CPU状态 %}

CPU时不时的会从0%抖动到50%，定位到时tomcat的**热部署**导致的问题。最终通过显式的加上`reloadable=“false”` 的配置解决了该问题。

**注：** 这里有一个坑，tomcat 的热部署默认是关闭的,具体请看[(文档)[http://tomcat.apache.org/tomcat-8.0-doc/config/context.html]] 中的`reloadable`说明， 然而我的服务器并没有显示配置`reloadable` 为true，tomcat却还是执行了对应的热部署相关的行为！

下面说说定位流程。

<!-- more -->

# 问题定位

- **查看服务进程的ID**
`ps aux | grep webAppName`

---

- **定位占用CPU高的线程**
`top -H -p pid`

---

- **查看线程堆栈**
```
[root@SZC-L0095267 serviceop]#  /wls/apache/tomcat/jdk1.8.0_66/bin/jstack -F 52754 |grep 53069 -A 20
    Thread 53069: (state = IN_JAVA)
java.util.jar.JarFile.getJarEntry(java.lang.String) @bci=2, line=223 (Compiled frame; information may be imprecise)
 org.apache.catalina.webresources.JarResourceSet.getArchiveEntry(java.lang.String) @bci=9, line=120 (Compiled frame)
 org.apache.catalina.webresources.AbstractArchiveResourceSet.getResource(java.lang.String) @bci=279, line=270 (Compiled frame)
 org.apache.catalina.webresources.StandardRoot.getResourceInternal(java.lang.String, boolean) @bci=103, line=281 (Compiled frame)
 org.apache.catalina.webresources.Cache.getResource(java.lang.String, boolean) @bci=14, line=63 (Compiled frame)
 org.apache.catalina.webresources.StandardRoot.getResource(java.lang.String, boolean, boolean) @bci=23, line=216 (Compiled frame)
 org.apache.catalina.webresources.StandardRoot.getClassLoaderResource(java.lang.String) @bci=22, line=225 (Compiled frame)
 org.apache.catalina.loader.WebappClassLoaderBase.modified() @bci=81, line=706 (Compiled frame)
 org.apache.catalina.loader.WebappLoader.modified() @bci=11, line=342 (Compiled frame)
 org.apache.catalina.loader.WebappLoader.backgroundProcess() @bci=8, line=286 (Compiled frame)
 org.apache.catalina.core.StandardContext.backgroundProcess() @bci=21, line=5608 (Compiled frame)
org.apache.catalina.core.ContainerBase$ContainerBackgroundProcessor.processChildren(org.apache.catalina.Container) @bci=55, line=1377 (Compiled frame)
org.apache.catalina.core.ContainerBase$ContainerBackgroundProcessor.processChildren(org.apache.catalina.Container) @bci=94, line=1381 (Compiled frame)
org.apache.catalina.core.ContainerBase$ContainerBackgroundProcessor.processChildren(org.apache.catalina.Container) @bci=94, line=1381 (Compiled frame)
org.apache.catalina.core.ContainerBase$ContainerBackgroundProcessor.run() @bci=68, line=1349 (Interpreted frame)
 java.lang.Thread.run() @bci=11, line=745 (Interpreted frame)
```
---

- **查看源码**
 调用流程:  `WebappLoader.backgroundProcess()`  -> ` WebappLoader.modified()`
 从线程堆栈可以看出是tomcat相关的线程导致的CPU异常，我们从源码入手看是什么问题。以下是
  ` WebappLoader.java` 的相关关键代码,从代码和打印的线程堆栈中可以看出，线上的生产服务器其实是走到了
  `reloadable`为`true`的流程中去了的，说明tomcat开启了热部署。


```
/**
 * The reloadable flag for this Loader.
 */
private boolean reloadable = false;


/**
* Execute a periodic task, such as reloading, etc. This method will be
* invoked inside the classloading context of this container. Unexpected
* throwables will be caught and logged.
*/
@Override
public void backgroundProcess() {
    if (reloadable && modified()) {
        try {
            Thread.currentThread().setContextClassLoader
                (WebappLoader.class.getClassLoader());
            if (context != null) {
                context.reload();
            }
        } finally {
            if (context != null && context.getLoader() != null) {
                Thread.currentThread().setContextClassLoader
                    (context.getLoader().getClassLoader());
            }
        }
    }
}

/**
 * Has the internal repository associated with this Loader been modified,
 * such that the loaded classes should be reloaded?
 */
@Override
public boolean modified() {
    return classLoader != null ? classLoader.modified() : false ;
}

```

---

-  **查看tomcat的`server.xml`配置，确认是否有开启`reloadable`**
```
<!-- 省略部分 -->
<Host name="localhost"  appBase="app base dir" unpackWARs="true" autoDeploy="false">
     <Context path="/f5monweb" docBase="/wls/apache/monitor_tm/f5monweb.war" unpackWAR="false"/>
     <Context path="/perfmon" docBase="/wls/apache/monitor_tm/perfmon.war" unpackWAR="false"/>
<!-- 省略部分 -->
```
可以看出，我们的应用并没有显式的配置`reloadable="true"`,即没有开启热部署， tomcat中关于`reloadable`的说明如下:
> reloadable
> Set to true if you want Catalina to monitor classes in /WEB-INF/classes/ and /WEB-INF/lib for changes, and
> automatically reload the web application if a change is detected. This feature is very useful during application
> development, but it requires significant runtime overhead and is not recommended for use on deployed production
> applications. **That's why the default setting for this attribute is false**. You can use the Manager web application,
> however, to trigger reloads of deployed applications on demand.

这真是tomcat的一个大坑，线程定位就是走了热部署相关的流程无误了。

----

- **解决问题**
最终通过显式的添加`reloadable="false"`解决问题，调整后`server.xml`配置如下:
```
<!-- 省略部分 -->
<Host name="localhost"  appBase="app base dir" unpackWARs="true" autoDeploy="false">
     <Context path="/myWebappName" docBase="myWebappName.war" reloadable="false"/>
     <Context path="/f5monweb" docBase="/wls/apache/monitor_tm/f5monweb.war" unpackWAR="false"/>
     <Context path="/perfmon" docBase="/wls/apache/monitor_tm/perfmon.war" unpackWAR="false"/>
<!-- 省略部分 -->
```