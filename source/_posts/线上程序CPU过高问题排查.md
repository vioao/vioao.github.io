---
title: 线上程序CPU过高问题排查
seo_title: how-to-find-the-cpu-problem-in-production-env
date: 2017-09-24 09:44:18
tags: [Java,CPU,线上问题排查]
categories: [工作记录]
---

# 简要
工作中负责的有一个项目是使用iReport+JasperReport实现的一个打印系统。最近这个线上程序经常无响应，重启后恢复正常，但是时不时还是会出现类似的问题。
最后发现是JasperReport的一个问题。有个JasperReport的转换任务内存占用特别高，当新对象需要分配内存时就会内存不够了，于是GC线程就不断GC，占用CPU。
导致系统CPU占用超高。
**下面说下问题排查的一个思路步骤**

<!-- more -->

# 基本环境
- tomcat 7
- JDK 7
- Linux

# 问题定位

## 查看后台异常
通过查看系统的后台日志，发现各个请求都正常，没有异常抛出。于是考虑系统状况

## 查看系统状况

### top 命令查看CPU、内存等使用情况
```
[root@DEV-L002323 ~]# top
top - 14:52:54 up 514 days,  7:00,  8 users,  load average: 2.85, 1.35, 1.62
Tasks: 147 total,   1 running, 146 sleeping,   0 stopped,   0 zombie
Cpu(s): 57.6%us,  6.3%sy,  0.0%ni,  9.2%id, 26.2%wa,  0.0%hi,  0.0%si,  0.7%st
Mem:   3922928k total,  3794232k used,   128696k free,   403112k buffers
Swap:  4194296k total,    65388k used,  4128908k free,  1492204k cached

  PID USER      PR  NI  VIRT  RES  SHR S %CPU %MEM    TIME+  COMMAND
 6764 root      20   0 2428m 1.1g  11m S 190.0 28.3  36:38.55 java
 1161 root      20   0     0    0    0 D  0.3  0.0  32:43.06 flush-253:0
 1512 root      20   0 14684 4188  488 S  0.3  0.1   0:16.12 sec_agent
    1 root      20   0 19356  652  436 S  0.0  0.0   0:16.64 init
    2 root      20   0     0    0    0 S  0.0  0.0   0:00.05 kthreadd
    3 root      RT   0     0    0    0 S  0.0  0.0   1:49.34 migration/0
    4 root      20   0     0    0    0 S  0.0  0.0  17:46.61 ksoftirqd/0
    5 root      RT   0     0    0    0 S  0.0  0.0   0:00.00 migration/0
    6 root      RT   0     0    0    0 S  0.0  0.0   2:02.78 watchdog/0
    7 root      RT   0     0    0    0 S  0.0  0.0   1:46.79 migration/1
```

从top命令的结果发现。pid为6764的java进程CPU利用持续占用过高,达到了190%。内存占用率为28.3%。

### 定位问题线程

使用`ps -mp pid -o THREAD,tid,time`命令查看该进程的线程情况，发现该进程的两个线程占用率很高

```
[root@DEV-L002323 ~]# ps -mp 6764 -o THREAD,tid,time
USER     %CPU PRI SCNT WCHAN  USER SYSTEM   TID     TIME
root     71.7   -    - -         -      -     - 00:36:52
root      0.0  19    - futex_    -      -  6764 00:00:00
root      0.0  19    - poll_s    -      -  6765 00:00:01
root     44.6  19    - futex_    -      -  6766 00:23:32
root     44.6  19    - futex_    -      -  6767 00:23:32
root      1.2  19    - futex_    -      -  6768 00:00:38
root      0.0  19    - futex_    -      -  6769 00:00:00
root      0.0  19    - futex_    -      -  6770 00:00:01
root      0.0  19    - futex_    -      -  6771 00:00:00
```

从上面可以看出6766和6767两个线程占用CPU大约有半个小时，每个线程的CPU利用率约为45%。接下来需要查看对应线程的问题堆栈
下面就看看6766这个问题线程的堆栈

### 查看问题线程堆栈

#### 将线程id转换为16进制

```
[root@DEV-L002323 ~]#  printf "%x\n" 6766
1a6e
```

