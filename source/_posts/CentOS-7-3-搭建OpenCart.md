---
title: CentOS 7.3 搭建OpenCart
seo_title: install-opencart-in-centos
date: 2017-07-19 20:24:01
tags: [OpenCart,CentOS]
categories: [PHP]

---
# 环境
- Centos 7.3 64-bit
- OpenCart 2.3.0.2

# 安装LAMP环境和OpenCart
- [How To Install OpenCart On CentOS 7 Linux](http://www.unixmen.com/install-opencart-centos-7-linux/)

- 配置支持SEO ，在OpenCart项目部署根目录下创建.htaccess文件,内容如下(需要在OpenCart后台打开SEO支持)
 <!-- more -->
  ```
  # 1.To use URL Alias you need to be running apache with mod_rewrite enabled.

  # 2. In your opencart directory rename htaccess.txt to .htaccess.

  # For any support issues please visit: http://www.opencart.com

  Options +FollowSymlinks

  # Prevent Directoy listing
  Options -Indexes

  # Prevent Direct Access to files
  <FilesMatch "(?i)((\.tpl|\.ini|\.log|(?<!robots)\.txt))">
   Require all denied
  ## For apache 2.2 and older, replace "Require all denied" with these two lines :
  # Order deny,allow
  # Deny from all
  </FilesMatch>

  # SEO URL Settings
  RewriteEngine On
  # If your opencart installation does not run on the main web folder make sure you folder it does run in ie. / becomes /shop/

  RewriteBase /
  ### rewrite all request to https
  RewriteCond %{SERVER_PORT} !^443$
  RewriteRule ^.*$ https://%{SERVER_NAME}%{REQUEST_URI} [L,R]
  ### rewrite all request to https

  RewriteRule ^sitemap.xml$ index.php?route=extension/feed/google_sitemap [L]
  RewriteRule ^googlebase.xml$ index.php?route=extension/feed/google_base [L]
  RewriteRule ^system/download/(.*) index.php?route=error/not_found [L]
  RewriteCond %{REQUEST_FILENAME} !-f
  RewriteCond %{REQUEST_FILENAME} !-d
  RewriteCond %{REQUEST_URI} !.*\.(ico|gif|jpg|jpeg|png|js|css)
  RewriteRule ^([^?]*) index.php?_route_=$1 [L,QSA]

  ### Additional Settings that may need to be enabled for some servers
  ### Uncomment the commands by removing the # sign in front of it.
  ### If you get an "Internal Server Error 500" after enabling any of the following settings, restore the # as this means your host doesn't allow that.

  # 1. If your cart only allows you to add one item at a time, it is possible register_globals is on. This may work to disable it:
  # php_flag register_globals off

  # 2. If your cart has magic quotes enabled, This may work to disable it:
  # php_flag magic_quotes_gpc Off

  # 3. Set max upload file size. Most hosts will limit this and not allow it to be overridden but you can try
  # php_value upload_max_filesize 999M

  # 4. set max post size. uncomment this line if you have a lot of product options or are getting errors where forms are not saving all fields
  # php_value post_max_size 999M

  # 5. set max time script can take. uncomment this line if you have a lot of product options or are getting errors where forms are not saving all fields
  # php_value max_execution_time 200

  # 6. set max time for input to be recieved. Uncomment this line if you have a lot of product options or are getting errors where forms are not saving all fields
  # php_value max_input_time 200

  # 7. disable open_basedir limitations
  # php_admin_value open_basedir none
  ```

- 配置支持https(需要在OpenCart后台打开https支持)

  - `yum install mod_ssl openssl`
  - 申请https支持证书(我自己是直接在阿里云上购买的免费的证书)
  - 将证书文件上传到服务器，并修改`/etc/httpd/conf.d/ssl.conf`文件,配置对应的证书文件(此处以阿里的说明为例子)
    ```
    # 添加 SSL 协议支持协议，去掉不安全的协议
    SSLProtocol all -SSLv2 -SSLv3
    # 修改加密套件如下
    SSLCipherSuite HIGH:!RC4:!MD5:!aNULL:!eNULL:!NULL:!DH:!EDH:!EXP:+MEDIUM
    SSLHonorCipherOrder on
    # 证书公钥配置
    SSLCertificateFile cert/public.pem
    # 证书私钥配置
    SSLCertificateKeyFile cert/xxxx.key
    # 证书链配置，如果该属性开头有 '#'字符，请删除掉
    SSLCertificateChainFile cert/chain.pem
    ```
  - 修改OpenCart项目下的`config.php`和`admin/config.php`文件

    - config.php
      ```
      // HTTPS
      define('HTTPS_SERVER', 'http://yourdomain/');

      改成

      // HTTPS
      define('HTTPS_SERVER', 'https://yourdomain/');

      ```

    - admin/config.php
      ```
      // HTTPS
      define('HTTPS_SERVER', 'http://yourdomain/admin/');
      define('HTTPS_CATALOG', 'http://yourdomain/');

      改成

      // HTTPS
      define('HTTPS_SERVER', 'https://yourdomain/admin/');
      define('HTTPS_CATALOG', 'https://yourdomain/');

      ```
   - 重启httpd `systemctl restart httpd`
