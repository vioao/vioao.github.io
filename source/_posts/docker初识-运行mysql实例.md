---
title: 'docker初识:运行mysql实例'
seo_title: run-mysql-in-docker
date: 2017-07-26 21:29:52
tags: [Docker,MySQL]
categories: [Program]
---

# 环境

 - CentOS 7.3 64bit

# 安装docker

1. 移除旧版本Docker
   > yum remove docker docker-common docker-selinux docker-engine

2. 设置Docker仓库

    2.1 安装所需要的包
    > yum install -y yum-utils device-mapper-persistent-data lvm2

    2.2 设置添加稳定版的Docker仓库
    > yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

    <!-- more -->

3. 安装 DOCKER CE

   3.1 更新`yum`
   > yum makecache fast

   3.2 安装最新版的docker ce
   > yum -y install docker-ce

   3.3 也可以安装指定版本的docker ce
      - 列举可用的docker ce
        > yum list docker-ce.x86_64  --showduplicates | sort -r
      - 安装指定版本
        > yum install docker-ce-\<VERSION>

4. 启动Docker
   > systemctl start docker

5. 查看Docker版本
   > docker -v

6. 卸载Docker(Optional)

   6.1 卸载docker安装包
   > yum remove docker-ce

   6.2 删除所有的 images, containers, volumes(一些自定义的配置文件需要自己手动删除)
   > rm -rf /var/lib/docker


# 安装Docker compose
1. 下载安装1.14.0版本的Compose
   > curl -L https://github.com/docker/compose/releases/download/1.14.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose

2. 赋予可执行权限
   > chmod +x /usr/local/bin/docker-compose

3. 查看版本号验证是否安装成功
   > docker-compose -v


#  docker运行mysql实例
1. 下载官方的mysql镜像
   > docker pull mysql:5.7.18

2. 启动mysql
   ```
   docker run --name mysql_db -p 3306:3306  -v /home/docker/mysql/logs:/data/logs/mysql -v /home/docker/mysql/data:/var/lib/mysql -v /home/docker/mysql/conf/:/etc/mysql/conf.d -e MYSQL_DATABASE=opencart -e MYSQL_ROOT_PASSWORD=Ao@1234567890 -d mysql:5.7.18
   ```

   参数说明:
   - `-p 3306:3306` ("port_you_want" : "exposed_port_from_dockerfile") 端口映射
   - `--name mysql_db` 指定docker container名称为mysql_db
   - `-v /home/docker/mysql/data:/var/lib/mysql` 映射container中mysql的数据目录`/var/lib/mysql`到本地`/home/docker/mysql/data`
   - `-v /home/docker/mysql/conf/:/etc/mysql/conf.d` 映射配置文件目录
   - `-v /home/docker/mysql/logs:/data/logs/mysql` 映射日志文件
   - `-e MYSQL_DATABASE=opencart` 设置启动环境参数MYSQL_DATABASE(初始化时创建的数据库)
   - `-e MYSQL_ROOT_PASSWORD=password` 设置初始化的mysql root用户密码
   - `-d mysql:5.7.18` demean模式运行mysql:5.7.18

   详细参数说明参考[Mysql Docker镜像文档](https://hub.docker.com/_/mysql/)

   附上简短的my.cnf配置
     ```
     ######################### my.cnf #######################################
     # 对应日志文件需要手动创建,并赋予mysql可读写权限,否则container启动不成功
     # 错误日志
     log-error=/var/log/mysql/error.log

     # 打开全查询日志. 所有的由服务器接收到的查询 (甚至对于一个错误语法的查询)
     # 都会被记录下来. 这对于调试非常有用, 在生产环境中常常关闭此项.
     general_log=ON
     general_log_file=/var/log/mysql/mysql.log

     # 慢查询日志
     slow_query_log=on
     long_query_time=2 #2s
     slow_query_log_file=/var/log/mysql/slowquery.log

     # 打开二进制日志功能.
     # 在复制(replication)配置中,作为 MASTER 主服务器必须打开此项
     # 如果你需要从你最后的备份中做基于时间点的恢复,你也同样需要二进制日志.
     #log-bin=/usr/local/mysql/logs/mysql-bin
     ```

3. 查看启动日志(启动时出错可以观察下是什么原因)
   > docker logs mysql_db

4. 查看运行中的容器
   > docker ps

   查看所有容器
   > docker ps -a

5. 安装mysql客户端
   > yum -y install mysql

6. 连接mysql
   > mysql -h 127.0.0.1 -uroot -p

7. 停止容器
   > docker stop mysql_db

8. 启动已有容器
   > docker start mysql_db

9. 在另一个container中使用mysql
   > docker run --name some-app --link mysql_db:mysql -d application-that-uses-mysql
