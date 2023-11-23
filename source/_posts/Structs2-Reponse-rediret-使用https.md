---
title: Structs2 Reponse rediret 使用https
seo_title: structs2-redirect-with-https
date: 2016-11-20 12:47:14
tags: [Struts]
categories: [工作记录]

---

### 问题:
**Structs2 action中的redirect只支持Http**,当应用部署在Https环境下时。会报错:
> Mixed Content: The page at 'https://managertest.efun.com/userlogin.mainWindow.shtml' was loaded over HTTPS, but requested an insecure script 'http://manager.efun.com/js/upload.js'. This request has been blocked; the content must be served over HTTPS.


```xml
<action name="serviceManagerAction_*" class="serviceManagerAction" method="{1}">
			<result name="listPage">/serviceList.jsp</result>
			<result name="updateUI">
				/serviceList.jsp
			</result>
			<result name="update" type="redirect">
				serviceManagerAction_search.shtml?searchGame=${gid}&amp;beginTime=${beginTime}&amp;endTime=${endTime}&amp;area=${area}&amp;gameCode=${gameCode}
			</result>
			<result name="delete" type="redirect">
				serviceManagerAction_search.shtml?searchGame=${gid}&amp;beginTime=${beginTime}&amp;endTime=${endTime}&amp;area=${area}
			</result>
			<result name="save" type="redirect">
				serviceManagerAction_search.shtml?searchGame=${gid}&amp;beginTime=${beginTime}&amp;endTime=${endTime}&amp;area=${area}&amp;gameCode=${gameCode}
			</result>
</action>
```

<!-- more -->

**解决过程如下:**

1. 查询解决方案,可以使用struts2-ssl-plugin插件,[使用说明](https://code.google.com/archive/p/struts2-ssl-plugin/wikis/HowToUse.wiki)
于是按照文档部署,测试时发现服务器不断重定向请求，问题处理失败。日志如下：
> [2017-01-16 17:09:34.326] {http-192.168.10.39:8040-1$1934196892} Going to SSL mode, redirecting to https://managertest.efun.com:443/userlogin.mainWindow.shtml

2. 之后发现服务器中使用https是通过ngnix根据域名的规则将所有请求转为https的。重定向的问题可能和这个有关。但是具体原因不清楚。 既然是通过ngnix来转https的。那么考虑也通过Ngnix将应用的Response的redirect也转换为Htpps来解决问题

**解决方案参考:**[How do I rewrite URLs in a proxy response in NGINX](http://stackoverflow.com/questions/32542282/how-do-i-rewrite-urls-in-a-proxy-response-in-nginx)