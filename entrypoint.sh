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
UNIVPN_TIMEOUT=${UNIVPN_TIMEOUT:-30}
DISCONNECT_ON_FAILURE=${DISCONNECT_ON_FAILURE:-true}

# 连接 VPN
echo "Connecting to UniVPN server: $UNIVPN_SERVER"
if /app/connect-vpn.sh; then
    echo "VPN connection established successfully"
    
    # 获取 VPN IP 地址
    VPN_IP=$(ip route get 8.8.8.8 | awk '{print $7}' | head -n1)
    echo "VPN IP Address: $VPN_IP"
    
    # 设置 GitHub Actions 输出
    echo "connection-status=connected" >> $GITHUB_OUTPUT
    echo "ip-address=$VPN_IP" >> $GITHUB_OUTPUT
    
    # 验证网络连接
    echo "Testing network connectivity..."
    if ping -c 3 8.8.8.8 > /dev/null 2>&1; then
        echo "Network connectivity verified"
    else
        echo "Warning: Network connectivity test failed"
    fi
    
    # 保持容器运行，等待工作流完成
    echo "VPN connection ready. Waiting for workflow to complete..."
    
    # 设置信号处理器，在容器停止时断开 VPN
    trap 'echo "Disconnecting VPN..."; /app/univpn-wrapper.sh disconnect || true; exit 0' TERM INT
    
    # 保持运行
    while true; do
        sleep 30
        # 检查 VPN 连接状态
        if [ "$(/app/univpn-wrapper.sh status)" != "connected" ]; then
            echo "VPN connection lost, attempting to reconnect..."
            if ! /app/connect-vpn.sh; then
                echo "Failed to reconnect VPN"
                if [ "$DISCONNECT_ON_FAILURE" = "true" ]; then
                    exit 1
                fi
            fi
        fi
    done
else
    echo "Failed to establish VPN connection"
    echo "connection-status=failed" >> $GITHUB_OUTPUT
    exit 1
fi

