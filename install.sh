#!/bin/sh
# 作者: 晓哥
# 时间: 2020.4.12
# 描述: 自动化使用docker安装wordpress

if_error() {
	if [[ $? != 0 ]];then
		# echo $1 
		echo -e "\033[31m$1\033[0m"
		exit 1
	fi
}
# 创建两个软连接
NG_CONF_DIR=/nginx_conf
NG_WP_DIR=/wordpress

# docker volume 基目录
D_VOLUME_BASE_DIR=/var/lib/docker/volumes

# 匹配docker-compose中网络名称,nginx配置存储卷名称,博客站点存储卷名称
D_NETWORK=$(grep -A1 ^networks docker-compose.yml |tail -1|tr -d ": ")
D_NGINX_CONF=$(grep /etc/nginx/conf.d docker-compose.yml |awk -F "[ \":]*" '{print $3}')
D_WWW=$(grep ":/wordpress" docker-compose.yml |tail -1|tr -d "[ \- /\"]"|awk -F: '{print $1}')

pre_check(){
    start=$(date +%s)
    ping dl-cdn.alpinelinux.org -c 1
    stop=$(date +%s)
    if [[ $(($stop-$start)) > 1 ]];then
    	echo "ping dl-cdn.alpinelinux.org 耗时$(($stop-$start))s,延迟较大,下载有可能失败!"
    fi
    if [[ ! -f /etc/redhat-release ]];then
        echo -e "\033[31m暂不支持CentOS系列以外的系统...\033[0m"
        exit 1
    fi
    if [[ -d $NG_CONF_DIR ]];then echo "$NG_CONF_DIR已经存在,请检查或者删除后再此尝试...";exit 2;fi
    if [[ -d $NG_WP_DIR ]];then echo "$NG_WP_DIR已经存在,请检查或者删除后再此尝试...";exit 3;fi
}

docker_install() {
    if [[ $(which dockerd) != /usr/bin/dockerd ]];then
        # 安装yum管理工具
        yum install -y yum-utils 
        if_error "安装yum-utils失败,请尝试或者检查网络是否异常..."
        # 安装docker源
        yum-config-manager \
            --add-repo \
            https://download.docker.com/linux/centos/docker-ce.repo
        if_error "导入docker-ce.repo失败,请尝试或者检查网络是否异常..."
        # 安装docker
        yum install docker-ce docker-ce-cli containerd.io -y
        if_error "docker安装失败,请排查原因..."
        # 开机自启动并立即启动
        systemctl enable --now docker
        if_error "docker启动失败,请检查日志排查问题..."
        echo "配置阿里云docker镜像加速..."
# 使用阿里云镜像加速
cat >/etc/docker/daemon.json <<-'EOF'
{
    "registry-mirrors": ["https://xtkg63xe.mirror.aliyuncs.com"]
}
EOF
        # 重加载systemctl配置,重启docker
        systemctl daemon-reload
        systemctl restart docker
        if_error "docker重启失败,请排查原因..."
    fi
    if [[ $(which docker-compose) != /usr/local/bin/docker-compose  ]];then
        # 安装docker-compose
        wget https://github.com/docker/compose/releases/download/1.25.5/docker-compose-Linux-x86_64
        if_error "docker-compose下载安装失败,请检查网络..."
        mv docker-compose-Linux-x86_64 docker-compose
        install docker-compose /usr/local/bin/
        rm -f docker-compose
    fi
    if [[ $(docker ps|grep wp-php|wc -l) == 1 ]];then
        echo "wordpress 已经启动,如需重启请使用 docker-compose 命令."
        exit 2
    fi
}

download_wordpress(){
    if [[ -f $(ls wordpress*.tar.gz 2>/dev/null) ]];then
	echo "当前目录已经存在wordpress源码包.."
        return
    fi
    VERSION=$(curl -s https://cn.wordpress.org/download/releases/ \
        |grep -o "\"https://cn.wordpress.org/wordpress-.*-zh_CN.tar.gz\"" \
        |awk -F '-' '{print $2}' \
        |sort -n|tail -1)
    if [[ ! $VERSION ]];then
    	VERSION=5.4
    fi
    echo "准备下载wordpress-${VERSION}-zh_CN.tar.gz..."
    wget https://cn.wordpress.org/wordpress-${VERSION}-zh_CN.tar.gz
    if [[ $? != 0 ]];then
    	echo -e "\033[34m网络故障,无法下载,尝试换源下载5.4版本..\033[0m"
	wget https://github.com/pi-v/wordpress-install/releases/download/v2/wordpress-5.4-zh_CN.tar.gz
	if [[ $? != 0 ]];then
	    echo -e "\033[31m依旧下载失败,请手动将wordpress-${VERSION}-zh_CN.tar.gz放在当前目录中,然后重新执行...\033[0m"
	    exit 2
	fi
    fi
}

nginx_ops() {
    nginx_conf_dir=${D_VOLUME_BASE_DIR}/${D_NETWORK}_${D_NGINX_CONF}/_data/
    # 修改nginx配置文件
    rm -f ${nginx_conf_dir}/default.conf
    cp wordpress.conf $nginx_conf_dir
    # 创建软连接
    ln -s $nginx_conf_dir $NG_CONF_DIR 
}

php_check() {
    echo "暂停3s,启动php中..."
    sleep 3
    # 重启nginx
    docker restart wp-nginx
    # 添加 phpinfo 文件测试
    echo "<?php phpinfo();?>" >${D_VOLUME_BASE_DIR}/${D_NETWORK}_${D_WWW}/_data/phpinfo.php
    isok=$(curl -s http://127.0.0.1/phpinfo.php|grep -Eo "PHP Version"|wc -l)
    if [[ $isok == 0 ]];then
        echo "php not ok ..."
        exit 1
    fi
}

wordpress_ops() {
    wp_dir=${D_VOLUME_BASE_DIR}/${D_NETWORK}_${D_WWW}/_data/
    # 部署wordpress到docker站点目录中
    tar xf wordpress*.tar.gz
    mv wordpress/* $wp_dir
    # 创建软连接
    ln -s $wp_dir $NG_WP_DIR
}

out_message() {
    # 输出结果
    ip=$(curl ifconfig.me)
    password=$(grep PASSWORD docker-compose.yml |awk '{print $2}'|sed "s#\"##g")

    echo -e "\033[33mnginx配置目录: $NG_CONF_DIR wordpress站点目录: $NG_WP_DIR\033[0m"
    echo -e "\033[33mmysql管理地址: http://$ip:8080\033[0m"
    echo -e "\033[33mmysql root用户密码: $password\033[0m"
    echo -e "\033[33mwordpress访问: http://$ip\033[0m"
}

# 安装前环境检查
pre_check
# docker和docker-compose 安装
docker_install
# wordpress 源码包下载
download_wordpress
# 启动 docker-compose 部署wordpress
docker-compose up -d
# nginx相关操作
nginx_ops
# php是否启动检查
php_check
# wordpress部署操作
wordpress_ops
# 信息输出
out_message
