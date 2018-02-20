---
layout: post
title: Nginx特例场景配置
date: 2018-02-05 20:30:47
tags:
  - Nginx配置
  - Nginx over Squid
  - Nginx防火墙穿透
  - HTTPS代理HTTP资源
categories:
  - 运维管理
---

## Nginx代理第三方http站点静态资源文件

**关键字**：
- HTTPS反向代理HTTP静态资源
- 单页面Markdown编写与渲染方案
- Nginx反向代理重定向拦截处理

这几天为部门搭建好了Maven仓库，为了便于指导部门同事能够准确配置并启用私有仓库，然后就打算写一份使用说明文档。

我不太喜欢写Word，也好几年几乎没用过了，一般都是直接写在部门的[Wiki](https://www.mediawiki.org/)系统上。不过，一份简单的文档写到Wiki上又不太方便查阅，于是找了找可以在单个HTML里写[Markdown](https://en.wikipedia.org/wiki/Markdown)并直接渲染展示的方案。

很快我就找到了[Strapdown Zeta](https://github.com/chaitin/strapdown-zeta)，其对Mardown的支持较为全面，并且使用很简单，还提供多套主题可自由切换。需要提到的是该库为[Strapdown](https://github.com/arturadib/strapdown)的衍生与改进版本，而`Strapdown`已经很长时间未更新了，选择`Strapdown Zeta`也是看重其活跃度。

<!--more-->

在`Strapdown Zeta`的支持下仅需在`<xmp></xmp>`标签中编写Markdown并在最后引入 http://cdn.ztx.io/strapdown/strapdown.min.js 脚本即可。可惜的是，作者提供的该站点并未启用HTTPS，而我们在[Let's Encrypt](https://letsencrypt.org/)的帮助下已经对部门的所有站点启用了HTTPS。这样，若在页面中引用非HTTPS资源，浏览器默认将阻止该资源的下载。

显然，这里不能直接在页面中引入该脚本，但是我也不愿再在站点上部署除使用文档之外的其他文件，就仅仅一个HTML文件即可，css什么的都不要有。

百般思索后，突然想到[Internet Archive](https://archive.org/)可以代理访问其他站点的页面，那我也可以专门为第三方静态资源搭建一个代理服务，该站点自身是HTTPS的，其在服务端获取到目标资源再返回给浏览器，这样该资源也就走的是HTTPS，既不用在服务器上存储这些资源，也可以自由代理其他第三方资源，而且不用管目标是不是HTTPS，甚至还可以代理一些无法访问到的资源。简单、经济、又实惠！:)

于是动手！这里假设代理站点为`https://static.example.com`，并构造代理链接为`https://static.example.com/*/<target url>`形式，这种结构可以方便Nginx做Location匹配，同时在使用和修改上均十分简单，我们不用改变目标资源的URL地址。

这里直接放出完整的配置：
```nginx
server {
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name static.example.com;

    include /etc/nginx/vhost.d/static.example.com/01_ssl.conf;

    # https://static.example.com/*/http://others.com/asset.js -> http://others.com/asset.js
    ## https://www.mediasuite.co.nz/blog/proxying-s3-downloads-nginx/
    location ~* ^/\*/(http[s]?):?/(.*?)/(.*)$ {
        # Note: Remove the directive 'internal;' to accept the external requests,
        #       otherwise it will return 404 for the external requests.
        #       See http://nginx.org/en/docs/http/ngx_http_core_module.html#internal
        set $backend_protocol   $1;
        set $backend_host       $2;
        set $backend_path       $3;
        set $backend_uri        $backend_host/$backend_path$is_args$args;
        set $backend_url        $backend_protocol://$backend_uri;

        # Headers for the remote server, unset Authorization and Cookie for security reasons.
        proxy_set_header Host $backend_host;
        proxy_set_header Authorization '';
        proxy_set_header Cookie '';

        # Stops the local disk from being written to (just forwards data through)
        proxy_max_temp_file_size 0;

        proxy_pass $backend_url;

        proxy_intercept_errors on;
        error_page 301 302 307 = @handle_backend_redirect;
    }

    # Nginx Embedded Variables: http://nginx.org/en/docs/varindex.html
    location @handle_backend_redirect {
        return 302 $scheme://$host/*/$upstream_http_location;
    }
}
```

该配置参考的是[Using NGINX’s X-Accel with Remote URLs](https://www.mediasuite.co.nz/blog/proxying-s3-downloads-nginx/)。这里没有做特别的改动，主要是针对我们的实际需求做了些调整：
- 去掉了`internal;`指令，该指令是限制仅能在Nginx内部做该代理请求，而我们是需要外部直接获取到目标资源的，因此，需要去掉该指令，否则，外部访问时将始终为`404`；
- 针对目标URL地址存在重定向问题，在`@handle_backend_redirect`中，我又将重定向地址（其对应变量`$upstream_http_location`）再次进行代理，这样无论目标跳转多少次，代理站点均能获取到最终的返回内容，而不是在浏览器中又突然跳到另一个HTTP链接了；

最后提醒大家一点是，在网络中对安全要时刻保持警惕，尽可能降低敏感数据泄漏的风险，因此，这里切忌不要将客户端的`Authorization`和`Cookie`转发到目标站点了。

## Nginx通过Squid穿透防火墙

**关键字**：
- Nginx http_proxy：`http_proxy`为Linux中配置启用正向代理的环境变量，很多命令可识别该变量并通过所设定的代理地址请求目标资源
- Nginx防火墙穿透
- Nginx over Squid
- Squid behind Nginx
- Nginx bypass firewall via Squid

在前面提到，为了将HTTP请求转换为HTTPS请求，我专门搭建了个静态文件代理站点。刚开始访问还很正常，可后来便发现公司网关阻止了服务器对外部网站的访问，导致编写的文档无法渲染。

因此，我便考虑在Nginx服务端通过Squid（其他代理服务也可）再做一次代理以穿透公司的防火墙，确保静态资源的代理不再出现问题。

在多次尝试以及搜索网络资料后终于发现[How to make an existing caching Nginx proxy use another proxy to bypass a firewall?](https://serverfault.com/questions/583743/how-to-make-an-existing-caching-nginx-proxy-use-another-proxy-to-bypass-a-firewa#683955)所提到的实现方法。

在原配置的基础上综合改进后，得到新的配置内容如下：
```nginx
server {
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name static.example.com;

    include /etc/nginx/vhost.d/static.example.com/01_ssl.conf;

    # https://static.example.com/*/http://others.com/asset.js -> http://others.com/asset.js
    ## https://www.mediasuite.co.nz/blog/proxying-s3-downloads-nginx/
    location ~* ^/\*/(http[s]?):?/(.*?)/(.*)$ {
        # Note: Remove the directive 'internal;' to accept the external requests,
        #       otherwise it will return 404 for the external requests.
        #       See http://nginx.org/en/docs/http/ngx_http_core_module.html#internal
        set $backend_protocol   $1;
        set $backend_host       $2;
        set $backend_path       $3;
        set $backend_uri        $backend_host/$backend_path$is_args$args;
        set $backend_url        $backend_protocol://$backend_uri;

        # Headers for the remote server, unset Authorization and Cookie for security reasons.
        proxy_set_header Host $backend_host;
        proxy_set_header Authorization '';
        proxy_set_header Cookie '';

        # Stops the local disk from being written to (just forwards data through)
        proxy_max_temp_file_size 0;

        # Forward the target to the squid proxy
        ## https://serverfault.com/questions/583743/how-to-make-an-existing-caching-nginx-proxy-use-another-proxy-to-bypass-a-firewa#683955
        ## Hide the reponse header to protect the backend proxy
        ### http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_hide_header
        proxy_hide_header Via;
        proxy_hide_header X-Cache;
        proxy_hide_header X-Cache-Hits;
        proxy_hide_header X-Cache-Lookup;
        proxy_hide_header X-Fastly-Request-ID;
        proxy_hide_header X-Served-By;
        proxy_hide_header X-Timer;
        rewrite ^(.*)$      "://$backend_uri"           break;
        rewrite ^(.*)$      "$backend_protocol$1"       break;
        proxy_pass http://<squid ip>:3128;

        # Proxy to the target directly
        #proxy_pass $backend_url;

        proxy_intercept_errors on;
        error_page 301 302 307 = @handle_backend_redirect;
    }

    # Nginx Embedded Variables: http://nginx.org/en/docs/varindex.html
    location @handle_backend_redirect {
        return 302 $scheme://$host/*/$upstream_http_location;
    }
}
```

这里需要特别注意的是：
- 这里做了两次`rewrite`是为了确保能够准确将目标URL地址附加到Squid的代理地址中以构成`http://<squid ip>:3128/<target url>`形式，同时，规避了因在[rewrite](http://nginx.org/en/docs/http/ngx_http_rewrite_module.html#rewrite)的替换字符串中包含`http://`、`https://`或`$scheme`而导致重定向的问题；
- 同样为了安全考虑，这里隐藏了Squid的几个响应头，避免客户端得到Squid的真实IP地址而产生潜在的攻击风险；

## Nginx反向代理Nexus3的不同类型仓库

**关键字**：
- Nginx反向代理
- Nexus3不同类型仓库映射独立域名

[Nexus3](https://help.sonatype.com/display/NXRM3)同时支持多种类型的资源存储，比如，Docker镜像、Maven依赖包、NPM等，
不过，不同类型的资源访问方式和使用惯例是不一致的，因此，为每类资源提供符合惯例的仓库地址，再将请求转发到Nexus3仓库，对使用者而言将更加有好。

为此，本例针对Docker、Maven和NPM仓库分别给出Nginx的反向代理配置。

首先确定几个子站点的域名为如下形式：
- `https://repo.example.com`：Nexus3服务访问地址
- `https://mvn.example.com`：Maven仓库访问地址
- `https://npm.example.com`：NPM仓库地址
- `https://dcr.example.com`：Docker镜像访问地址

### `https://repo.example.com`的反向代理配置

```nginx
server {
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name repo.example.com;

    include /etc/nginx/vhost.d/repo.example.com/01_ssl.conf;

    proxy_cache off;
    location / {
        # Avoid to get address resolve error when starting
        set $nexus3 http://<nexus3 ip>:<nexus3 web port>;
        proxy_pass $nexus3;
    }
}
```

对`https://repo.example.com`的配置很简单，直接将请求反向代理到Nexus3的Web接口即可。这里仅需要注意以下几点：
- 为了避免Nginx缓存导致资源的元数据（`metadata`）不能及时更新，所以，这里启用了`proxy_cache off;`以关闭代理缓存。当然，也可以根据实际情况仅对某些类的文件关闭缓存
- Nginx在解析配置时会对`proxy_pass`的目标域名地址进行解析，若是解析失败则会导致Nginx启动异常，因此，这里采用变量方式将解析延迟到需要时，从而避免启动失败

### `https://mvn.example.com`的反向代理配置

需要科普一下的是，在Nexus3中访问某个仓库内的资源的URL结构为`http://<nexus3>/#browse/browse/components:<repo>/`，访问某个资源的URL结构为`http://<nexus3>/repository/<repo>/<asset path>`。其中，`<repo>`为仓库名称，所有类型的仓库均会有`hosted`（私有存储）、`proxy`（代理外部仓库）和`group`（组合同类仓库）三种模式。

为了规范内部和外部访问并便于进行权限控制（如，外部帐号不允许访问`hosted`中的源码等），这里创建了以下几个仓库：
- `maven-hosted-releases`：存储内部产品发布包。部署发布包时，向该仓库发送更新请求
- `maven-hosted-snapshots`：存储内部产品开发快照包。部署快照包时，向该仓库发送更新请求
- `maven-hosted`：`maven-hosted-*`的组合仓库。在Maven客户端更新依赖时，从该仓库下载内部产品的发布包或快照包
- `maven-<3rd repo url>`：对第三方仓库的代理仓库，`<3rd repo url>`为站点域名，比如，`maven-apache.org`。也可以按其他规范命名，只要能友好区分不同仓库即可
- `maven-public`：所有`maven-<3rd repo url>`的组合仓库。用于统一下载第三方的依赖包

然后，我们期望在访问以下URL链接时，能够将请求转发到对应的资源上：
- `GET https://mvn.example.com/public/<asset>` -> `https://repo.example.com/repository/maven-public/<asset>`
- `GET https://mvn.example.com/hosted/<asset>` -> `https://repo.example.com/repository/maven-hosted/<asset>`
- `GET https://mvn.example.com/releases/<asset>` -> `https://repo.example.com/repository/maven-hosted/<asset>`
- `GET https://mvn.example.com/snapshots/<asset>` -> `https://repo.example.com/repository/maven-hosted/<asset>`
- `POST https://mvn.example.com/releases/<asset>` -> `https://repo.example.com/repository/maven-hosted-releases/<asset>`
- `POST https://mvn.example.com/snapshots/<asset>` -> `https://repo.example.com/repository/maven-hosted-snapshots/<asset>`

根据以上规范和需求，`https://mvn.example.com`的最终配置如下：

```nginx
server {
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name mvn.example.com;

    include /etc/nginx/vhost.d/mvn.example.com/01_ssl.conf;

    # Redirect to the maven repository (named as 'maven-public') of Nexus3
    location = / {
        return 302 $scheme://repo.example.com/#browse/browse/components:maven-public/;
    }
    # Redirect to the target asset of Nexus3
    location ~* ^/repository/maven-.+$ {
        return 301 $scheme://repo.example.com$request_uri;
    }

    # Disable cache of assets
    proxy_cache            off;
    proxy_read_timeout     300;
    proxy_connect_timeout  300;

    location / {
        set $nexus3 http://<nexus3 ip>:<nexus3 web port>;

        # NOTE: rewrite and proxy_pass should be put in the same block
        ## http://nginx.org/en/docs/http/ngx_http_rewrite_module.html#rewrite
        # web browse or `mvn compile`
        if ($request_method ~* "^GET|HEAD$") {
            rewrite ^/public/(.*)           /repository/maven-public/$1    break;
            rewrite ^/hosted/(.*)           /repository/maven-hosted/$1    break;
            rewrite ^/releases/(.*)         /repository/maven-hosted/$1    break;
            rewrite ^/snapshots/(.*)        /repository/maven-hosted/$1    break;
            proxy_pass      $nexus3;
            break;
        }

        # `mvn deploy`
        if ($request_method ~* "^POST|PUT$") {
            rewrite ^/(releases|snapshots)/(.*)              /repository/maven-hosted-$1/$2   break;
            proxy_pass      $nexus3;
            break;
        }
    }
}
```

这里需要注意以下几点：
- 在前两个`location`匹配后均跳转到`https://repo.example.com`，因为，这两个地址的请求可认为只能是从浏览器发出的，直接跳转到Nexus3可让访问者了解我们使用的是Nexus3系统，从而尽快熟悉该系统，完全没有必要将Nexus3代理到`https://mvn.example.com`域名下
- `return 301`代表固定跳转，浏览器后续访问相同URL时将直接跳转到指定的目标，而不会再向服务器发送请求；而`return 302`为临时跳转，浏览器的后续访问依然会向服务器发送请求。对`= /`做临时跳转是因为我们可能会在该URL下放些说明文档之类的页面，如果做固定跳转，那么若后续支持该需求则只能在客户端清空浏览器`Cookie`后方能生效，对使用者会造成一定困扰
- 看过[Maven代码](https://github.com/apache/maven)可以发现其使用的[HttpClient](https://hc.apache.org/httpcomponents-client-ga/)库向仓库发送HTTP请求，所以，只需要对`$request_method`做匹配，将读请求转发到`maven-pulic`和`maven-hosted`两个组合仓库中，而将写请求转发到`maven-hosted-*`仓库即可

剩下的就是调整Maven `settings.xml`。对普通的仅做依赖下载更新的配置为（**仅列出主要内容，请按实际需求修改**）：
```xml
<!-- https://maven.apache.org/settings.html -->
<settings>
    <servers>
        <server>
            <!-- Associated with <repository/> and <pluginRepository/> -->
            <id>your-repo-public</id>
            <username></username>
            <password></password>
        </server>
        <server>
            <id>your-repo-hosted</id>
            <username></username>
            <password></password>
        </server>
    </servers>
    <profiles>
        <profile>
            <id>your-repo</id>
            <repositories>
                <repository>
                    <id>your-repo-public</id>
                    <url>https://mvn.example.com/public/</url>
                    <releases><enabled>true</enabled></releases>
                    <snapshots><enabled>true</enabled></snapshots>
                </repository>
                <repository>
                    <id>your-repo-hosted</id>
                    <url>https://mvn.example.com/hosted/</url>
                    <releases><enabled>true</enabled></releases>
                    <snapshots><enabled>true</enabled></snapshots>
                </repository>
            </repositories>
            <pluginRepositories>
                <pluginRepository>
                    <id>your-repo-public</id>
                    <url>https://mvn.example.com/public/</url>
                    <releases><enabled>true</enabled></releases>
                    <snapshots><enabled>true</enabled></snapshots>
                </pluginRepository>
            </pluginRepositories>
        </profile>
    </profiles>
    <activeProfiles>
        <activeProfile>your-repo</activeProfile>
    </activeProfiles>
</settings>
```

而对需要向仓库部署包的配置则为（**仅列出主要内容，请按实际需求修改**）：
```xml
<!-- https://maven.apache.org/settings.html -->
<settings>
    <servers>
        <server>
            <!-- Associated with <repository/> and <pluginRepository/> -->
            <id>public</id>
            <username></username>
            <password></password>
        </server>
        <server>
            <id>releases</id>
            <username></username>
            <password></password>
        </server>
        <server>
            <id>snapshots</id>
            <username></username>
            <password></password>
        </server>
        <server>
            <id>thirdparty</id>
            <username></username>
            <password></password>
        </server>
    </servers>
    <profiles>
        <profile>
            <id>your-repo</id>
            <repositories>
                <repository>
                    <id>public</id>
                    <url>https://mvn.example.com/public/</url>
                    <releases><enabled>true</enabled></releases>
                    <snapshots><enabled>true</enabled></snapshots>
                </repository>
                <repository>
                    <id>releases</id>
                    <url>https://mvn.example.com/releases/</url>
                    <releases><enabled>true</enabled></releases>
                    <snapshots><enabled>false</enabled></snapshots>
                </repository>
                <repository>
                    <id>snapshots</id>
                    <url>https://mvn.example.com/snapshots/</url>
                    <releases><enabled>false</enabled></releases>
                    <snapshots><enabled>true</enabled></snapshots>
                </repository>
                <repository>
                    <id>thirdparty</id>
                    <url>https://mvn.example.com/thirdparty/</url>
                    <releases><enabled>true</enabled></releases>
                    <snapshots><enabled>true</enabled></snapshots>
                </repository>
            </repositories>
            <pluginRepositories>
                <pluginRepository>
                    <id>public</id>
                    <url>https://mvn.example.com/public/</url>
                    <releases><enabled>true</enabled></releases>
                    <snapshots><enabled>true</enabled></snapshots>
                </pluginRepository>
            </pluginRepositories>
        </profile>
    </profiles>
    <activeProfiles>
        <activeProfile>your-repo</activeProfile>
    </activeProfiles>
</settings>
```

注意，Maven在更新时是按照`settings.xml`中定义的仓库顺序依次查找依赖直到内置的[central](https://repo.maven.apache.org/maven2)仓库，若在某个仓库中找到依赖则停止查找。因此，需要注意调整仓库的位置以避免因依赖同名而导致下载的内容与预期的不同。

### `https://npm.example.com`的反向代理配置

`https://npm.example.com`与`https://mvn.example.com`的规划和注意事项基本一致，只是`npm-hosted`仓库直接使用`hosted`模式，因为NPM依赖包没有快照版本，而`npm-public`仓库依然为`group`模式，用于组合多个第三方仓库。

以下为对`https://npm.example.com`的完整配置：

```nginx
server {
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name npm.example.com;

    include /etc/nginx/vhost.d/npm.example.com/01_ssl.conf;

    # Redirect to the npm repository (named as 'npm-public') of Nexus3
    location = / {
        return 302 $scheme://repo.example.com/#browse/browse/components:npm-public/;
    }
    # Redirect to the target asset of Nexus3
    location ~* ^/repository/npm-.+$ {
        return 301 $scheme://repo.example.com$request_uri;
    }


    # Disable cache of assets
    proxy_cache            off;
    proxy_read_timeout     60;
    proxy_connect_timeout  60;

    location / {
        set $nexus3 http://<nexus3 ip>:<nexus3 web port>;

        # NOTE: rewrite and proxy_pass should be put in the same block
        ## http://nginx.org/en/docs/http/ngx_http_rewrite_module.html#rewrite
        # web browse or `npm install`
        if ($request_method ~* "^GET$") {
            rewrite ^/(.+)                      /repository/npm-public/$1      break;
            proxy_pass      $nexus3;
            break;
        }

        # `npm publish`
        if ($request_method ~* "^PUT|DELETE$") {
            rewrite ^/(.+)          /repository/npm-hosted/$1   break;
            proxy_pass      $nexus3;
            break;
        }
    }
}
```

### `https://dcr.example.com`的反向代理配置

在Nexus3中，Docker类型的仓库需要使用不同的端口进行访问，创建仓库时需要为仓库[自行设定](http://www.sonatype.org/nexus/2016/06/29/using-nexus-3-as-a-private-docker-registry/)一个HTTP端口号，然后再通过Nginx将读写请求转发到不同的端口上。

这里创建一个`hosted`模式的仓库`docker-hosted`用于`docker push`镜像，创建一个`group`模式的仓库`docker-public`用于组合多个第三方镜像仓库。

最终，针对`https://dcr.example.com`的Nginx配置如下：

```nginx
server {
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name dcr.example.com;

    include /etc/nginx/vhost.d/dcr.example.com/01_ssl.conf;

    # Disable cache of assets
    proxy_cache            off;
    proxy_read_timeout     600;
    proxy_connect_timeout  600;

    location / {
        if ($http_user_agent !~* "^docker/.+$") {
            return 301 $scheme://repo.example.com/#browse/browse/components:docker-public$request_uri;
        }

        set $nexus3 http://<nexus3 ip>;

        # docker pull dcr.example.com/xx-xx
        set $repo_url $nexus3:<docker-public port>;

        # https://github.com/moby/moby/blob/7061b0f748c29ffd1e6852cdc5dd11f90840eb1c/daemon/logger/awslogs/cloudwatchlogs_test.go#L71
        # https://github.com/moby/moby/blob/master/client/image_pull.go
        # https://github.com/moby/moby/blob/master/client/image_push.go

        # NOTE: rewrite and proxy_pass should be put in the same block
        ## http://nginx.org/en/docs/http/ngx_http_rewrite_module.html#rewrite
        # docker push dcr.example.com/xx-xx
        if ($request_method ~* "^HEAD|POST|PUT|DELETE|PATCH$") {
            set $repo_url $nexus3:<docker-hosted port>;
        }

        proxy_pass $repo_url;
    }
}
```

这里同样需注意以下几个问题：
- Docker发送的HTTP请求中`User Agent`包含`docker`字符串，因此，如果`$http_user_agent`中没有这个字符串，则视为浏览器访问，直接跳转到`https://repo.example.com`
- 从Docker的源码中可以发现`HTTP Method`为`HEAD`、`POST`、`PUT`、`DELETE`、`PATCH`均与镜像变更（新增、删除、打标签、更新等）有关，因此，需要将这些请求均转发到`docker-hosted`仓库
