---
title: Drone 初探
seo_title: drone-for-beginner
date: 2019-06-21 11:14:55
tags: [CI,CD,Drone,Docker]
categories: [Program]
---

### 简介

Drone 是一个基于 Docker 的 CI/CD 工具，其所有编译、测试的流程都在 Docker 容器中进行。
其主要核心应该就是 configuration as a code + docker 了。每个项目下都需要定义一个 yml 配置文件，默认为 .drone.yml ，
在该配置文件中可自定义 Pipelines ，配置中的每一个 Pipeline 步骤都是在一个独立的 Docker 容器中自动执行的。
并且 Drone 现在已默认无缝集成了多种代码管理平台，目前有如下：
- GitHub
- Bitbucket
- GitLab
- Gitea
- Gogs

后面我会以集成 Github 为例来说明下我利用 Drone 自动将自己的 Github Pages 项目打包部署到自己服务器上的例子。

<!-- more -->

### 运行 Drone 准备

Drone 包含两个服务
- drone-server：负责后台管理界面以及调度
- drone-agent：负责具体的任务执行

所以，安装的时候最好统一安装管理咯，这边使用 docker-compose 来进行编排安装管理。
其他的一些核心概念的学习可以参考下 [GeekPipe -基于 Drone 的持续集成实践之基本概念篇](https://developer.finogeeks.com/topic/11/geekpipe-%E5%9F%BA%E4%BA%8Edrone%E7%9A%84%E6%8C%81%E7%BB%AD%E9%9B%86%E6%88%90%E5%AE%9E%E8%B7%B5%E4%B9%8B%E5%9F%BA%E6%9C%AC%E6%A6%82%E5%BF%B5%E7%AF%87)


#### 安装 Docker

1. 移除旧版(如果有)
   ```bash
   yum remove docker \
                     docker-client \
                     docker-client-latest \
                     docker-common \
                     docker-latest \
                     docker-latest-logrotate \
                     docker-logrotate \
                     docker-engine
   ```

2. 安装 Docker CE
    
    1. 安装必要的包    
        ```bash
        yum install -y yum-utils \
          device-mapper-persistent-data \
          lvm2
        ```
    2. 设置 docker 仓库             
        ```bash
        yum-config-manager \
            --add-repo \
            https://download.docker.com/linux/centos/docker-ce.repo
        ```
    3. 安装最新版 docker ce 和 containerd
        ```bash
        yum install docker-ce docker-ce-cli containerd.io
        ```
    4. 启动 Docker CE
        ```bash
        systemctl start docker
        ```
    5. 验证 Docker CE 是否正常启动
        ```
        docker run hello-world
        ```
        上述命令是运行了 hello-world 镜像，如果执行命令后能见到如下输出，说明 Docker 安装运行正常。
        {% asset_img docker-hello-world.png docker验证 %}
        
更多 Docker 相关文档请阅读[官方文档](https://docs.docker.com/)。 
        

#### 安装 Docker-compose

1. 添加 EPEL 源
```bash
yum install -y epel-release
```

2. 安装 python-pip
```bash
yum install -y python-pip
```

3. 安装 docker-compose
```
pip install docker-compose
```

我执行 `pip install` 的时候出现过如下错误:
> Command "python setup.py egg_info" failed with error code 1

解决方案: `pip install --upgrade setuptools`

参考: https://github.com/facebook/prophet/issues/418

更多 Docker-compose 使用请参考[官方文档](https://docs.docker.com/compose/overview/)


### 运行 Drone 服务

1. 创建 GitHub OAuth Apps
    
    Settings -> Developer settings -> Developer settings -> OAuth Apps -> New OAuth App
    {% asset_img drone-github.png 创建Apps %}
    创建后，会有 CLIENT_ID 和 CLIENT_SECRET，在下一步会用到。

2. 创建 docker-compose.yml
   
   进入 `/etc/drone` 创建 docker-compose.yml
    ```yaml
    version: '3'
    services:
      drone-server:
        image: drone/drone:1
        restart: always
        ports:
          - "8000:80"
          - "8443:443"
        volumes:
          - /var/lib/drone:/data
          - /var/run/docker.sock:/var/run/docker.sock
        environment:
          - DRONE_OPEN=true
          - DRONE_SERVER_PROTO=https
          - DRONE_TLS_AUTOCERT=true
          - DRONE_SERVER_HOST=drone.vioao.site
          - DRONE_RUNNER_CAPACITY=2
          # 集成 GitHub 配置
          - DRONE_GITHUB_SERVER=https://github.com
          - DRONE_GITHUB_CLIENT_ID=${GITHUB_CLIENT_ID}
          - DRONE_GITHUB_CLIENT_SECRET=${GITHUB_CLIENT_SECRET}
          # 需要自行生成配置值
          - DRONE_RPC_SECRET=${DRONE_RPC_SECRET}
          # 配置日志输出
          - DRONE_LOGS_DEBUG=true
          - DRONE_LOGS_TEXT=true
          - DRONE_LOGS_PRETTY=true
          - DRONE_LOGS_COLOR=true
          # 配置管理员
          - DRONE_USER_CREATE=username:vioao,admin:true
    
      drone-agent:
        image: drone/agent:1
        restart: always
        depends_on:
          - drone-server
        volumes:
          - /var/run/docker.sock:/var/run/docker.sock  
        environment:
          - DRONE_RPC_SERVER=drone.vioao.site
          # DRONE_RPC_SECRET 需要与 drone-server 中的一致 
          - DRONE_RPC_SECRET=${DRONE_RPC_SECRET}
          - DRONE_RUNNER_CAPACITY=2
          # 配置日志输出
          - DRONE_LOGS_DEBUG=true
          - DRONE_LOGS_TEXT=true
          - DRONE_LOGS_PRETTY=true
          - DRONE_LOGS_COLOR=true
    ```
    上面配置了 drone-server 和 drone-agent 服务，更多的服务相关配置请看[文档](https://docs.drone.io/)，
    这个 1.0 文档也是比较坑的，文档说明比较简陋。可以看看旧版 0.8 的文档，也可以多 Google 吧。
    
3. 后台运行 Drone 服务
   在 `/etc/drone` 目录下执行如下命令:
   ```
   docker-compose up -d
   ```
   
4. 配置 Apache 代理
   因为我自己的服务器本身是已经有了一个 Apache 服务，所以占用了 80 和 443 端口。因此，在上面配置的时候，
   Drone 是运行在 8000 和 8443 端口的，因此这里还需要稍微做个代理配置，给 Apache 的 httpd.conf 添加如下配置：
   ```conf
   <VirtualHost *:80>
       ProxyPreserveHost On 
       # RequestHeader set X-Forwarded-Proto "https"       用https的话得加这个    
       ProxyPass / http://127.0.0.1:8000/
       ProxyPassReverse / http://127.0.0.1:8000/
   </VirtualHost>
   ```
   
全部配置完成后，就能在浏览器访问 drone 服务，服务地址就是上面配置的 DRONE_SERVER_HOST 。GitHub 授权登录即可。
登录后会获取对应账号的 Github 项目列表：
{% asset_img drone-web.png Drone服务 %}
点击 Activate 进入即可激活。激活后如果项目中已有 .drone.yml 配置文件的话，当你 push 代码后， Drone 会自动执行你配置的
Pipelines 。上图是我已经激活并配置了 vioao.github.io 项目。   
   

### 配置项目 CI/CD

这个例子非常简单，只是用 drone 自动构建生成静态页面后，将其复制到我项目实际的部署目录上去（就是一个静态文件目录，已经在 Apache 服务配置过的）

1. 配置项目 CI/CD 配置 .drone.yml
    ```yaml
    kind: pipeline
    name: default
    
    steps:
      - name: build
        image: node
        # 映射主机 volumes [ drone -> host ]，该配置必须将对应的 repository 设置为 trusted
        # 可以在 drone 的 web 服务上进入对应的项目设置，但是登陆用户必须是管理员才行
        volumes:
          - name: target
            path: /drone/target/vioao.github.io
        commands:
          - npm install
          - ./node_modules/hexo/bin/hexo clean
          - ./node_modules/hexo/bin/hexo g
          - pwd && rm -rf /drone/target/vioao.github.io/*
          - mv /drone/src/public/* /drone/target/vioao.github.io
          - cd /drone/target/vioao.github.io && ls -l
        # 配置执行调整，只有 blog 分支有变化时才会执行对应的 step
        when:
          branch:
            - blog

    volumes:
      - name: target
        host:
          path: /var/www/mine
    ```
    上述如果直接将 public 目录映射到 host 需要部署的目录的话，在执行 `hexo clean` 命令时会报如下错误:
    > Error: EBUSY: resource busy or locked
    
2. 验证 CI/CD

    提交代码到 blog 分支即可。Drone 会自动执行对应的步骤。
    {% asset_img drone-task.png Drone任务 %}
    {% asset_img drone-task-detail.png Drone任务详情 %}
    如果提交了代码，但是却没有触发对应的构建任务的话，那你可以 GitHub 的对应 repository 的 Webhooks 配置，看看其对应
    drone 的 WebHook 地址是不是能正常访问。 如果是构建过程出错，那一般是 .drone.yml 配置文件有问题了，看对应的构建日志去
    解决问题即可。
    

### 配置项目 CI/CD -- 改进

上面的配置是部署到自己服务器的，还有一种是直接部署到 GitHub Pages 和 Coding Pages 上去的。之前我有场 Chat 
[无需服务器构建属于自己的博客站](https://gitbook.cn/gitchat/activity/5d00a0737a4f0413709aa7d4) 就有讲同时部署到本地如何
同时部署到 GitHub Pages 和 Coding Pages。

现在我们要利用 Drone 来完成这个工作。
其实目前已经有一个插件 [drone-gh-pages](https://github.com/drone-plugins/drone-gh-pages) 可以帮你部署到 GitHub Pages 了。
但是这个插件无法部署到 Coding Pages 上去。这边对这个插件研究了下，发现其实它只需要暴露出两个配置就可以支持的，于是我提交
了个 [Pull Request](https://github.com/drone-plugins/drone-gh-pages/pull/25)，不过后来发现好像有个几乎一样的 Request，
看上去作者并不想将这个功能合并。没办法的我只能自己构建一个发布到 Docker Hub 了。大家使用我的镜像即可。调整后 Drone 流程可
同时发布到服务器、GitHub Pages、Coding Pages。

1. 调整配置
    ```yaml
    kind: pipeline
    name: default
    
    steps:
      - name: build
        image: node
        volumes:
          - name: target
            path: /drone/target/vioao.github.io
        commands:
          - npm install
          - ./node_modules/hexo/bin/hexo clean
          - ./node_modules/hexo/bin/hexo g
          - rm -rf /drone/target/vioao.github.io/*
          # 需要将构建好的文件复制到不同的目录，供后面的 step 使用
          - cp -r /drone/src/public/* /drone/target/vioao.github.io     
          - mkdir github_pages && cp -r /drone/src/public/* /drone/src/github_pages
          - mkdir coding_pages && cp -r /drone/src/public/* /drone/src/coding_pages
        when:
          branch:
            - blog
    
      - name: publish github pages
        image: plugins/gh-pages
        settings:
          remote_url: https://github.com/vioao/vioao.github.io.git
          # step 设置独立的 pages_directory 和 temporary_base，便于不同 step 的文件隔离
          pages_directory: github_pages
          target_branch: master
          temporary_base: .github_tmp
          # 用户名密码需要在 Drone 服务商设置对应的 Secrets
          username:
            from_secret: github_username
          password:
            from_secret: github_password
    
      - name: publish coding pages
        # 这里使用的是我自己构建的镜像
        image: vioao/drone-gh-pages
        settings:
          # coding pages 相关配置
          machine: git.coding.net
          remote_url: https://git.coding.net/vioao/vioao.git
          pages_directory: coding_pages
          target_branch: master
          temporary_base: .coding_tmp
          username:
            from_secret: coding_username
          password:
            from_secret: coding_password
    
    volumes:
      - name: target
        host:
          path: /var/www/mine
    ```

2. 添加 Secrets
    
    在对应的项目 Setting 上添加即可：
    {% asset_img drone-secret.png 添加Secret %}


### 总结

从上面的操作的感受来说，Drone 的代码即配置，有点像 docker-compose ，整体比较简洁，并且支持 pipeline steps 、webhook、services
等。基本 CI/CD 的功能都是支持的，且符合云原生的趋势。但是感觉还是比较年轻啊，而且文档是真心有点简陋(比如中途想看 Drone 插件编写的相关文档就没找着)，多数时候还是需要自己去Google下。
另外，文档不支持搜索也是有点鸡儿疼的。
