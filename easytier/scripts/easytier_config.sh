#!/bin/bash

# EasyTier 配置管理脚本
# 用于软件中心Web界面

# 安全地加载base.sh，如果失败则使用fallback
if [ -f /koolshare/scripts/base.sh ]; then
    source /koolshare/scripts/base.sh 2>/dev/null || true
fi
if [ -d "/koolshare" ]; then
  # 根据环境调整路径
    # Merlin环境
    CONFIG_FILE="/koolshare/configs/easytier.conf"
    EASYTIER_BIN="/koolshare/bin/easytier-core"
    PID_FILE="/var/run/easytier.pid"
    LOCK_FILE="/var/lock/easytier.lock"
    LOG_FILE="/tmp/upload/easytier_log.txt"
else
    alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'
    # 测试环境
    CONFIG_FILE="/tmp/easytier/easytier.conf"
    EASYTIER_BIN="./easytier/bin/easytier-core"
    PID_FILE="/tmp/easytier.pid"
    LOCK_FILE="/tmp/easytier.lock"
    LOG_FILE="/tmp/easytier_log.txt"
fi

# 批量导出所有easytier相关的dbus变量
# 取出 dbus 中的配置，隔离到 DBUS_ 前缀，避免污染脚本逻辑使用的变量
eval "$(dbus export easytier_ 2>/dev/null | sed 's/^export easytier_/DBUS_easytier_/')" || true

echo_date "==================== EasyTier Config Script Start ====================" >> $LOG_FILE
echo_date "EasyConfig script start" >> $LOG_FILE
echo_date "EasyConfig script args: \$1=$1 \$2=$2 \$3=$3" >> $LOG_FILE
echo_date "Script invocation: $0 $*" >> $LOG_FILE
echo_date "PWD: $(pwd)" >> $LOG_FILE
echo_date "=======================================================================" >> $LOG_FILE

# 文件锁机制
set_lock()
{
    echo_date "EasyConfig setlock" >> $LOG_FILE
    exec 233>${LOCK_FILE}
    flock -n 233 || {
        http_response "$ACTION"
        exit 1
    }
}

unset_lock()
{
    echo_date "EasyConfig unlock" >> $LOG_FILE
    flock -u 233
    rm -rf ${LOCK_FILE}
}

# 输入验证函数
number_test()
{
    case $1 in
        ''|*[!0-9]*)
            echo 1
            ;;
        *)
            echo 0
            ;;
    esac
}

# IP地址验证
ip_test()
{
    if echo "$1" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
        echo 0
    else
        echo 1
    fi
}

# 从dbus加载配置
load_config_from_dbus()
{
    # 使用已导出的变量，如果不存在则尝试直接读取
    config_content_encoded=${easytier_config_content_encoded:-$(dbus get easytier_config_content_encoded 2>/dev/null)}
    config_content=${easytier_config_content:-$(dbus get easytier_config_content 2>/dev/null)}
    autostart=${easytier_autostart:-$(dbus get easytier_autostart 2>/dev/null)}
    
    # 如果有编码版本，解码它
    if [ -n "$config_content_encoded" ]; then
        config_content=$(echo "$config_content_encoded" | base64 -d 2>/dev/null || echo "$config_content")
        echo_date "从Base64编码加载配置内容" >> $LOG_FILE
    fi
}

# 验证配置参数
validate_config()
{
    local has_error=0
    
    # 清除之前的错误标记
    dbus set easytier_config_content_error=0 2>/dev/null || true
    
    # 配置文件内容验证
    if [ -z "$config_content" ]; then
        echo_date "❌ 配置文件内容不能为空"
        dbus set easytier_config_content_error=1 2>/dev/null || true
        has_error=1
    else
        # 简单检查配置文件是否包含基本关键词
        if ! echo "$config_content" | grep -qE "(hostname|network_name|instance_name)"; then
            echo_date "⚠️ 配置文件内容可能无效，请检查是否为有效的 easytier 配置"
            # 这里只是警告，不设置为错误
        fi
    fi
    
    return $has_error
}

# 保存配置到文件
save_config_to_file()
{
    echo_date "保存配置文件..."
    echo_date "保存配置文件..." >> $LOG_FILE
    # 确保配置目录存在
    mkdir -p "$(dirname "$CONFIG_FILE")" 2>/dev/null || true
    
    # 验证配置
    if ! validate_config; then
        echo_date "❌ 配置验证失败，不保存到文件"
        return 1
    fi
    
    # 将配置内容保存为配置文件
    if [ -n "$config_content" ]; then
        echo "$config_content" > "$CONFIG_FILE" 2>/dev/null || {
            echo_date "❌ 配置文件保存失败"
            return 1
        }
        chmod 600 "$CONFIG_FILE" 2>/dev/null || true
        echo_date "✅ 配置文件已保存"
        return 0
    else
        echo_date "❌ 配置内容为空"
        return 1
    fi
}

