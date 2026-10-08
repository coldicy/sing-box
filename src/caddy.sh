caddy_config() {
    is_caddy_site_file=$is_caddy_conf/${host}.conf
    
    # 【新增】定义本地伪装网页的存放目录
    local masquerade_dir="/var/www/html/masquerade"
    
    case $1 in
    new)
        mkdir -p $is_caddy_dir $is_caddy_dir/sites $is_caddy_conf $masquerade_dir
        
        # 【新增】如果伪装目录是空的，自动生成一个默认的 "Hello World" 伪装页
        if [[ ! -f "$masquerade_dir/index.html" ]]; then
            cat >$masquerade_dir/index.html <<-EOF
<!DOCTYPE html>
<html>
<head><title>Welcome</title></head>
<body>
    <h1>It works!</h1>
    <p>This is a default masquerade page.</p>
</body>
</html>
EOF
        fi

        cat >$is_caddyfile <<-EOF
# don't edit this file #
# for more info, see https://233boy.com/$is_core/caddy-auto-tls/
# 不要编辑这个文件 #
# 更多相关请阅读此文章: https://233boy.com/$is_core/caddy-auto-tls/
# https://caddyserver.com/docs/caddyfile/options
{
  admin off
  http_port $is_http_port
  https_port $is_https_port
  auto_https off  # 【新增】全局禁用自动 HTTPS 和证书申请
}
import $is_caddy_conf/*.conf
import $is_caddy_dir/sites/*.conf
EOF
        ;;
    *ws* | *http*)
        cat >${is_caddy_site_file} <<<"
${host}:${is_https_port} {
    # 【新增】强制指定本地证书路径
    tls /etc/ssl/fullchain.pem /etc/ssl/private.key

    # 1. 匹配节点专属路径，转发给 sing-box
    handle ${path} {
        reverse_proxy 127.0.0.1:${port}
    }

    # 2. 【新增】匹配其他所有请求，展示本地伪装网页
    handle {
        root * ${masquerade_dir}
        file_server
    }

    import ${is_caddy_site_file}.add
}"
        ;;
    *h2*)
        cat >${is_caddy_site_file} <<<"
${host}:${is_https_port} {
    # 【新增】强制指定本地证书路径
    tls /etc/ssl/fullchain.pem /etc/ssl/private.key

    handle ${path} {
        reverse_proxy h2c://127.0.0.1:${port} {
            transport http {
                tls_insecure_skip_verify
            }
        }
    }

    # 【新增】本地伪装
    handle {
        root * ${masquerade_dir}
        file_server
    }

    import ${is_caddy_site_file}.add
}"
        ;;
    *grpc*)
        cat >${is_caddy_site_file} <<<"
${host}:${is_https_port} {
    # 【新增】强制指定本地证书路径
    tls /etc/ssl/fullchain.pem /etc/ssl/private.key
    
    handle /${path}/* {
        reverse_proxy h2c://127.0.0.1:${port}
    }

    # 【新增】本地伪装
    handle {
        root * ${masquerade_dir}
        file_server
    }

    import ${is_caddy_site_file}.add
}"
        ;;
    proxy)

        cat >${is_caddy_site_file}.add <<<"
reverse_proxy https://$proxy_site {
        header_up Host {upstream_hostport}
}"
        ;;
    esac
    [[ $1 != "new" && $1 != 'proxy' ]] && {
        [[ ! -f ${is_caddy_site_file}.add ]] && echo "# see https://233boy.com/$is_core/caddy-auto-tls/" >${is_caddy_site_file}.add
    }
}
