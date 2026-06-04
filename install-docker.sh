#!/bin/bash

# Docker 自动安装脚本（Ubuntu）
# 适用 Ubuntu 22.04/20.04/18.04
# 使用方法：bash install-docker.sh

set -e  # 遇到错误立即退出
set -u  # 未定义变量立即报错

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 或使用 sudo 运行此脚本"
  exit 1
fi


echo "删除可能冲突的软件包..."
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    apt-get remove -y "$pkg" 2>/dev/null || true
done


echo "更新 apt 包索引..."
apt-get update -y

echo "安装依赖包..."
apt-get install -y ca-certificates curl gnupg lsb-release

echo "添加 Docker 官方 GPG key..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "设置 Docker 官方仓库..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "更新 apt 包索引..."
apt-get update -y

echo "安装 Docker Engine..."
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "启动 Docker 并设置开机自启..."
systemctl enable docker
systemctl start docker

echo "安装完成！建议注销后重新登录，以应用 docker 组权限。"
echo "测试 Docker 是否正常：docker run hello-world"