# 检查服务状态
check_status()
{
    echo_date "=== Starting check_status function ===" >> $LOG_FILE
    echo_date "PID_FILE path: $PID_FILE" >> $LOG_FILE
    echo_date "Checking if PID file exists..." >> $LOG_FILE
    
    if [ -f "$PID_FILE" ]; then
        echo_date "PID file exists, reading PID..." >> $LOG_FILE
        PID=$(cat "$PID_FILE" 2>/dev/null)
        echo_date "PID from file: $PID" >> $LOG_FILE
        
        if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
            echo_date "Process $PID is running, returning 运行" >> $LOG_FILE
            http_response "运行"
        else
            echo_date "PID $PID is not running or invalid" >> $LOG_FILE
            http_response "异常"
        fi
    else
        echo_date "PID file does not exist: $PID_FILE" >> $LOG_FILE
        echo_date "EasyTier 未运行" >> $LOG_FILE
        http_response "停止"
    fi
    
}

# 启动EasyTier
start_easytier()
{
    echo_date "正在启动EasyTier..."
    
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo_date "EasyTier 已在运行"
        return 0
    fi
    
    # 检查配置文件是否存在
    if [ ! -f "$CONFIG_FILE" ] || [ ! -s "$CONFIG_FILE" ]; then
        echo_date "❌ 配置文件不存在或为空，无法启动服务"
        return 1
    fi
    
    # 检查二进制文件是否存在
    if [ ! -f "$EASYTIER_BIN" ]; then
        echo_date "❌ EasyTier 二进制文件不存在: $EASYTIER_BIN"
        echo_date "请检查 EasyTier 是否正确安装"
        return 1
    fi
    
    echo_date "使用配置文件启动: $CONFIG_FILE"
    
    # 使用配置文件启动进程
    # 路由器内核的 tun 模块可能未随开机加载，缺它时 core 会报
    # "tun device error: No such device (os error 19)" 并退出
    if ! grep -qs tun /proc/modules && [ ! -e /dev/net/tun ]; then
        modprobe tun 2>/dev/null || true
    fi
    if [ ! -e /dev/net/tun ]; then
        [ -d /dev/net ] || mkdir -p /dev/net
        mknod /dev/net/tun c 10 200 2>/dev/null || true
        chmod 600 /dev/net/tun 2>/dev/null || true
    fi
    cd /tmp || return 1
    nohup $EASYTIER_BIN -c "$CONFIG_FILE" > /dev/null 2>&1 &
    echo $! > "$PID_FILE"
    
    sleep 3
    
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo_date "✅ EasyTier 启动成功"
        return 0
    else
        echo_date "❌ EasyTier 启动失败"
        rm -f $PID_FILE
        return 1
    fi
}

# 停止EasyTier
stop_easytier()
{
    echo_date "正在停止EasyTier..."
    
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
            kill "$PID" 2>/dev/null
            # 等待进程结束
            i=1
            while [ $i -le 10 ]; do
                if ! kill -0 "$PID" 2>/dev/null; then
                    break
                fi
                sleep 1
                i=$((i + 1))
            done
            
            # 如果还在运行，强制杀死
            if kill -0 "$PID" 2>/dev/null; then
                echo_date "进程未正常结束，强制终止..."
                kill -9 "$PID"
                sleep 1
            fi
            
            # 确认进程已停止
            if ! kill -0 "$PID" 2>/dev/null; then
                echo_date "✅ EasyTier 已停止"
                rm -f $PID_FILE
                return 0
            else
                echo_date "❌ EasyTier 停止失败"
                return 1
            fi
        else
            echo_date "EasyTier 进程已不存在，清理PID文件"
            rm -f $PID_FILE
            return 0
        fi
    else
        echo_date "EasyTier 未运行"
        return 0
    fi
}

# 保存配置到dbus
save_config_to_dbus()
{
    echo_date "保存配置到dbus..."
    
    if command -v dbus >/dev/null 2>&1; then
        dbus set easytier_autostart="$autostart" 2>/dev/null || true
        dbus set easytier_config_content="$config_content" 2>/dev/null || true
        # 也保存编码版本以防需要
        if [ -n "$config_content_encoded" ]; then
            dbus set easytier_config_content_encoded="$config_content_encoded" 2>/dev/null || true
        fi
        dbus set easytier_version="1.3.1" 2>/dev/null || true
        
        echo_date "✅ 配置已保存到dbus"
        return 0
    else
        echo_date "❌ dbus命令不可用"
        return 1
    fi
}

