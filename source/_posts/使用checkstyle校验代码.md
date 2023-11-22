---
title: 使用checkstyle校验代码
date: 2017-12-03 13:48:38
tags: [CheckStyle,Maven]
categories: [工作记录]

---
## 引入背景
目前手上接管了一个旧项目,在调整的过程中发现其编码规范非常的多样化。其实就是没有规范了。代码中的命名、注释、换行等风格都有多种，差不多每个曾经修改过代码的程序员都留来过自己的风格。代码风格质量良莠不齐，这导致新员工在阅读代码时需要花更多的时间,也更加痛苦。所以考虑使用checkstyle来校验统一代码风格。
起初考虑是直接在svn上做一个pre-commit的hook的。不过沟通无果，svn服务的权限无法掌控在自己手里。于是便考虑使用maven插件[Apache Maven Checkstyle Plugin](http://maven.apache.org/plugins/maven-checkstyle-plugin/)，在本地编译的时候去校验。不过由于是旧项目，在使用插件时不希望校验以前的老旧代码，不然这将是一个灾难(除非你希望改到天荒地老)。那么，这边就希望只校验新增加和修改的文件。后面给出处理方式。

<!-- more -->

## Checkstyle介绍
Checkstyle 是一个帮助程序员使用统一编码风格来编写java代码的开发工具。它能够替代人工自动校验代码，这是希望使用统一编码风格的项目的理想选择。Checkstyle是高可配的，几乎支持任何的编码风格，人们可以使用自己的编码标准。
可以参考下Sun和Google的 [Sun Code Conventions](http://www.oracle.com/technetwork/java/javase/documentation/codeconvtoc-136057.html)、[Google Java Style](http://checkstyle.sourceforge.net/reports/google-java-style-20170228.html).
另外,还可以使用Maven和Checkstyle生产检查报告。
更新信息请查阅[官方文档](http://checkstyle.sourceforge.net/index.html)

## Apache Maven Checkstyle Plugin介绍
Apache Maven Checkstyle Plugink可以根据预先定义好的编码标准校验代码并生成检查报告。使用该插件需要在pom文件中定义，并配置对应的代码标准配置文件。插件中默认已经包含两个标准文件 [sun_style.xml](http://checkstyle.sourceforge.net/sun_style.html)、[google_style.xml](http://checkstyle.sourceforge.net/google_style.html)
更新信息请查阅[官方文档](http://maven.apache.org/plugins/maven-checkstyle-plugin/)

## 项目引入Maven Checkstyle Plugin统一编码
### 添加pom.xml配置
```
<plugin>
   <groupId>org.apache.maven.plugins</groupId>
   <artifactId>maven-checkstyle-plugin</artifactId>
   <version>2.17</version>
   <executions>
     <execution>
       <id>validate</id>
       <phase>validate</phase>
       <configuration>
         <!-- 使用内置google编码规范 -->
         <configLocation>checkstyle.xml</configLocation>
         <encoding>UTF-8</encoding>
         <consoleOutput>true</consoleOutput>
         <!-- 校验不通过时直接编译失败 -->
         <failsOnError>true</failsOnError>
         <linkXRef>false</linkXRef>
       </configuration>
       <goals>
         <goal>check</goal>
       </goals>
     </execution>
   </executions>
 </plugin>
```

### 添加自定义的编码规范配置文件checkstyle.xml
由于目前也没有统一的编码规范，所以暂时使用google的checkstyle配置，之后在其基础上修改以适应实际情况。需要将eckstyle.xml放置在系统根目录下。当然也可以放在其他地方,对应修改pom配置文件中Checkstyle Plugin的`configLocation`参数即可
```
Specifies the location of the XML configuration to use.
Potential values are a filesystem path, a URL, or a classpath resource.
This parameter expects that the contents of the location conform to the
xml format configuration of rulesets.

This parameter is resolved as resource, URL, then file. If successfully
resolved, the contents of the configuration is copied into the
${project.build.directory}/checkstyle-configuration.xml
file before being passed to Checkstyle as a configuration.

There are 2 predefined rulesets.sun_checks.xml & google_checks.xml
```

### 只校验变更的文件
刚开始考虑是通过java方式来操作svn来获取托管在svn上的项目的相关信息，调查发现了SVNKIT这东西，但是简要看了下发现，使用svnkit都需要配置url,username,pwd这些。但是我只是想获取各变更列表而已，而且代码校验也只是本地校验而已，就觉得太麻烦了。于是决定通过java执行本地cmd来获取稳健变更列表。具体实现如下:
参考步骤[Using Custom Developed Checkstyle Checks](http://maven.apache.org/plugins/maven-checkstyle-plugin/examples/custom-developed-checkstyle.html),实现自定义的BeforeExecutionFileFilter
此步骤实现Checkstyle执行时只校验新增加和修改的文件。
```
/**
 * 只校验新增加的文件和新修改的文件
 * Created by Vioao on 2017/11/23.
 */
public class CustomBeforeExecutionFileFilter extends AutomaticBean implements BeforeExecutionFileFilter {
    private static final Logger LOGGER = LoggerFactory.getLogger(PaicBeforeExecutionFileFilter.class);

    private static final String CMD = "svn diff --summarize";
    private List<String> changedFiles = new ArrayList<String>();
    private volatile boolean initialized = false;

    private String ignoredSvnStatus = "D";

    public void setIgnoredSvnStatus(String ignoredSvnStatus) {
        this.ignoredSvnStatus = ignoredSvnStatus;
    }

    public boolean accept(String uri) {

        if (!initialized) {
            try {
                initChangedFileList();
            } catch (Exception e) {
                LOGGER.warn("获取SVN变更列表失败,跳过CHeckStyle", e);
            }
            initialized = true;
        }
        return changedFiles.contains(uri);
    }

   /**
     * 获取svn文件变更列别
     * @return 文件变更列表
     * @throws IOException
     */
    private List<String> initChangedFileList() throws IOException {
        Process process = Runtime.getRuntime().exec(CMD);
        BufferedReader bufferedReader = new BufferedReader(new InputStreamReader(process.getInputStream()));
        String line;
        while ((line = bufferedReader.readLine()) != null) {
            if (!ignoredSvnStatus.contains(String.valueOf(line.charAt(0)))) {
                String fileName = line.substring(1, line.length()).trim();
                fileName = (new File(fileName)).getAbsolutePath();
                changedFiles.add(fileName);
            }
        }
        return changedFiles;
    }
}

```

这个实现只支持svn托管代码的，如果是git托管代码，那么将对应的svn命令换成git的即可。

### 修改checkstyle.xml配置
修改checkstyle.xml配置，添加自定义的文件过滤`CustomBeforeExecutionFileFilter`
```
<?xml version="1.0"?>
<!DOCTYPE module PUBLIC
        "-//Puppy Crawl//DTD Check Configuration 1.3//EN"

<module name = "Checker">
    <!-- 省略部分配置 -->
    <property name="charset" value="UTF-8"/>

    <property name="severity" value="ERROR"/>

    <property name="fileExtensions" value="java, properties, xml, jsp, json"/>

    <module name="com.vioao.checkstyle.CustomBeforeExecutionFileFilter"/>

   <!-- 省略部分配置 -->
</module>
```