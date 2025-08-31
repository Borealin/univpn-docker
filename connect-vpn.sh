#!/bin/bash

set -e

echo "Initializing UniVPN connection..."

# 检查必要的环境变量
if [ -z "$UNIVPN_SERVER" ] || [ -z "$UNIVPN_USERNAME" ] || [ -z "$UNIVPN_PASSWORD" ]; then
    echo "Error: Required environment variables not set"
    echo "Required: UNIVPN_SERVER, UNIVPN_USERNAME, UNIVPN_PASSWORD"
    exit 1
fi

# 设置默认值
UNIVPN_PORT=${UNIVPN_PORT:-443}
UNIVPN_TIMEOUT=${UNIVPN_TIMEOUT:-60}

echo "Connecting to UniVPN server: $UNIVPN_SERVER:$UNIVPN_PORT"
echo "Username: $UNIVPN_USERNAME"

# 使用我们的封装脚本连接 VPN
if /app/univpn-wrapper.sh connect "$UNIVPN_SERVER" "$UNIVPN_USERNAME" "$UNIVPN_PASSWORD" "$UNIVPN_PORT"; then
    echo "VPN connection established successfully"
    
    # 等待一下让连接稳定
    sleep 5
    
    # 检查连接状态
    if [ "$(/app/univpn-wrapper.sh status)" = "connected" ]; then
        echo "VPN status verified: connected"
        
        # 显示网络信息
        echo "Network interfaces:"
        ip addr show | grep -E "inet.*(tun|ppp|vpn|cnem_vnic|vnic)" || echo "No VPN interfaces found yet"
        
        # 显示 VPN 接口详情
        if ip addr show | grep -q "cnem_vnic"; then
            echo "UniVPN interface details:"
            ip addr show cnem_vnic
        fi
        
        echo "Routing table:"
        ip route | head -10
        
        echo "Current IP address:"
        curl -s --max-time 10 https://ipinfo.io/ip || echo "Could not determine external IP"
        
        return 0
    else
        echo "Warning: VPN status check failed"
        return 1
    fi
else
    echo "Failed to establish VPN connection"
    return 1
fi
