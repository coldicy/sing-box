# detect init system
is_systemd=$(type -P systemctl)
is_openrc=$(type -P rc-service)

install_service() {
    if [[ $is_systemd ]]; then
        install_service_systemd $1
    elif [[ $is_openrc ]]; then
        install_service_openrc $1
    fi
}

install_service_systemd() {
    case $1 in
    $is_core)
        is_doc_site=https://sing-box.sagernet.org/
        cat >/lib/systemd/system/$is_core.service <<<"
[Unit]
Description=$is_core_name Service
Documentation=$is_doc_site
After=network.target nss-lookup.target

[Service]
#User=nobody
User=root
NoNewPrivileges=true
ExecStart=$is_core_bin run -c $is_config_json -C $is_conf_dir
Restart=on-failure
RestartSec=5s
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1048576
PrivateTmp=true
ProtectSystem=full
#CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
#AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target"
        ;;
    caddy)
        cat >/lib/systemd/system/caddy.service <<<"
#https://github.com/caddyserver/dist/blob/master/init/caddy.service
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=root
Group=root
ExecStart=$is_caddy_bin run --environ --config $is_caddyfile --adapter caddyfile
ExecReload=$is_caddy_bin reload --config $is_caddyfile --adapter caddyfile
Restart=on-failure
RestartSec=5s
TimeoutStopSec=5s
LimitNPROC=10000
LimitNOFILE=1048576
PrivateTmp=true
ProtectSystem=full
#AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target"
        ;;
    esac

    # 【优化】先 reload 让 systemd 识别新文件，再 enable 设置开机自启
    systemctl daemon-reload
    systemctl enable $1
}

install_service_openrc() {
    case $1 in
    $is_core)
        cat >/etc/init.d/$is_core <<EOF
#!/sbin/openrc-run

name="$is_core_name"
description="$is_core_name Service"

command="$is_core_bin"
command_args="run -c $is_config_json -C $is_conf_dir"
# 【修复】删除了 command_background=true，避免与 supervise-daemon 冲突
pidfile="/run/\${RC_SVCNAME}.pid"
output_log="/var/log/$is_core/access.log"
error_log="/var/log/$is_core/error.log"

supervisor=supervise-daemon
respawn_delay=5
respawn_max=0

depend() {
    need net
    after firewall
}
EOF
        chmod +x /etc/init.d/$is_core
        ;;
    caddy)
        cat >/etc/init.d/caddy <<EOF
#!/sbin/openrc-run

name="Caddy"
description="Caddy web server"

command="$is_caddy_bin"
command_args="run --environ --config $is_caddyfile --adapter caddyfile"
# 【修复】删除了 command_background=true，避免与 supervise-daemon 冲突
pidfile="/run/\${RC_SVCNAME}.pid"

supervisor=supervise-daemon
respawn_delay=5
respawn_max=0

depend() {
    need net
    after firewall
}
EOF
        chmod +x /etc/init.d/caddy
        ;;
    esac

    # enable
    rc-update add $1 default
}
