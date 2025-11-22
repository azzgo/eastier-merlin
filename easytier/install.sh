#!/bin/sh

# EasyTier for koolcenter软件中心安装脚本
# 适用于RT-BT86U - 修复版

source /koolshare/scripts/base.sh
alias echo_date='echo 【$(date +"%Y年%m月%d日 %H:%M:%S")】'

DIR="/koolshare"
INSTALL_DIR="/koolshare"
CONFIG_DIR="/koolshare/configs"

# 软件中心要求的目录结构
WEB_DIR="/koolshare/webs"
RES_DIR="/koolshare/res"

# 设置权限
set_lock(){
    exec 1000>"/tmp/easytier_install.lock"
    flock -x 1000
}

unset_lock(){
    flock -u 1000
    exec 1000>&-
}

# 检查架构
check_arch(){
    if [ "$(uname -m)" != "aarch64" ]; then
        echo_date "错误: 此插件仅支持ARM64架构 (RT-BT86U)"
        exit 1
    fi
}

# 检查空间
check_space(){
    local available=$(df /koolshare | tail -1 | awk '{print $4}')
    local required=5000
    if [ "$available" -lt "$required" ]; then
        echo_date "警告: 可用空间不足，建议至少5MB"
    fi
}

# 安装文件
install_files(){
    echo_date "安装文件..."
    
    # 确定源文件目录
    # 软件中心解压到 /tmp/easytier，所以使用绝对路径
    SOURCE_DIR="/tmp/easytier"
    echo_date "源文件目录: $SOURCE_DIR"
    echo_date "当前工作目录: $(pwd)"
    
    # 列出源目录内容用于调试
    echo_date "源目录内容:"
    ls -la $SOURCE_DIR 2>&1
    
    # 复制二进制
    if [ -f "$SOURCE_DIR/bin/easytier-core" ]; then
        cp -f "$SOURCE_DIR/bin/easytier-core" $INSTALL_DIR/bin/
        chmod +x $INSTALL_DIR/bin/easytier-core
        echo_date "✓ 二进制文件复制成功"
    else
        echo_date "✗ 找不到二进制文件: $SOURCE_DIR/bin/easytier-core"
    fi
    
    # 复制脚本
    if [ -f "$SOURCE_DIR/scripts/easytier_config.sh" ]; then
        cp -f "$SOURCE_DIR/scripts/easytier_config.sh" $INSTALL_DIR/scripts/
        # 软件中心API需要脚本在/koolshare/scripts/目录
        cp -f "$SOURCE_DIR/scripts/easytier_config.sh" /koolshare/scripts/easytier_config.sh
        chmod +x $INSTALL_DIR/scripts/*.sh
        chmod +x $INSTALL_DIR/scripts/*.cgi
        chmod +x /koolshare/scripts/easytier_config.sh
        echo_date "✓ 脚本文件复制成功"
    else
        echo_date "✗ 找不到脚本目录: $SOURCE_DIR/scripts/"
    fi
    
    # 复制Web界面
    if [ -f "$SOURCE_DIR/webs/Module_easytier.asp" ]; then
        cp -f "$SOURCE_DIR/webs/Module_easytier.asp" $WEB_DIR/Module_easytier.asp
        echo_date "✓ Web界面复制成功"
    else
        echo_date "✗ 找不到Web界面: $SOURCE_DIR/webs/Module_easytier.asp"
    fi
    
    # 复制插件信息
    if [ -f "$SOURCE_DIR/config.json.js" ]; then
        cp -f "$SOURCE_DIR/config.json.js" $INSTALL_DIR/
        echo_date "✓ 配置文件复制成功"
    else
        echo_date "✗ 找不到配置文件: $SOURCE_DIR/config.json.js"
    fi
    
    # 复制图标
    if [ -f "$SOURCE_DIR/res/easytier.png" ]; then
        cp -f "$SOURCE_DIR/res/easytier.png" $RES_DIR/icon-easytier.png
        echo_date "✓ 图标文件复制成功"
    else
        echo_date "✗ 找不到图标文件: $SOURCE_DIR/res/easytier.png"
    fi
    
    # 创建默认配置
    cat > $CONFIG_DIR/easytier.conf << EOF
ipv4=10.0.0.1
network_name=my-network
network_secret=change-me
peers=
enable=0
EOF
    
    chmod 600 $CONFIG_DIR/easytier.conf
}

# 创建启动脚本 - 已由单独的文件提供，无需创建

# 创建卸载脚本
create_uninstall_script(){
    cat > $INSTALL_DIR/scripts/uninstall_easytier.sh << 'EOF'
#!/bin/sh
source /koolshare/scripts/base.sh

# 停止服务
/koolshare/scripts/easytier_config.sh stop

# 删除文件
rm -f /koolshare/configs/easytier.conf
rm -f /koolshare/webs/Module_easytier.asp
rm -f /koolshare/res/icon-easytier.png
rm -f /koolshare/scripts/easytier_config.sh
rm -f /koolshare/scripts/uninstall_easytier.sh

# 删除计划任务
cru d easytier_check

# 删除dbus设置
dbus remove softcenter_module_easytier_version
dbus remove softcenter_module_easytier_install
dbus remove softcenter_module_easytier_name
dbus remove softcenter_module_easytier_title
dbus remove softcenter_module_easytier_description
dbus remove easytier_version
dbus remove easytier_enable
dbus remove easytier_ip
dbus remove easytier_name
dbus remove easytier_secret
dbus remove easytier_peers

# 完成
echo_date "EasyTier 已卸载完成" >> /tmp/easytier_uninstall.log
EOF
    chmod +x $INSTALL_DIR/scripts/uninstall_easytier.sh
}

# 添加到软件中心 - 关键修复部分
add_to_software_center(){
    echo_date "添加到软件中心..."
    
    # 版本号
    VERSION="1.2.1"
    
    # 设置软件中心需要的dbus变量 - 这是关键！
    dbus set softcenter_module_easytier_version="$VERSION"
    dbus set softcenter_module_easytier_install="1"
    dbus set softcenter_module_easytier_name="easytier"
    dbus set softcenter_module_easytier_title="EasyTier"
    dbus set softcenter_module_easytier_description="EasyTier 是一个简单、安全、去中心化的内网穿透 VPN 组网方案"
    dbus set easytier_version="$VERSION"
    dbus set easytier_enable=0
    dbus set easytier_ip=""
    dbus set easytier_name=""
    dbus set easytier_secret=""
    dbus set easytier_peers=""
    
    # 创建软件中心启动脚本
    cat > /koolshare/init.d/S99easytier.sh << 'EOF'
#!/bin/sh
source /koolshare/scripts/base.sh
if [ -f /koolshare/scripts/easytier_config.sh ]; then
    /koolshare/scripts/easytier_config.sh start
fi
EOF
    chmod +x /koolshare/init.d/S99easytier.sh
    
    # 创建软件中心停止脚本
    cat > /koolshare/init.d/N99easytier.sh << 'EOF'
#!/bin/sh
source /koolshare/scripts/base.sh
if [ -f /koolshare/scripts/easytier_config.sh ]; then
    /koolshare/scripts/easytier_config.sh stop
fi
EOF
    chmod +x /koolshare/init.d/N99easytier.sh
}

# 主安装流程
main(){
    set_lock
    echo_date "开始安装EasyTier..."
    
    check_arch
    check_space
    install_files
    create_uninstall_script
    add_to_software_center
    
    echo_date "EasyTier 安装完成！"
    echo_date "请访问 http://$(nvram get lan_ipaddr)/Module_easytier.asp 进行配置"
    
    unset_lock
}

main "$@"
