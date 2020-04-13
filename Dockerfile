FROM php:7.4-fpm-alpine
# 下面的三个是网络代理配置,扩展库要从国外服务器下载安装,自己想办法搞,我的不能乱传
# ENV http_proxy http://172.17.0.2:8118
# ENV https_proxy http://172.17.0.2:8118
# ENV no_proxy 127.0.0.1,/var/run/docker.sock

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/bin/

RUN install-php-extensions gd gettext mysqli && \
    sed -i "s#www-data#root#g" /usr/local/etc/php-fpm.d/www.conf

EXPOSE 9000

CMD ["php-fpm","-R"]
