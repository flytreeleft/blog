---
layout: post
title: Nginx特例场景配置
date: 2018-02-05 20:30:47
tags:
  - Nginx配置
categories:
  - 运维管理
---

## Nginx代理第三方http站点静态资源文件

这几天为部门搭建好了Maven仓库，为了便于指导部门同事能够准确配置并启用私有仓库，然后就打算写一份使用说明文档。

我不太喜欢写Word，也好几年几乎没用过了，一般都是直接写在部门的[Wiki](https://www.mediawiki.org/)系统上。不过，一份简单的文档写到Wiki上又不太方便查阅，于是找了找可以在单个HTML里写[Markdown](https://en.wikipedia.org/wiki/Markdown)并直接渲染展示的方案。

很快我就找到了[Strapdown Zeta](https://github.com/chaitin/strapdown-zeta)，其对Mardown的支持较为全面，并且使用很简单，还提供多套主题可自由切换。需要提到的是该库为[Strapdown](https://github.com/arturadib/strapdown)的衍生与改进版本，而`Strapdown`已经很长时间未更新了，选择`Strapdown Zeta`也是看重其活跃度。

<!--more-->

在`Strapdown Zeta`的支持下仅需在`<xmp></xmp>`标签中编写Markdown并在最后引入 http://cdn.ztx.io/strapdown/strapdown.min.js 脚本即可。可惜的是，作者提供的该站点并未启用HTTPS，而我们在[Let's Encrypt](https://letsencrypt.org/)的帮助下已经对部门的所有站点启用了HTTPS。这样，若在页面中引用非HTTPS资源，浏览器默认将阻止该资源的下载。

显然，这里不能直接在页面中引入该脚本，但是我也不愿再在站点上部署除使用文档之外的其他文件，就仅仅一个HTML文件即可，css什么的都不要有。

百般思索后，突然想到[Internet Archive](https://archive.org/)可以代理访问其他站点的页面，那我也可以专门为第三方静态资源搭建一个代理服务，该站点自身是HTTPS的，其在服务端获取到目标资源再返回给浏览器，这样该资源也就走的是HTTPS，既不用在服务器上存储这些资源，也可以自由代理其他第三方资源，而且不用管目标是不是HTTPS，甚至还可以代理一些无法访问到的资源。简单、经济、又实惠！:)

于是动手！这里假设代理站点为`https://static.example.com`，并构造代理链接为`https://static.example.com/*/<target url>`形式，这种结构可以方便Nginx做Location匹配，同时在使用和修改上均十分简单，我们不用改变目标资源的URL地址。

这里直接放出完整的配置：
```conf
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

## Nginx通过Squid穿透防火墙（Nginx bypass firewall via Squid）

**Google关键字**：`nginx http_proxy`。其中，`http_proxy`为Linux中配置启用正向代理的环境变量，很多命令可识别该变量并通过所设定的代理地址请求目标资源。

在前面提到，为了将HTTP请求转换为HTTPS请求，我专门搭建了个静态文件代理站点。刚开始访问还很正常，可后来便发现公司网关阻止了服务器对外部网站的访问，导致编写的文档无法渲染。

因此，我便考虑在Nginx服务端通过Squid（其他代理服务也可）再做一次代理以穿透公司的防火墙，确保静态资源的代理不再出现问题。

在多次尝试以及搜索网络资料后终于发现[How to make an existing caching Nginx proxy use another proxy to bypass a firewall?](https://serverfault.com/questions/583743/how-to-make-an-existing-caching-nginx-proxy-use-another-proxy-to-bypass-a-firewa#683955)所提到的实现方法。

在原配置的基础上综合改进后，得到新的配置内容如下：
```conf
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
- 这里做了两次`rewrite`是为了确保能够准确将目标URL地址附加到Squid的代理地址中以构成`http://<squid ip>:3128/<target url>`形式，同时，规避了因在[`rewrite`](http://nginx.org/en/docs/http/ngx_http_rewrite_module.html#rewrite)的替换字符串中包含`http://`、`https://`或`$scheme`而导致重定向的问题；
- 同样为了安全考虑，这里隐藏了Squid的几个响应头，避免客户端得到Squid的真实IP地址而产生潜在的攻击风险；
