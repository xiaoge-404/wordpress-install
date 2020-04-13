# wordpress-install
使用脚本一键安装docker环境,部署wordpress最新版博客程序!

## 快速安装方式
```sh
curl -s https://pi-v.github.io/sh/wordpress_quick_install.html|bash
```
使用香港云服务器测试,5分钟配置好wordpress网站,非常适合懒人使用

默认mysql为8.0版本,root密码为`Word press123.`

mysql的配置文件使用的docker volume 方式而不是直接挂在目录
volumes目录地址为:/var/lib/docker/volumes

```yaml
mysql:
    image: mysql:8.0.19
    networks:
      - db
    command: --default-authentication-plugin=mysql_native_password
    environment:
      MYSQL_ROOT_PASSWORD: "Wordpress."
    volumes:
      - "conf:/etc/mysql/conf.d"
      - "data:/var/lib/mysql"
```

mysql 管理使用的`adminer:latest` 镜像,非常强大好用!

php环境使用以 php:7.4-fpm-alpine为基础 

添加了 gd gettext mysqli这三个扩展,用于wordpress程序的mysql链接和图片处理
更多扩展添加需求修改Dockerfile文件,增加所需要的扩展即可

可以直接添加的扩展,请看:[php官方镜像扩展安装工具](https://hub.docker.com/r/mlocati/php-extension-installer)

nginx配置仅供参考,根据自己需求进行修改
