#!/bin/bash

set -e

echo "Starting UniVPN Connection Action..."

# 检查必要的环境变量
if [ -z "$UNIVPN_SERVER" ] || [ -z "$UNIVPN_USERNAME" ] || [ -z "$UNIVPN_PASSWORD" ]; then
    echo "Error: Required environment variables not set"
    echo "Required: UNIVPN_SERVER, UNIVPN_USERNAME, UNIVPN_PASSWORD"
    exit 1
fi

# 设置默认值
UNIVPN_PORT=${UNIVPN_PORT:-443}

# 连接 VPN
echo "Connecting to UniVPN server: $UNIVPN_SERVER:$UNIVPN_PORT"
if /app/univpn-wrapper.sh connect "$UNIVPN_SERVER" "$UNIVPN_USERNAME" "$UNIVPN_PASSWORD" "$UNIVPN_PORT"; then
    echo "VPN connection established successfully"
    
    # 显示网络信息
    echo "Network interfaces:"
    ip addr show | grep -E "inet.*(tun|ppp|vpn|cnem_vnic|vnic)" || echo "No VPN interfaces found yet"
    
    # 获取 VPN IP 地址
    VPN_IP=$(ip addr show cnem_vnic 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1 || echo "unknown")
    
    echo "Current IP address:"
    curl -s --max-time 10 https://ipinfo.io/ip || echo "Could not determine external IP"
    
    echo "VPN setup complete. Container ready for GitHub Actions."
    
    # 设置信号处理器
    trap '/app/univpn-wrapper.sh disconnect || true; exit 0' TERM INT
    
    # 保持容器运行，等待 GitHub Actions 执行命令
    while true; do
        sleep 30
        # 检查 VPN 连接状态
        if [ "$(/app/univpn-wrapper.sh status)" != "connected" ]; then
            echo "VPN connection lost, attempting to reconnect..."
            /app/univpn-wrapper.sh connect "$UNIVPN_SERVER" "$UNIVPN_USERNAME" "$UNIVPN_PASSWORD" "$UNIVPN_PORT" || true
        fi
    done
else
    echo "Failed to establish VPN connection"
    exit 1
fi
