---
title: 关于我
date: 2017-05-19 20:59:45
---

<img align='right' src='https://octodex.github.com/images/daftpunktocat-guy.gif' width='200'>

### Hi there 👋

I'm Vio. A software engineer @ShenZhen.

Major skill
- Java
- Python
- Typescript & HTML
- Flutter

---

这是我利用业余时间做的一些应用

#### 必省生活公众号&小程序

必省生活是一个集红包领取/低价购物/消费返现的生活平台。可以渗透到生活的方方面面。能够最大程度的给你生活中的消费节省费用。聚少成多。
- 特价电影票
- 外卖红包
- 出行红包
- 特价卡券
  - 腾讯/优酷/爱奇艺等各大影音会员
  - 美团/饿了么等各大餐饮会员
- 特价快递
- 特价话费充值
- 淘宝/抖音/PDD购物返现

<img src='https://i.imgs.ovh/2023/12/01/pNAtt.jpeg' width='200'>



#### 临时邮箱小助手
这是一个可以提供临时、安全、匿名、免费的一次性电子邮箱的小程序。
是不是有些网站/应用必须要注册才能查看内容。但是你以后又不太可能回到这个网站，或者你压根就不想使用自己的私人邮箱。那么可以使用这个小程序来获取临时邮箱接收验证码。
- 支持自定义邮箱地址
- 支持附件下载
- 邮件临时保存

<img src='https://i.imgs.ovh/2023/12/01/pN2L0.jpeg' width='200'>


#### 智能水印工具箱
一个图片/短视频处理的小程序
- 图片去水印
- 图片画质增强
- 图片背景移除
- 短视频去水印
- 短视频图集一键提取

<img src='https://i.imgs.ovh/2023/12/01/pNF0C.jpeg' width='200'>



#### Z-Library 镜像小程序
Z-Library（简称Z-Lib，前身为BookFinder）是一个影子图书馆和开放获取文件分享计划，用户可在此一网站上下载期刊文章以及各种类型的书籍。
本小程序是将其镜像并搬运到微信平台。方便大家使用。

<img src='https://i.imgs.ovh/2023/12/01/pNXjU.jpeg' width='200'>



<div class="links-of-author motion-element" style="display: inline-block; opacity: 1; margin-top: 0">
{% if theme.social %}
  {% for name, link in theme.social %}
    <span class="links-of-author-item">
      <a href="{{ link }}" target="_blank" title="{{ name }}">
        {% if theme.social_icons.enable %}
          <i class="fa fa-fw fa-{{ theme.social_icons[name] | default('globe') | lower }}"></i>
        {% endif %}
        {{ name }}
      </a>
    </span>
  {% endfor %}
{% endif %}
</div>