#### jstack查看线程堆栈信息
jstack命令打印线程堆栈信息，命令格式：`jstack pid |grep tid`

```
[root@DEV-L002323 ~]# jstack 6764 | grep 1a6e
"GC task thread#0 (ParallelGC)" prio=10 tid=0x00007ffeb8016800 nid=0x1a6e runnable
"GC task thread#0 (ParallelGC)" prio=10 tid=0x00007ffeb8016800 nid=0x1a6e runnable
"GC task thread#1 (ParallelGC)" prio=10 tid=0x00007ffeb8016800 nid=0x1a6e runnable
"VM Periodic Task Thread" prio=10 tid=0x00007ffeb8016800 nid=0x3700 waiting on condition

JNI global references: 496

```

从上面可以看书，这些都是GC的线程。那么可以推断，很有可能就是内存不够导致GC不断执行。接下来我们就需要查看
gc 内存的情况

### jstat查看进程内存状况
命令: `jstat -gcutil`
```
[root@DEV-L002323 bin]# jstat -gcutil 6764 2000 10
  S0     S1     E      O      P     YGC     YGCT    FGC    FGCT     GCT
  0.00   0.00  100.00 100.00  97.74   1863   33.937   310  453.788  487.726
  0.00   0.00  100.00 100.00  97.74   1863   33.937   310  453.788  487.726
  0.00   0.00  100.00 100.00  97.74   1863   33.937   310  453.788  487.726
  0.00   0.00  100.00 100.00  97.74   1863   33.937   310  453.788  487.726
  0.00   0.00  100.00 100.00  97.74   1863   33.937   310  453.788  487.726
  0.00   0.00  100.00 100.00  97.74   1863   33.937   310  453.788  487.726
  0.00   0.00  100.00 100.00  97.74   1863   33.937   310  453.788  487.726
  0.00   0.00  100.00 100.00  97.74   1863   33.937   310  453.788  487.726
  0.00   0.00  100.00 100.00  97.74   1863   33.937   310  453.788  487.726
  0.00   0.00  100.00 100.00  97.74   1863   33.937   310  453.788  487.726
```

可以看出内存的年轻代和年老带的利用率都达到了惊人的100%。FGC的次数也特别多，并且在不断飙升。可以推断出
程序肯定是在哪里的实现有问题，需要重点查看大对象或者异常多的对象信息。此时可以生成headdump文件拿到本地来分析

### `jstack` 和 `jmap` 分析进程堆栈和内存状况
使用`jmap`命令导出heapdump文件，然后拿到本地使用**jvisualvm.exe**分析。

命令: `jmap [option] vmid`
jmap -dump:format=b,file=dump.bin 6764

命令: `jstack [option] vmid`
jstack -l 6764 >> jstack.out