# 仅保存自启动配置
save_autostart_config()
{
    echo_date "开始保存自启动配置..."
    
    # 从环境变量读取POST数据
    autostart="$easytier_autostart"
    
    echo_date "自启动配置参数："
    echo_date "  自启动状态: $autostart"
    
    # 保存到dbus
    if command -v dbus >/dev/null 2>&1; then
        dbus set easytier_autostart="$autostart" 2>/dev/null || true
        echo_date "✅ 自启动配置已保存到dbus"
    else
        echo_date "❌ dbus命令不可用"
        return 1
    fi
    
    echo_date "✅ 自启动配置保存完成"
    return 0
}

# 仅保存配置（不启动服务）
save_config()
{
    echo_date "开始保存配置..."
    
    # 从环境变量读取POST数据（由软件中心框架设置）
    autostart="$easytier_autostart"
    config_content_encoded="$easytier_config_content_encoded"
    config_content="$easytier_config_content"
    
    # 如果有编码版本，解码它
    if [ -n "$config_content_encoded" ]; then
        config_content=$(echo "$config_content_encoded" | base64 -d 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$config_content" ]; then
            echo_date "成功从Base64解码配置内容"
        else
            echo_date "Base64解码失败，使用原始内容"
            config_content="$easytier_config_content"
        fi
    fi

    # fields 里没有配置内容时（stop/restart 等提交只带部分字段），
    # 保留现有配置文件，不视为错误
    if [ -z "$config_content" ]; then
        if [ -s "$CONFIG_FILE" ]; then
            echo_date "请求未携带配置内容，保留现有配置文件"
            return 0
        fi
    fi

    echo_date "配置参数："
    echo_date "  自启动状态: $autostart"
    echo_date "  配置文件内容长度: ${#config_content} 字符"
    echo_date "  配置文件行数: $(echo "$config_content" | wc -l)"
    
    # 验证配置
    if ! validate_config; then
        echo_date "❌ 配置验证失败"
        return 1
    fi
    
    # 保存到dbus
    save_config_to_dbus
    
    # 保存配置文件
    save_config_to_file
    
    echo_date "✅ 配置保存完成"
    return 0
}

# 现在统一使用底部的web_submit处理器

# 从配置文件加载配置（作为dbus的备份）
load_config_from_file()
{
    if [ -f "$CONFIG_FILE" ]; then
        echo_date "从配置文件加载配置..."
        # 直接读取整个配置文件内容
        config_content=$(cat "$CONFIG_FILE" 2>/dev/null)
        echo_date "✅ 配置文件加载完成"
    else
        echo_date "⚠️ 配置文件不存在，使用默认配置"
    fi
}

# 获取当前配置
get_config()
{
    # 首先尝试从dbus读取
    autostart_val=""
    config_content_val=""
    version_val="1.3.1"
    
    if command -v dbus >/dev/null 2>&1; then
        autostart_val=$(dbus get easytier_autostart 2>/dev/null || echo "")
        config_content_val=$(dbus get easytier_config_content 2>/dev/null || echo "")
        version_val=$(dbus get easytier_version 2>/dev/null || echo "1.3.1")
    fi
    
    # 如果dbus中没有配置，尝试从文件读取
    if [ -z "$config_content_val" ] && [ -f "$CONFIG_FILE" ]; then
        config_content_val=$(cat "$CONFIG_FILE" 2>/dev/null)
    fi
    
    # 如果配置内容包含换行符，需要进行Base64编码以安全传输
    if [ -n "$config_content_val" ]; then
        config_content_encoded=$(echo "$config_content_val" | base64 -w 0 2>/dev/null || echo "$config_content_val" | base64 2>/dev/null)
    fi
    
    # 输出结果
    echo "easytier_autostart=${autostart_val}"
    echo "easytier_config_content=${config_content_encoded}"  # 输出编码版本
    echo "easytier_version=${version_val}"
}

# 软件中心调用契约（2026-10-31 从真机取证，见 tests/fixtures/contract/）：
#   $1 = 请求随机ID（框架生成，忽略）
#   $2 = 操作名：status | save_config | save_autostart | start | stop | restart
#   $3 = "web_submit"（仅提交类操作携带；status 只有两个参数）
#   fields 中的键会被框架导出为同名环境变量（如 easytier_autostart）
OPERATION="$2"
WEB_SUBMIT="$3"
PARAM_SOURCE="argv"

echo_date "=== Final Operation Handling ===" >> $LOG_FILE
echo_date "Source: $PARAM_SOURCE, Op: $OPERATION, WebSubmit: $WEB_SUBMIT, args: $*" >> $LOG_FILE
# 处理Web提交请求：仅当框架显式携带 web_submit 标记时进入；
# status 轮询（无 $3）永远不进入此分支
if [ "$WEB_SUBMIT" = "web_submit" ]; then
    set_lock
    echo_date "开始处理Web提交..." | tee -a ${LOG_FILE}

    # 统一的错误处理
    # 统一的错误处理
    handle_error()
    {
        echo_date "❌ 操作失败: $1" | tee -a ${LOG_FILE}
        echo "XU6J03M6" | tee -a ${LOG_FILE}
        http_response "$1"
        unset_lock
        exit 1
    }

    # 运行命令，输出进日志，按命令真实退出码继续（tee 不影响判断）
    run_logged()
    {
        local out
        out=$("$@" 2>&1)
        local rc=$?
        [ -n "$out" ] && printf '%s\n' "$out" >> ${LOG_FILE}
        return $rc
    }

    if [ "$OPERATION" = "save_config" ]; then
        echo_date "执行保存配置操作..." | tee -a ${LOG_FILE}
        if run_logged save_config; then
            echo_date "✅ 配置保存成功" | tee -a ${LOG_FILE}
        else
            handle_error "配置保存失败"
        fi
    elif [ "$OPERATION" = "save_autostart" ]; then
        echo_date "执行保存自启动配置操作..." | tee -a ${LOG_FILE}
        if run_logged save_autostart_config; then
            echo_date "✅ 自启动配置保存成功" | tee -a ${LOG_FILE}
        else
            handle_error "自启动配置保存失败"
        fi
    elif [ "$OPERATION" = "start" ] || [ "$OPERATION" = "stop" ] || [ "$OPERATION" = "restart" ]; then
        echo_date "执行服务操作: $OPERATION" | tee -a ${LOG_FILE}

        # 先保存配置
        if ! save_config >/dev/null 2>&1; then
            handle_error "配置保存失败，无法执行服务操作"
        fi

        # 重新加载配置
        load_config_from_dbus

        # 执行服务操作
        case "$OPERATION" in
            start)
                echo_date "🚀 正在启动服务..." | tee -a ${LOG_FILE}
                if run_logged start_easytier; then
                    echo_date "✅ 服务启动成功" | tee -a ${LOG_FILE}
                else
                    handle_error "服务启动失败"
                fi
                ;;
            stop)
                echo_date "⏹️ 正在停止服务..." | tee -a ${LOG_FILE}
                if run_logged stop_easytier; then
                    echo_date "✅ 服务停止成功" | tee -a ${LOG_FILE}
                else
                    handle_error "服务停止失败"
                fi
                ;;
            restart)
                echo_date "🔄 正在重启服务..." | tee -a ${LOG_FILE}
                # 先停止，再启动，两个操作都要成功
                if run_logged stop_easytier; then
                    if run_logged start_easytier; then
                        echo_date "✅ 服务重启成功" | tee -a ${LOG_FILE}
                    else
                        handle_error "服务启动失败"
                    fi
                else
                    handle_error "服务停止失败"
                fi
                ;;
        esac
    else
        handle_error "未知的操作: $OPERATION"
    fi

    echo_date "✅ Web操作完成" | tee -a ${LOG_FILE}
    echo "XU6J03M6" | tee -a ${LOG_FILE}
    # 框架机制：http_response 把响应 POST 给 httpdb(3030/_resp/$ID)，
    # 浏览器的 ajax 才能立即收到返回；否则 httpd 挂起等到前端超时
    http_response "success"
    unset_lock
    exit 0
