---
title: 从 VPS 到科学上网一气呵成
seo_title: build-vpn-with-vps
date: 2019-08-27 10:47:13
tags: [VPS,SSR,V2Ray]
categories: [Side Project]
---

### 起因

最近自己的香港阿里云服务器到期了，也不打算续期了，是在太贵。最低配一年一千多，其实我也没啥事要做，再续期的话就不划算了，遍放弃了。但是，科学上网的需求还是有的啊。于是便想要买个 VPS 自己整个跳转用用，对于这个 VPS 我只有两个要求：

1. 便宜，一定要便宜！！！！毕竟自己需求较小，花多了钱觉得不划算
2. 流量要不限量。（虽然我也不咋用，但是我就是想要不限量）

### VPS 购置
#### 挑选 VPS
首先我是按照自己的要求 google 了一番合适的 VPS 的，有下面几个链接比较有用：
1. [2019 年最好的国外 VPS 推荐](https://www.10besty.com/best-vps-hosting-services/)
2. [10美元以下国内VPS/美国VPS推荐](https://www.vpser.net/ten-dollars-vps)
3. [老左常用国内/国外便宜VPS主机商家推荐整理](https://www.laozuo.org/myvps)

当然，按照我的要求，我选择了 [**BuyVM**](https://my.frantech.ca/aff.php?aff=3157) 家最便宜的一个 VPS。配置收费如下：

- $2 USD/Month，年付更优惠：$18.68 USD/Year ，支持支付宝付款
- 流量不限
- 512M 内存
- 10G 存储
- KVM 架构
- 1 核 CPU

这个配置用来部署一些小工具和用来科学上网是足够了。(这个，有个比较坑的地方就是，他的网速貌似不是很稳定，下载速度有时候有 1M/s，有时候只有 50k/s 这样子。。。。)

<!-- more -->

#### 购买 VPS

购买 VPS 没有太多东西要说的，大家根据自己的要求选择对应的配置就好。不过还是有几个点需要注意：

1. 他家的 VPS 主要在拉斯维加斯、纽约、卢森堡三个地方。不一定都有货，选择网络连通较好并有货的就OK。我买的是拉斯维加斯的
2. **如果选择 Paypal 付款，请确保你的 Paypal 账户的邮箱和你 BuyVM 账号的邮箱一致**
3. 购买后，服务可能会处于 Pending 状态，需要等待。如果时间超过 2h，请提 Tickte 询问原因。
4. **所有过程，请留意你的邮箱**。老外就是喜欢邮箱，所有的服务相关信息会通过邮箱给你。包括
    - 后台管理 [Stallion](https://manage.buyvm.net) 的登录账号和密码
    - VPS 服务器的 IP 和 相关配置登录信息 ( SSH 连接 VPS 的账号就是 root，密码就是你购买时配置的 ROOT 密码)
5. 有任何疑惑，尽管提工单

具体购买流程如下：

1. 选择 VPS
   {% asset_img select-vps.png 选择VPS %}

2. 配置 VPS（半年付开始会更便宜，不过我是先买一个月试水）
   {% asset_img config-vps.png 配置VPS %}

3. 选择付款方式并付款
   {% asset_img pay-vps.png 付款 %}

4. 成功购置，服务处于 Active 状态
   {% asset_img check-vps.png Active %}

5. 登录 后台管理 [Stallion](https://manage.buyvm.net) ，为服务安装 CentOS
   {% asset_img install-vps.png 安装系统 %}

6. SSH 连接到服务器，肆意妄为

### 科学上网
#### 搭建梯子
目前比较多用的梯子有两种：SSR 和 V2Ray。我这边之前搭建的 SSR，这次想弄点不一样的，就弄了个 V2Ray 试试。

SSR 和 V2Ray 二选一：

- [ShadowsocksR 安装配置](https://www.zfl9.com/ssr.html)
  - [客户端](https://ssr.tools/175)
- [V2Ray 下载安装](https://www.v2ray.com/chapter_00/install.html)
  - [相关配置](https://www.v2ray.com/chapter_02/01_overview.html) ,默认安装的基本配置是直接可用的，需要更高级的特性的话可以看看这个配置说明
  - [客户端](https://www.v2ray.com/awesome/tools.html)

#### 服务器优化: BBR 加速（可选）
##### 啥是 BBR
>  2016年9月，Google 开源了其 TCP BBR 拥塞控制算法，并提交到了 Linux 内核，从 4.9 开始，Linux 内核已经用上了该算法。根据以往的传统，Google 总是先在自家的生产环境上线运用后，才会将代码开源，此次也不例外。  
根据实地测试，在部署了最新版内核并开启了 TCP BBR 的机器上，网速甚至可以提升好几个数量级。  
通俗的来说，BBR就和锐速一样，是用来提速的，当然再如何提速也不可能突破物理带宽，他只是一个优化网络拥堵的算法。

##### 安装
1. 一键安装
   ```bash
    wget --no-check-certificate https://github.com/teddysun/across/raw/master/bbr.sh && chmod +x bbr.sh && ./bbr.sh
   ```
2. 重启后验证是否安装成功
    ```bash
    [root@giratina ~]# uname -r
    5.2.10-1.el7.elrepo.x86_64
    ```

#### 配置防火墙
服务器上来是需要配置防火墙的，不然相当于裸奔了。

1. 启动防火墙
    ```bash
    [root@giratina ~]# systemctl start firewalld
    ```
2. 验证防火墙
    ```bash
    [root@giratina ~]# systemctl status firewalld
    ● firewalld.service - firewalld - dynamic firewall daemon
        Loaded: loaded (/usr/lib/systemd/system/firewalld.service; disabled; vendor preset: enabled)
        Active: active (running) since Mon 2019-08-26 19:00:49 PDT; 34min ago
          Docs: man:firewalld(1)
      Main PID: 4162 (firewalld)
         Tasks: 2
        Memory: 29.4M
        CGroup: /system.slice/firewalld.service
                └─4162 /usr/bin/python -Es /usr/sbin/firewalld --nofork --nopid

    Aug 26 19:00:48 giratina.unovarpgnet.net systemd[1]: Starting firewalld - dynamic firewall daemon...
    Aug 26 19:00:49 giratina.unovarpgnet.net systemd[1]: Started firewalld - dynamic firewall daemon.
    ```
3. 添加对应的开放端口(按需配置)
    ```bash
    [root@giratina ~]# firewall-cmd --zone=public --add-port=14361/tcp --permanent
    [root@giratina ~]# firewall-cmd --zone=public --add-port=80/tcp --permanent
    [root@giratina ~]# firewall-cmd --zone=public --add-port=443/tcp --permanent
    ```
4. 更新防火墙规则
    ```bash
    [root@giratina ~]# firewall-cmd --reload
    ```
5. 验证/查看开放的端口
    ```bash
    [root@giratina ~]# firewall-cmd --zone=public --list-ports
    ```

### Docker 运行礼包

懒一点的也可以直接使用我的一个工具包 [docker-utils](https://github.com/vioao/docker-utils)  
按照说明启动对应的服务即可。  
里面的一些个人相关的配置需要自己修改下.