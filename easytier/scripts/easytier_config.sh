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
eval $(dbus export easytier_) 2>/dev/null || true

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
    
    if [ -f "$PID_FILE" ] && kill -0 $(cat $PID_FILE) 2>/dev/null; then
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
    cd /tmp
    nohup $EASYTIER_BIN -c "$CONFIG_FILE" > /dev/null 2>&1 &
    echo $! > $PID_FILE
    
    sleep 3
    
    if [ -f $PID_FILE ] && kill -0 $(cat $PID_FILE) 2>/dev/null; then
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
    
    if [ -f $PID_FILE ]; then
        PID=$(cat $PID_FILE)
        if kill -0 $PID 2>/dev/null; then
            kill $PID
            # 等待进程结束
            i=1
            while [ $i -le 10 ]; do
                if ! kill -0 $PID 2>/dev/null; then
                    break
                fi
                sleep 1
                i=$((i + 1))
            done
            
            # 如果还在运行，强制杀死
            if kill -0 $PID 2>/dev/null; then
                echo_date "进程未正常结束，强制终止..."
                kill -9 $PID
                sleep 1
            fi
            
            # 确认进程已停止
            if ! kill -0 $PID 2>/dev/null; then
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
        dbus set easytier_version="1.2.0" 2>/dev/null || true
        
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
    version_val="1.2.0"
    
    if command -v dbus >/dev/null 2>&1; then
        autostart_val=$(dbus get easytier_autostart 2>/dev/null || echo "")
        config_content_val=$(dbus get easytier_config_content 2>/dev/null || echo "")
        version_val=$(dbus get easytier_version 2>/dev/null || echo "1.2.0")
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

# 软件中心API参数检测与处理
# 软件中心调用机制分析：
# 从你的调试显示：args "38727934 status"
# 说明：$1=随机ID, $2=某种状态，真正的参数需要从别的地方获取

OPERATION=""
WEB_SUBMIT=""
PARAM_SOURCE="unknown"

# 检测调用模式
IS_API_CALL=0
if [ -n "$1" ] && [ "$1" -eq "$1" ] 2>/dev/null; then
    IS_API_CALL=1
fi

echo_date "=== Parameter Detection Start ===" >> $LOG_FILE
echo_date "Raw args: \$1=$1, \$2=$2, IS_API_CALL=$IS_API_CALL" >> $LOG_FILE

if [ "$IS_API_CALL" = "1" ]; then
    # 软件中心API调用模式
    echo_date "检测为API调用模式，分析请求类型..." >> $LOG_FILE
    
    # 方法1: 检查预定义的环境变量
    echo_date "Method 1: Checking predefined environment variables..." >> $LOG_FILE
    for prefix in "params_" "param_" "method_param_" "arg_" ""; do
        if [ -z "$prefix" ]; then
            # 检查直接的数字变量名和特殊变量
            for varname in "1" "2" "3" "params" "method" "action" "operation"; do
                eval "val=\$$varname"
                if [ -n "$val" ] && [ "$varname" != "1" ] || ([ "$varname" = "1" ] && [ "$val" != "$1" ]); then
                    OPERATION="$val"
                    PARAM_SOURCE="direct_${varname}"
                    echo_date "Found operation from \$${varname}: $OPERATION" >> $LOG_FILE
                    break 2
                fi
            done
        else
            var1="${prefix}0"
            var2="${prefix}1"
            eval "val1=\$$var1"
            eval "val2=\$$var2"
            echo_date "Checking ${var1}=$val1, ${var2}=$val2" >> $LOG_FILE
            if [ -n "$val1" ]; then
                OPERATION="$val1"
                WEB_SUBMIT="$val2"
                PARAM_SOURCE="env_${prefix}"
                echo_date "Found operation from ${var1}: $OPERATION" >> $LOG_FILE
                break
            fi
        fi
    done
    
    # 特殊检查：软件中心可能直接设置method环境变量
    if [ -z "$OPERATION" ] && [ -n "$method" ]; then
        echo_date "Found method variable: $method" >> $LOG_FILE
        OPERATION="$method"
        PARAM_SOURCE="method_env"
    fi
    
    # 方法2: 基于$2参数和配置字段推断操作类型
    if [ -z "$OPERATION" ]; then
        echo_date "Method 2: No operation found in env vars, inferring from params and config..." >> $LOG_FILE
        echo_date "第二参数: $2" >> $LOG_FILE
        echo_date "检查配置字段: easytier_autostart=$easytier_autostart, easytier_config_content=${#easytier_config_content}, easytier_config_content_encoded=${#easytier_config_content_encoded}" >> $LOG_FILE
        
        # 首先检查$2参数是否明确指示了操作类型
        if [ "$2" = "status" ]; then
            echo_date "第二参数明确为status，执行状态查询" >> $LOG_FILE
            OPERATION="status"
            PARAM_SOURCE="inferred_status_from_param2"
        # 检查是否有easytier配置字段（表示这是配置相关请求）
        elif [ -n "$easytier_autostart" ] || [ -n "$easytier_config_content" ] || [ -n "$easytier_config_content_encoded" ]; then
            echo_date "检测到配置字段，判断为配置相关操作" >> $LOG_FILE
            # 根据软件中心框架的常见模式，有配置字段通常表示服务操作
            # 需要进一步判断是什么操作
            if [ -n "$easytier_config_content" ] || [ -n "$easytier_config_content_encoded" ]; then
                echo_date "配置文件内容存在，推断为启动服务操作" >> $LOG_FILE
                OPERATION="start"
                WEB_SUBMIT="web_submit"
                PARAM_SOURCE="inferred_start_from_config"
            else
                echo_date "配置不完整，推断为保存配置操作" >> $LOG_FILE
                OPERATION="save_config"
                WEB_SUBMIT="web_submit"
                PARAM_SOURCE="inferred_save_from_config"
            fi
        else
            # 没有配置字段且$2不是status，默认为状态查询
            echo_date "无配置字段且第二参数非status，默认为状态查询" >> $LOG_FILE
            OPERATION="status"
            PARAM_SOURCE="inferred_default_status"
        fi
    fi
    
    # 方法3: 调试模式 - 记录所有相关环境变量
    echo_date "=== 环境变量调试信息 ===" >> $LOG_FILE
    echo_date "All environment variables containing 'param', 'method', 'easy', or 'arg':" >> $LOG_FILE
    env | grep -iE "(param|method|easy|arg|action|operation)" | head -30 >> $LOG_FILE
    echo_date "All positional parameters:" >> $LOG_FILE
    echo_date "All args: $*" >> $LOG_FILE
    i=0
    while [ $i -le 5 ]; do
        eval "val=\$$i"
        if [ -n "$val" ]; then
            echo_date "  \$$i = $val" >> $LOG_FILE
        fi
        i=$((i + 1))
    done
    echo_date "Special variables check:" >> $LOG_FILE
    echo_date "  method=$method" >> $LOG_FILE
    echo_date "  action=$action" >> $LOG_FILE
    echo_date "  operation=$operation" >> $LOG_FILE
    echo_date "========================" >> $LOG_FILE
    
    # 方法4: 基于payload分析的直接映射
    if [ -z "$OPERATION" ]; then
        echo_date "Method 4: Direct payload mapping based on config presence..." >> $LOG_FILE
        # 如果有完整的配置字段，且不是单纯的status查询，很可能是服务操作
        if [ -n "$easytier_config_content" ] || [ -n "$easytier_config_content_encoded" ]; then
            echo_date "Complete config detected, assuming service operation" >> $LOG_FILE
            # 检查是否有明确的服务操作指示
            if [ "$2" != "status" ]; then
                OPERATION="start"
                WEB_SUBMIT="web_submit"
                PARAM_SOURCE="inferred_service_operation"
                echo_date "Inferring start operation from complete config" >> $LOG_FILE
            fi
        fi
    fi
    
