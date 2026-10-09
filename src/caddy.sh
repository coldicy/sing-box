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
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="icon" href="/icon.svg" type="image/svg+xml">
<title>COLDORA|Intelligent Technology</title>
<meta name="description" content="COLDORA focuses on cloud infrastructure, intelligent systems and next-generation technology solutions.">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif;background:#0b1020;color:#fff}
header{height:80px;display:flex;justify-content:space-between;align-items:center;padding:0 8%;border-bottom:1px solid rgba(255,255,255,.08)}
.logo{font-size:24px;font-weight:700;letter-spacing:2px}
nav a{color:#aaa;text-decoration:none;margin-left:30px;font-size:14px}
nav a:hover{color:white}
.hero{min-height:650px;display:flex;flex-direction:column;justify-content:center;align-items:center;text-align:center;padding:40px}
.hero h1{font-size:64px;background:linear-gradient(90deg,#4facfe,#00f2fe);-webkit-background-clip:text;color:transparent}
.hero p{margin-top:25px;max-width:650px;color:#aaa;font-size:18px;line-height:1.8}
.button{margin-top:40px;display:inline-block;padding:14px 40px;border-radius:30px;background:#fff;color:#111;text-decoration:none;font-weight:600}
.section{padding:80px 8%}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:25px}
.card{background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.08);border-radius:20px;padding:35px}
.card h3{margin-bottom:15px}
.card p{color:#aaa;line-height:1.7}
.status{margin-top:20px;display:inline-block;padding:6px 15px;border-radius:20px;background:#123;color:#4cff8f;font-size:13px}
footer{text-align:center;padding:40px;color:#666;border-top:1px solid rgba(255,255,255,.08)}
@media(max-width:700px){.hero h1{font-size:42px}nav{display:none}}
</style>
</head>
<body>
<header>
<div class="logo">COLDORA</div>
<nav>
<a href="#">Home</a>
<a href="#">Solutions</a>
<a href="#">About</a>
<a href="#">Contact</a>
</nav>
</header>
<section class="hero">
<h1>Building Future Digital Infrastructure</h1>
<p>We design reliable cloud-native systems,intelligent platforms and scalable technology solutions for the next generation of applications.</p>
<a class="button" href="#">Explore More</a>
<span class="status">●All Systems Operational</span>
</section>
<section class="section">
<div class="cards">
<div class="card">
<h3>Cloud Infrastructure</h3>
<p>High performance distributed systems,secure networking architecture and global availability solutions.</p>
</div>
<div class="card">
<h3>Artificial Intelligence</h3>
<p>Researching intelligent automation,machine learning applications and modern computing technologies.</p>
</div>
<div class="card">
<h3>Developer Platform</h3>
<p>Powerful tools and APIs designed for developers building future products.</p>
</div>
</div>
</section>
<footer>©2026 COLDORA Technologies.All rights reserved.</footer>
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
