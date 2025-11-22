#!/bin/bash

# EasyTier for ASUS RT-BT86U - 标准打包脚本
# 用于创建符合koolcenter软件中心标准的安装包

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  EasyTier 安装包打包脚本${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查必要文件
echo -e "${YELLOW}检查必要文件...${NC}"
REQUIRED_FILES=(
    "easytier/bin/easytier-core"
    "easytier/scripts/easytier_config.sh"
    "easytier/webs/Module_easytier.asp"
    "easytier/install.sh"
    "easytier/config.json.js"
    "easytier/.valid"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}错误: 缺少必要文件: $file${NC}"
        exit 1
    fi
done

echo -e "${GREEN}✓ 所有必要文件检查通过${NC}"

# 检查目录结构
echo -e "${YELLOW}检查目录结构...${NC}"
REQUIRED_DIRS=(
    "easytier/bin"
    "easytier/scripts"
    "easytier/webs"
    # "easytier/configs" # 当前是空文件
    "easytier/res"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        echo -e "${RED}错误: 缺少必要目录: $dir${NC}"
        exit 1
    fi
done

echo -e "${GREEN}✓ 所有必要目录检查通过${NC}"

# 清理旧的安装包
echo -e "${YELLOW}清理旧的安装包...${NC}"
rm -f easytier.tar.gz easytier.tar.gz.md5

# 打包
echo -e "${YELLOW}开始打包...${NC}"
tar -czf easytier.tar.gz easytier/

# 验证打包结果
if [ ! -f "easytier.tar.gz" ]; then
    echo -e "${RED}错误: 打包失败${NC}"
    exit 1
fi

# 生成MD5
echo -e "${YELLOW}生成MD5校验文件...${NC}"
md5sum easytier.tar.gz > easytier.tar.gz.md5

# 显示打包信息
FILE_SIZE=$(ls -lh easytier.tar.gz | awk '{print $5}')
MD5_VALUE=$(cat easytier.tar.gz.md5 | awk '{print $1}')

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}打包完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "文件名: ${YELLOW}easytier.tar.gz${NC}"
echo -e "大小: ${YELLOW}${FILE_SIZE}${NC}"
echo -e "MD5: ${YELLOW}${MD5_VALUE}${NC}"
echo -e "${GREEN}========================================${NC}"

# 显示包内容
echo -e "${YELLOW}包内容预览:${NC}"
tar -tzf easytier.tar.gz | head -n 20

echo ""
echo -e "${GREEN}✓ 安装包已准备就绪，可以上传到软件中心${NC}"
