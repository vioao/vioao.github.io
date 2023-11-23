---
title: 微信公众平台SDK JAVA实现WeChat-SDK
seo_title: java-wechat-sdk
date: 2018-01-21 10:31:13
tags: [Java,WeChat,公众平台,开放平台]
categories: [Java]

---
# 前言
最近有做一些涉及到微信公众平台和第三方平台开发的工作。需要使用微信提供的接口。然而微信只提供了基于基本的HTTP接口，并没有对应各语言的SDK实现。所以如果自己开发的话需要封装一套SDK。不过，微信公众平台出来几年了，市面上早就有不少JAVA实现的微信SDK了。于是便收集了一些开源的JAVA实现的微信SDK，但是最后都不是特别合适。最终决定自己写一个。下面给出各开源SDK的实现对比和自己的写的进展。

# 微信公众号java sdk技术选型
针对目前开源的公众号java sdk对比，之前已经有人对比过了。可以自行前去:[微信公众号java sdk技术选型](https://my.oschina.net/ywbrj042/blog/402049)

针对上面几款开源的微信公众号SDK，针对我自己的需求，我自己也做了下简单的对比:

|     -          | jfinal-weixin | weixin-java-tools|fastweixin |weixin-popular|
|:-----|:-----:|:-----:|:-----:|:-----:|
| 实现简单        |  √            |  x               |  √       |  √  |
| 更新快且全          | √             |  √           |  √       |  √  |
| 有对应的实体封装  | x             |  √               |  √       |  √  |
| 依赖少          | x             |  x                |  √       |  √  |
| 方便支持多公众号  |  √           |  x                |  x       |  √  |
| 代码结构&可拓展性 |  √           |  √               | √        |  x  |


可以看出是没有一个是完全符合自己的需求的。没有找到方便支持多公众号管理，代码结构好容易扩展且依赖少，更新快，使用简洁的。所以最后自己还是决定自己实现对应的SDK了。

<!-- more -->

# 自实现WeChat-SDK
目前只实现了一些微信基本的SDK。按照微信公众平台接口文档分类。

**已实现功能:**
 - 自定义菜单[√]
 - 消息管理[√]
 - 微信网页开发(网页授权)[√]
 - 素材管理[√]
 - 图文消息留言管理[√]
 - 用户管理[√]
 - 账号管理[√]
 - 数据统计[√]
 - 新版客服功能[√]
 - 微信第三方平台[√]
 - 微信卡券[√]
 - 微信门店[√]

**未实现功能:**
 - 微信小店[x]
 - 语义理解[x]
 - 微信设备功能[x]
 - 微信摇一摇周边[x]
 - 微信连WI-FI[x]
 - 微信扫一扫[x]
 - 微信发票[x]


**项目依赖:**
- jackson(可选，默认的序列化工具类依赖于jsckson。可自定义实现对应的序列化接口)
- slf4j(日志用)
- httpcomponents (可选，默认的HTTP请求工具类依赖于httpcomponents 。可自定义实现对应的HTTP请求接口)
- junit (测试用)

除了实现对应的微信功能接口。还提供了一些支持类的接口和默认实现。可以根据自己的需要使用默认的实现或使用自定义的实现。如消息查重接口、token缓存管理接口、消息推送处理接口、消息处理器管理接口。
目前只实现了上述功能。对应的测试用例也只写了一部分。需要后面慢慢的完善。

# WeChat-SDK使用

**maven依赖:**
```
<dependency>
  <groupId>com.github.vioao</groupId>
  <artifactId>wechat-sdk</artifactId>
  <version>1.1.0</version>
</dependency>
```
目前是版本1.0.0，接下来会不断完善代码。使得代码功能更全，使用更方便。

**接口使用示例:**

```java
    // 用户标签接口
    @Test
    public void testAboutTagUsers() {
        TagsResponse result1 = UserApi.getTags(TOKEN);
        System.out.println("Get tags: " + result1);
        Assert.assertEquals(true, result1.isSuccess());

        if (result1.getTags().size() > 0) {
            Integer tagId = result1.getTags().get(0).getId();

            BaseResponse result2 = UserApi.batchTagUsers(TOKEN, Arrays.asList(OPENID), tagId);
            System.out.println("Batch tag users: " + result2);
            Assert.assertEquals(true, result2.isSuccess());

            FollowResponse result3 = UserApi.getTagUserIds(TOKEN, tagId, null);
            System.out.println("Get tag users: " + result3);
            Assert.assertEquals(true, result3.isSuccess());

            BaseResponse result4 = UserApi.batchUnTagUsers(TOKEN, Arrays.asList(OPENID), tagId);
            System.out.println("Batch tag users: " + result4);
            Assert.assertEquals(true, result4.isSuccess());
        }
    }

    // 菜单接口
    @Test
    public void testCreate() {
        Button click = new Button();
        click.setType("click");
        click.setName("今日歌曲");
        click.setKey("V1001_TODAY_MUSIC");

        Button view = new Button();
        view.setType("view");
        view.setName("搜索");
        view.setUrl("http://www.soso.com/");
        Button click2 = new Button();
        click2.setType("click");
        click2.setName("赞一下我们");
        click2.setKey("V1001_GOOD");
        Button complex = new Button();
        complex.setName("菜单");
        complex.setSubButton(Arrays.asList(view, click2));

        MenuButtons menuButtons = new MenuButtons();
        menuButtons.setButton(Arrays.asList(click, complex));
        BaseResponse result = MenuApi.create(TOKEN, menuButtons);

        System.out.println("Create Menu: " + result);
        Assert.assertEquals(true, result.isSuccess());
    }
```

更多示例可以查看项目的单元测试代码。项目地址:
# [wecht-sdk](https://github.com/vioao/wechat-sdk)

---

# 更新日志

## 2018-02-28
Done:
> **完善以下功能模块的实现:**
- 微信门店功能
- 微信卡券功能

---


## 2018-03-11
Done:
> **第三方平台对小程序的管理:**
- 小程序服务器域名设置
- 小程序成员管理
- 小程序微信登录
- 小程序基础信息设置
- 微信开放平台帐号管理

ToDo:
> **第三方平台对小程序的管理**
   - 代码管理
   - 小程序模版库管理
   - 小程序代码模版库管理

---

## 2018-03-24
Done:
> **第三方平台对小程序的管理:**
- 小程序代码管理
- 小程序代码模版库管理
- 小程序模版设置
- 小程序插件管理权限集

> **发布1.1.0版本**
- 本次版本主要是完善了第三方平台相关的接口支持。可以基于wechat-sdk方便实现自己的第三方平台。管理平台下的小程序和公众号。

**maven依赖:**
```
<dependency>
  <groupId>com.github.vioao</groupId>
  <artifactId>wechat-sdk</artifactId>
  <version>1.1.0</version>
</dependency>
```

ToDo:
> **第三方平台相关:**
- 卡券强授权
- 微信广告接口


> **公众号相关:**
  - 微信摇一摇周边
  - 微信卡券
  - 微信小店
  - 语义理解
  - 微信连WI-FI
  - 微信扫一扫
  - 微信设备功能
  - 微信发票