从heapdump文件中定位到程序中的工作现场，和内存状况，如下：
线程:
```
"Thread-21" daemon prio=5 tid=85 WAITING
	at java.lang.Object.wait(Native Method)
	at java.lang.Object.wait(Object.java:503)
	at net.sf.jasperreports.engine.fill.AbstractThreadSubreportRunner.waitResult(AbstractThreadSubreportRunner.java:81)
	   Local Variable: net.sf.jasperreports.engine.fill.ThreadExecutorSubreportRunner#2
	at net.sf.jasperreports.engine.fill.AbstractThreadSubreportRunner.start(AbstractThreadSubreportRunner.java:53)
	at net.sf.jasperreports.engine.fill.JRFillSubreport.prepare(JRFillSubreport.java:758)
	at net.sf.jasperreports.engine.fill.JRFillElementContainer.prepareElements(JRFillElementContainer.java:331)
	   Local Variable: net.sf.jasperreports.engine.fill.JRFillSubreport#3
	at net.sf.jasperreports.engine.fill.JRFillBand.fill(JRFillBand.java:384)
	at net.sf.jasperreports.engine.fill.JRFillBand.fill(JRFillBand.java:358)
	at net.sf.jasperreports.engine.fill.JRVerticalFiller.fillBandNoOverflow(JRVerticalFiller.java:458)
	   Local Variable: net.sf.jasperreports.engine.fill.JRFillBand#3
	at net.sf.jasperreports.engine.fill.JRVerticalFiller.fillPageHeader(JRVerticalFiller.java:421)
	at net.sf.jasperreports.engine.fill.JRVerticalFiller.fillPageBreak(JRVerticalFiller.java:1954)
	at net.sf.jasperreports.engine.fill.JRVerticalFiller.fillColumnBreak(JRVerticalFiller.java:1981)
	at net.sf.jasperreports.engine.fill.JRVerticalFiller.fillDetail(JRVerticalFiller.java:754)
	   Local Variable: net.sf.jasperreports.engine.fill.JRFillBand[]#1
	   Local Variable: net.sf.jasperreports.engine.fill.JRFillBand#2
	at net.sf.jasperreports.engine.fill.JRVerticalFiller.fillReportStart(JRVerticalFiller.java:288)
	at net.sf.jasperreports.engine.fill.JRVerticalFiller.fillReport(JRVerticalFiller.java:151)
	at net.sf.jasperreports.engine.fill.JRBaseFiller.fill(JRBaseFiller.java:939)
	at net.sf.jasperreports.engine.fill.JRFiller.fill(JRFiller.java:152)
	   Local Variable: net.sf.jasperreports.engine.util.LocalJasperReportsContext#1
	   Local Variable: net.sf.jasperreports.engine.fill.JRVerticalFiller#1
	at net.sf.jasperreports.engine.JasperFillManager.fill(JasperFillManager.java:464)
	at net.sf.jasperreports.engine.JasperFillManager.fill(JasperFillManager.java:300)
	   Local Variable: java.io.File#135
	   Local Variable: net.sf.jasperreports.engine.JasperFillManager#1
	   Local Variable: net.sf.jasperreports.engine.JasperReport#1
	at net.sf.jasperreports.engine.JasperFillManager.fillReport(JasperFillManager.java:757)
	at com.pingan.icore.print.asyntask.jasper.AysnJasPdfConvertorThread.fill(AysnJasPdfConvertorThread.java:110)
	   Local Variable: java.lang.String#57815
	   Local Variable: java.lang.String#55498
	   Local Variable: java.util.HashMap#1682
	   Local Variable: java.lang.String#57807
	   Local Variable: java.lang.String#57809
	at com.pingan.icore.print.asyntask.jasper.AysnJasPdfConvertorThread.run(AysnJasPdfConvertorThread.java:223)
	   Local Variable: java.io.File#139
	   Local Variable: java.io.File#138
	   Local Variable: java.io.File#137
	   Local Variable: java.io.File#136
	   Local Variable: com.pingan.icore.print.asyntask.jasper.AysnJasPdfConvertorThread#1
	at java.lang.Thread.run(Thread.java:722)

```

内存:
发现这个net.sf.jasperreports.engine.fill.JRTemplatePrintText类的实例特别多，实例占了33.2%，大小占了58.1%

# 结论
到这里可以判断出是JasperReport在转换时对对象的创建和使用不当造成的。然而解决该问题并没有什么特别好的方式，除非去改源码或者换一个报表工具
根据上面的情况google了下别人是否遇到过类似的问题，然后定位到如下两个网址:
- http://community.jaspersoft.com/jasperreports-library/issues/4151
- http://community.jaspersoft.com/wiki/isprintwhendetailoverflowstrue-can-cause-report-render-indefinitely

可以看出新版的jasperreports依然会有该问题。只能通过取消勾选 **‘Print When Detail Overflows’**的选项来避免该问题
同时使jasperreport的virtualizer(Virtualizes data to the filesystem. When this object is finalized, it removes the swap files it makes. The virtualized objects have references to this object, so finalization does not occur until this object and the objects using it are only weakly referenced.)
来优化jasperreport的内存使用，减轻症状。
下面给出个使用demo:
- http://www.massapi.com/source/sourceforge/17/71/1771543975/oreports-code/openreports/src/org/efs/openreports/util/ScheduledReportJob.java.html#158

问题解决并不算完美。遗憾


# 感想
总的来说，这次问题排查的过程，很多思路和想法都是来自于之前阅读的一本书《深入理解Java虚拟机：JVM高级特性与最佳实践》的第二版。其中对虚拟机性能监控与故障处理以及jvm内存等的介绍以及一些实战都是很有帮助的，想了解的可以去阅读下。

