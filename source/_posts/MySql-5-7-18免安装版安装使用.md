---
title: MySql 5.7.18免安装版安装使用
date: 2017-05-26 21:32:04
tags: MySQL
categories: 工作记录

---

由于公司对电脑安全做了较多的限制。自己无法使用MySql的msi文件来安装Mysql。于是下了个mysql的zip压缩包来使用。
[Mysql下载地址](https://dev.mysql.com/downloads/mysql/),我下的是版本为mysql-5.7.18-winx64.zip

下载后解压到任意目录，进入到解压后的mysql-5.7.18-winx64。
按照以往的经验。首先进入到bin目录下运行`mysqld.exe`来初始化mysql。

```
D:\Dev\MySql\mysql-5.7.18-winx64\bin>mysqld.exe --initialize
```
不幸的是，失败了。错误日志如下:

```
D:\Dev\MySql\mysql-5.7.18-winx64\bin>mysqld.exe
mysqld: Could not create or access the registry key needed for the MySQL application to log to the Windows EventLog.
Run the application with sufficient privileges once to create the key, add the key manually, or turn off logging for that application.
mysqld: Can't change dir to 'D:\Dev\MySql\mysql-5.7.18-winx64\data\' (Errcode: 2 - No such file or directory)
 ...
```

<!-- more -->

可见由于没有管理员权限，初始化是不行滴。于是只能按照提示暂时关闭日志了并自己手动创建了`data`目录。
继续运行命令:
```
D:\Dev\MySql\mysql-5.7.18-winx64\bin>mysqld.exe --initialize --log_syslog=0
```
这次成功，成功运行后，会在mysql-5.7.18-winx64目录下生产data目录。

成功初始化后，使用窗口模式启动mysql，命令如下:
```
D:\Dev\MySql\mysql-5.7.18-winx64\bin>mysqld.exe --console
```

成功启动后另开一个窗口，使用默认的用户名密码("root"/"")进入mysql操作
```
D:\Dev\MySql\mysql-5.7.18-winx64\bin>mysql.exe -uroot -p
Enter password:
ERROR 1045 (28000): Access denied for user 'root'@'localhost' (using password: NO)
```
纳尼？居然提示用户名密码错误？我就纳闷了,mysql改了默认的空密码了？无奈，只能google下了。
结果发现貌似mysql5.7.10之后的初始化密码已经不是为空了，而是初始化话的时候会随机生成一个密码。用户需要使用这个密码进入mysql
且初次进入后是需要重新设置密码的，否则不允许操作,会有如下提示。
```
ERROR 1820 (HY000): You must reset your password using ALTER USER statement before executing this statement.
```

正确步骤如下:
1. 在data目录下找到.err后缀的文件，在里面查找`A temporary password is generated for root@localhost:`这句话找到生成的随机密码
2. 执行`mysql.exe -uroot -p`,然后输入刚刚找到的随机密码即可
3. 执行`mysql> alter user 'root'@'localhost' identified by 'yourpassword';`修改默认用户的密码。
4. 安全起见,刷新下权限。`mysql> flush privileges;`

好，接下来就可以愉快的正常使用mysql了。

---

最后附上mysql的官方安装文档:
[Installing MySQL on Microsoft Windows Using a noinstall Zip Archive](https://dev.mysql.com/doc/refman/5.7/en/windows-install-archive.html)