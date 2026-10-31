#!/bin/sh
# Mock koolshare base.sh: minimal echo_date + http_response
echo_date() {
    echo "【$(date '+%Y年%m月%d日 %H:%M:%S')】: $*"
}
http_response() {
    echo "$1"
}