fi

# 处理直接命令行调用和状态查询
case $OPERATION in
    status)
        # 状态查询直接执行，不需要web_submit处理
        echo_date "Executing status check operation" >> $LOG_FILE
        check_status
        echo_date "Status check completed" >> $LOG_FILE
        exit 0
        ;;
    start)
        if [ "$WEB_SUBMIT" != "web_submit" ]; then
            load_config_from_dbus
            start_easytier
            exit 0
        fi
        ;;
    stop)
        if [ "$WEB_SUBMIT" != "web_submit" ]; then
            stop_easytier
            exit 0
        fi
        ;;
    restart)
        if [ "$WEB_SUBMIT" != "web_submit" ]; then
            load_config_from_dbus
            stop_easytier
            start_easytier
            exit 0
        fi
        ;;
    save_config)
        if [ "$WEB_SUBMIT" != "web_submit" ]; then
            save_config
            exit 0
        fi
        ;;
    save_autostart)
        if [ "$WEB_SUBMIT" != "web_submit" ]; then
            save_autostart_config
            exit 0
        fi
        ;;
    get_config)
        get_config
        exit 0
        ;;
    *)
        if [ "$WEB_SUBMIT" != "web_submit" ]; then
            echo "Usage: $0 {status|start|stop|restart|save_config|save_autostart|get_config}"
            exit 1
        fi
        ;;
esac
