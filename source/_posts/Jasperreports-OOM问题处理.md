---
title: Jasperreports OOM问题处理
date: 2018-02-28 22:48:10
tags: [Java,JasperReports,OOM]
categories: [工作记录]

---

# 问题描述
项目使用Jasperreports来转换导出PDF，不过在转换过程中有时会出现OOM的异常。将直接导致线上系统不可使用。主要导致OOM的问题有如下两种:

 1. jasper模板文件设计不合理导致Jasperreports进入死循环
 2. 需要转换的文件确实很大，超过了系统所支持的内存范围

此前就有遇到过上述情况导致系统不可用的情况，这明显影响了程序的健壮性。是需要处理的。此前对该的处理排查描述请查看之前的博文:**[线上java程序CPU占用过高问题排查](http://blog.csdn.net/u010862794/article/details/78020231)**

<!-- more -->

# 问题处理
既然知道问题由于内存占用过多导致的，那么直接从上面的两个问题可能思考解决方案即可。
## jasper模板文件设计不合理
在设计模板时，如果勾选了"**Print When Detail Overflows**"选项时，那么很有可能就会导致OOM了。这个问题官方将其定位为模板设计不合理，并不打算解决。所以只能我们自己严格把关了。
针对该问题我考虑了两种解决方案:

1. **利用SVN钩子函数，在提交jasper模板文件时校验设计文件是否有勾选"Print When Detail Overflows"属性。**简要的设计如下:

 > 1. [svnlook changed](https://www.visualsvn.com/support/svnbook/ref/svnlook/c/changed/)命令获取到改变的文件列表
 > 2. 将变更列表传递给java程序，java程序利用Jasperreports的API获取模板文件的熟悉来判断模板文件是否有勾选"Print When Detail Overflows"

   大致代码:
    ```java
    JasperReport rr = (JasperReport) JRLoader.loadObjectFromFile(filePath);
    boolean isPrintWhenDetailOverflows = Boolean.valueOf(rr.getPropertiesMap().getProperty(JRXmlConstants.ATTRIBUTE_isPrintWhenDetailOverflows));
   ```

2. **添加Jasperreports的配置文件**
在项目classpath下添加jasperreports.properties配置文件，添加对应的配置。其中有个**net.sf.jasperreports.consume.space.on.overflow**的配置可以处理上述问题。不过该配置需要Jasperreports 6.3.1版本才支持。

```
net.sf.jasperreports.consume.space.on.overflow
Property used to force the expanding text fields to occupy all remaining space at the bottom of the page so that no other element renders there.

API:	PROPERTY_CONSUME_SPACE_ON_OVERFLOW
Default:	true
Scope:	Global | Context | Report | Text Element
Since:	6.3.1
```

## 确实需要很多的内存
解决方案也是从两个点来处理该问题:

 1. **减少内存使用**

 减少内存使用的方式在**[线上java程序CPU占用过高问题排查](http://blog.csdn.net/u010862794/article/details/78020231)**一文中已经说了使用方式。这里简单说明下。 Jasperreports 提供了 `Virtualizer`配置，通过该配置可以使用磁盘代替内存来保存转换过程中的数据存储，从而达到减少内存使用的目的。但是相应的转换速度会变慢。`Virtualizer`的详细使用可以参考官方的示例: **[Virtualizer Sample (version 6.5.1)](http://jasperreports.sourceforge.net/sample.reference/virtualizer/)**

 2. **限制内存使用(转换超过指定页数或时间则转换失败,而不是一直使用内存导致OOM)**

   `Virtualizer`无法解决当程序陷入死循环导致空间不够用的问题，所以还需要限制通过转换时间和转换页码等限制转换程序对内存空间的占用。可以添加如下的配置：
   ```
   net.sf.jasperreports.governor.max.pages
   If the governor that checks if a report exceeds a specified limit of pages is turned on, this property will indicate the        maximum number of pages allowed to be ran, in order to prevent a memory overflow error. If the number of pages in the    report becomes greater than this value, the report execution will be stopped.

    API:	PROPERTY_MAX_PAGES
Default:	N/A
Scope:	Global | Context | Report
Since:	3.1.4

 net.sf.jasperreports.governor.max.pages.enabled
A flag indicating whether the governor that checks if a report exceeds a specified limit of pages is turned on. With this property enabled, the JR engine will stop the report execution if the number of pages becomes greater than a custom given value.

 API:	PROPERTY_MAX_PAGES_ENABLED
Default:	false
Scope:	Global | Context | Report
Since:	3.1.4


   net.sf.jasperreports.governor.timeout
If the governor that checks if the elapsed time during report execution exceeds a specified amount of time is turned on, this property will indicate the maximum allowed amount of time, in order to prevent a memory overflow error. If this value becomes exceeded, the report execution will be stopped.

 API:	PROPERTY_TIMEOUT
Default:	N/A
Scope:	Global | Context | Report
Since:	3.1.4


 net.sf.jasperreports.governor.timeout.enabled
A flag indicating whether the governor that checks if the elapsed time during report execution exceeds a specified amount of time is turned on.
With this property enabled, the JR engine will stop the report execution if the elapsed time becomes greater than the limit value.
By default it should be turned off.

 API:	PROPERTY_TIMEOUT_ENABLED
Default:	false
Scope:	Global | Context | Report
Since:	3.1.4
   ```

 eg. **jasperreports.properties**
 ```properties
     # 转换时间最多为60s
 net.sf.jasperreports.governor.timeout.enabled = 60*1000
     # 最多只能转换10页
 net.sf.jasperreports.governor.max.pages = 10
 ```

其实Jasperreports目前提供了比以前更多的问题。我们可以多阅读，其中有不少问题是可以通过文档解决的。

 - [JasperReports - Configuration Reference](http://jasperreports.sourceforge.net/config.reference.html#net.sf.jasperreports.consume.space.on.overflow)
 - [JasperReports-Ultimate-Guide-3.pdf]( http://jasperreports.sourceforge.net/JasperReports-Ultimate-Guide-3.pdf)
 - [JasperReports - Sample Reference](http://jasperreports.sourceforge.net/sample.reference.html)