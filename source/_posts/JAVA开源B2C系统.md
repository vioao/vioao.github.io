---
title: 'JAVA开源B2C系统'
seo_title: opensource-java-b2c-system
date: 2017-07-03 21:09:02
tags: [Java,B2C,OpenSource]
categories: [Side Project]

---

# 前言
最近有人想面向境外销售商品，但是又不想依托于亚马逊这些平台，于是找我来帮忙想弄个B2C系统。因为刚开始只是打算试试水，也就不打算投入多少成本了。所以这边就考虑使用开源的B2C系统来直接使用了。

---

# B2C开源系统选择
由于自己的主语言是JAVA，平时工作也都是用的JAVA。考虑到以后需要对系统进行二开、部署维护等。所以一开始就直接查找JAVA 的开源系统了，并且将是JAVA语言开发的作为了第一个必要选项。结果却是证明了自己的愚蠢啊。
在这里需要说明在选择一个开源系统作为线上系统实际部署应用的时候，我们应该主要考虑这几项:
1. 项目的成熟程度
2. 项目的生态环境
3. 项目的二开友好程度
4. 自己对项目的熟悉程度

就我自己来说，上面几点的重要程度应该是从高到低的。

<!-- more -->

---

# 几款开源的JAVA商店系统
刚开始的时候查找开源商店系统没有什么头绪，都是直接通过关键字查找 ，什么 `java Open source shop` 、 `java 开源商店` 、 `JAVA 开源购物车` 等。查找起来特别费时，非常的浪费时间。特别是国内的，很多打着开源的幌子，实际上公布出来来的代码都是缺斤少两的，或者根本就没有把代码开源出来，简直是浪费了一堆时间来过滤。

不过后台发现了一个收集了目前开源Shop的网站 **[eCommWar](https://www.ecommwar.com/)**,这个网站收集了目前开源的网店系统，网站上有对项目的简要描述，项目的使用语言，项目的首页地址，项目的github star数量，fork数量等都要标注出来，真的是非常的实用。要是选型开源网店系统的话直接在这里了解相关信息一般是足够的了。
然而我一开始并没有发现这东西，一心就想着找JAVA写的。结果就找到了下面这三个，下面一一简单说明下。

---

## Shopizer
[Shopizer](http://www.shopizer.com/) 是JAVA语言写的开源B2C系统。主要技术栈是 `Spring Core`、`Spring MVC`、`Spring Security`、`Hibernate`、`Elasticsearch`、`JBoss Infinispan`。这些是一般JAVA程序猿比较熟悉的技术栈了。这个项目从五年前开始，现在依然还有在维护，还是有一点活跃度的。
基本的商店系统该有的功能一般都有了，详细查看他们的官网介绍:[Shopizer 支持的功能](http://www.shopizer.com/#!/discover)。 但是！我是后悔没有好好看首页啊。 首页有一句话，引用他们的原文
> Shopizer's team is developing for developers first(首先是面向开发人员开发的啊有木有，要是一开始把这句看进去了后面就不会checkout代码研究开发了)

感受下项目的前端和后台:

{% asset_img shopizer_front_end.png shopizer前端 %}

{% asset_img shopizer_background.png shopizer后台 %}

下面简要说下Shopizer的优缺点
### 优点
- Shopizer 支持多店铺系统；
- 支持多语言，不过目前只有英语和法语，想要其他语言的还需要自己翻译；
- 基于Elasticsearch做的搜索，效果还不错；
- 技术栈对于JAVA开发人员来说比较熟悉
- 作者没有弃坑,依然在维护
- 后期如果做大，扩展方便

---

### 缺点
- 产品成熟度不够，功能还是不够完善(营销推广、系统监控备份之类的没有)
- 产品首先面向开发人员(也就是说,不好使用!!!!,特别是后台，特别不好用)
- 对于小用户来说，该系统对内存要求稍高(单机4G内存才可以运行良好)
- 系统还有不少bug。。。(系统代码维护不是特别好，有些地方逻辑不清晰，备注文档也少)

---

## Broadleaf Commerce
[Broadleaf Commerce](www.broadleafcommerce.com) 是基于Spring的企业级商店系统。不过这个系统从5.0版本开始就不再开源了，最新版是需要收费的。不过前面几个版本的还是开源的，不过可以想到后面对于开源版本的估计也不会花什么时间来维护了把。很有可能直接弃坑了。不过呢，这个系统文档比较完善，4.0版本的已经有比较完善的文档了 Tutorials、Javadoc 这些都有，不过更早版本的就木有了。这个项目被一开的官网收费吓到了，导致后来没有自己的调查，感觉错过了一个好东西，现在回过头来看感觉应该会是个不错的开源系统。

### 优点
1. 系统相对成熟，功能比较完善
2. 社区比较活跃
3. 可定制程度高(比较适合有一定开发能力的中小企业)

### 缺点
1. 最新版不开源,有弃坑风险

由于这个没有做太多的调查，也没有把代码checkout下来研究。所以就简单介绍下就是啦。。。大家可以参考他们的官网和这篇博文:[BroadleafCommerce简介](http://blog.csdn.net/jimmybinbin/article/details/45027735)

---

## mayocat-shop
[mayocat-shop](https://github.com/jvelo/mayocat-shop) 也是一个JAVA的开源商店系统。致力于做一个开源商店系统并构建marketplace平台供大家使用。类似 wordpress 的。可以在marketplace 下载或上传插件模版之类的。 主要致力于针对解决下面两个市场空缺:
1. 针对那些想构建一个商店系统的小用户来说目前市场缺少一个简单的解决方案
2. online marketplaces提供平台聚集网页制作设计

mayocat-shop主要技术栈:
- PostgreSQL
- ElasticSearch
- REST/Jersey
- Jetty
- Mustache / Handlebars

{% asset_img mayocat_tec.png mayocat-shop技术栈 %}

### 优点
1. 前后分离(分工明确,部署灵活)
2. 项目目标不错，适合中小企业及个人用户
3. 技术栈对于JAVA开发人员来说比较熟悉
4. 懂html和js就可以定义前端模版

### 缺点
1. 致命伤，从2017.02开始已经不再维护了

其他的就不用再说啦。

---

# 结束语
上面只是简单了记录了自己在找JAVA开源商店系统的时候了解的一些东西。需要选型开源商店系统的话，这个 **[eCommWar](https://www.ecommwar.com/)** 网站真的特别有用。作为个人用户和小商户企业来说，个人**不建议使用JAVA的开源商店系统**，目前市面上比较成熟的都是PHP开发的，读者可以在 **eCommWar** 这个网站上去查找对比。
我这边最终选用了 **[OpenCart](https://www.opencart.com/)**，这是一个PHP写的开源的B2C商店系统，功能完善，生态圈好，有各种插件。中国有对应的论坛，使用量多，非常适合小商户。
接下来打算写下 **Shopizer搭建开发** 和 **OpenCart的搭建部署**