else
    # 标准命令行调用
    OPERATION="$1"
    WEB_SUBMIT="$2"
    PARAM_SOURCE="cmdline"
fi

echo_date "最终确定 - Source: $PARAM_SOURCE, Op: $OPERATION, WebSubmit: $WEB_SUBMIT" >> $LOG_FILE

# 处理Web提交请求
if [ "$WEB_SUBMIT" = "web_submit" ] || ( [ "$IS_API_CALL" = "1" ] && ( [ -n "$easytier_config_content" ] || [ -n "$easytier_config_content_encoded" ] ) ); then
    # 强制设置为web_submit模式，如果检测到完整配置
    if [ "$WEB_SUBMIT" != "web_submit" ]; then
        WEB_SUBMIT="web_submit"
        echo_date "Forcing web_submit mode due to config presence" >> $LOG_FILE
    fi
    
    set_lock
    true > ${LOG_FILE} 2>/dev/null || true
    check_status
    
    echo_date "开始处理Web提交..." | tee -a ${LOG_FILE}
    
    # 统一的错误处理
    handle_error()
    {
        echo_date "❌ 操作失败: $1" | tee -a ${LOG_FILE}
        echo "XU6J03M6" | tee -a ${LOG_FILE}
        unset_lock
        exit 1
    }
    
    if [ "$OPERATION" = "save_config" ]; then
        echo_date "执行保存配置操作..." | tee -a ${LOG_FILE}
        if save_config 2>&1 | tee -a ${LOG_FILE}; then
            echo_date "✅ 配置保存成功" | tee -a ${LOG_FILE}
        else
            handle_error "配置保存失败"
        fi
    elif [ "$OPERATION" = "save_autostart" ]; then
        echo_date "执行保存自启动配置操作..." | tee -a ${LOG_FILE}
        if save_autostart_config 2>&1 | tee -a ${LOG_FILE}; then
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
                if start_easytier 2>&1 | tee -a ${LOG_FILE}; then
                    echo_date "✅ 服务启动成功" | tee -a ${LOG_FILE}
                else
                    handle_error "服务启动失败"
                fi
                ;;
            stop)
                echo_date "⏹️ 正在停止服务..." | tee -a ${LOG_FILE}
                if stop_easytier 2>&1 | tee -a ${LOG_FILE}; then
                    echo_date "✅ 服务停止成功" | tee -a ${LOG_FILE}
                else
                    handle_error "服务停止失败"
                fi
                ;;
            restart)
                echo_date "🔄 正在重启服务..." | tee -a ${LOG_FILE}
                # 先停止，再启动，两个操作都要成功
                if stop_easytier 2>&1 | tee -a ${LOG_FILE}; then
                    if start_easytier 2>&1 | tee -a ${LOG_FILE}; then
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
    unset_lock
    exit 0
fi

# 处理直接命令行调用和状态查询
echo_date "=== Final Operation Handling ===" >> $LOG_FILE
echo_date "OPERATION: $OPERATION, WEB_SUBMIT: $WEB_SUBMIT, PARAM_SOURCE: $PARAM_SOURCE" >> $LOG_FILE

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
