---
title: 利用Github Pages和Hexo搭建个人博客
seo_title: how-to-build-personal-blog-with-github-pages-and-hexo
date: 2017-05-29 10:02:26
tags: [GitHub,Hexo,Next,Blog,Html]
categories: [Program]
---

## Github Pages和Hexo介绍
**[Github Pages](https://pages.github.com/)** 是 **[Github](https://github.com/)** 推出的一个福利。可以在上面构建个人页面。**[Hexo](https://hexo.io/zh-cn/)** 就是一个快速、简洁且高效的博客框架(官网上是这么说的,hhh),并且支持一键部署到github。可以用它来构建自己的个人博客，当hexo遇到Github pages时,我们就不需要自己的一个服务器就可以搭建一个个人博客网站了。下面开始讲搭建过程。

<!-- more -->

---

## 创建自己的Github Pages
首先需要在Github上创建自己的静态页面。这个需要使用到Github Pages服务，需要有Github账号才行。如果没有账号的自行去官网注册一个。这里就不多说了。
如何创建自己的静态页面，总的来说就是(假设你使用过GitHub):
1. 创建一个和Repository 并将其命名为 _username_.github.io其中 _username_ 是你自己的github用户名。
2. 在该Repository下创建静态页面(eg. index.html)
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Title</title>
</head>
<body>
Hello World!

</body>
</html>
```
3. 访问 _username_.github.io就可以见到你创建的静态页面了。(就是一个有Hello World字样的页面)

不过如果你没使用过GitHub的话，官网上也有详细的引导步骤。具体参考[Github Pages](https://pages.github.com/)上第二步中的 _I don't know_ 环节

---

## 使用Hexo建站
安装使用Hexo需要依赖到[Nodejs](https://nodejs.org/en/),如果你还没有就赶紧去官网上下一个吧。参照官网的安装步骤，还是非常简单的。
安装完Nodejs后使用hexo就容易了。

### 安装Hexo
1. 下载安装[Nodejs](https://nodejs.org/en/download/)
2. 使用NPM安装Hexo
```
$ npm install hexo-cli -g
$ hexo init blog
$ cd blog
$ npm install
$ hexo server
```


### 使用Hexo建站
这个其实在[官网文档](https://hexo.io/zh-cn/docs/)中已经说的很详细的了。大家可以参照文档中的去做。大致的步骤就是:
1. 初始化目录，目录结构请参考[官网说明](https://hexo.io/zh-cn/docs/setup.html)
```
$ hexo init <folder>
$ cd <folder>
$ npm install
```

2. 创建自己的博文,参考[写作](https://hexo.io/zh-cn/docs/writing.html)
```
$ hexo new [layout] <title>
```

3. 修改配置,生成页面并部署到GitHub,参考[部署](https://hexo.io/zh-cn/docs/deployment.html)
```
$ hexo deploy
```
以上只是一个概括性的建站步骤，详细配置说明这些大家需要进入到官网文档中自行去了解。


### 选择主题
另外，Hexo有很多主题，大家可以挑选自己喜欢的主题配置上去。关于主题挑选可以参考下面这两个网站:

- [有哪些好看的Hexo主题](https://www.zhihu.com/question/24422335)
- [Hexo官网列出的主题](https://hexo.io/themes/)

我自己使用的是[Next](http://theme-next.iissnan.com/)主题.该主题已经支持了比较多的特性，大家可以参考官方文档去选择配置自己需要的特性。比如有 阅读计数，分享功能，评论功能，文章搜索功能等。


### 推广
如果只是自己记录自己看的话，那么可以忽略这步了。建站后有的同学希望能推广自己的博客，希望能被搜索引擎收录自己的网站。那么就需要做如下的步骤了。这些都是我在建站的时候遇到的问题，也是参考的别人的解决方案做的。下面给出步骤:
1. 绑定自己的域名，没有的话去整一个。参考[github pages+阿里云域名绑定搭建个人博客](http://www.cnblogs.com/olddoublemoon/p/6629398.html)
2. 添加百度和谷歌收录。参考[hexo提交搜索引擎（百度+谷歌）](http://www.cnblogs.com/tengj/p/5357879.html)
3. Hexo Next SEO 优化。 参考[Hexo NexT 主题SEO优化指南](http://www.jianshu.com/p/0d54a590b81a)
4. 解决百度蜘蛛无法抓取GitHub的页面导致无法收到到百度的问题。参考[百度无法爬取Github Pages静态网站解决方案](http://guochenglai.com/2016/09/26/baidu-crow-github-page/)