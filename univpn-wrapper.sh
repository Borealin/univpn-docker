#!/bin/bash

set -e

# UniVPN 自动化封装脚本
# 支持自动创建连接、登录和断开连接

UNIVPN_CLIENT="/usr/local/UniVPN/serviceclient/UniVPNCS"
UNIVPN_PID_FILE="/tmp/univpn.pid"
CONNECTION_NAME="AutoConn_$(date +%s)_$$"

# 默认值
DEFAULT_PORT="443"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# 检查 UniVPN 客户端是否存在
check_univpn_client() {
    if [ ! -f "$UNIVPN_CLIENT" ]; then
        error "UniVPN client not found at $UNIVPN_CLIENT"
        error "Please ensure UniVPN is properly installed"
        exit 1
    fi
    
    if [ ! -x "$UNIVPN_CLIENT" ]; then
        error "UniVPN client is not executable"
        exit 1
    fi
    
    log "UniVPN client found at $UNIVPN_CLIENT"
}

# 清理现有连接
cleanup_connections() {
    log "Cleaning up existing connections..."
    
    # 使用 expect 来自动化交互
    expect << EOF
set timeout 10
spawn $UNIVPN_CLIENT

# 等待主菜单
expect "Welcome to UniVPN!"

# 循环删除所有现有连接
while {1} {
    expect {
        "Welcome to UniVPN!" {
            # 查找连接列表中的数字（连接ID）
            expect {
                -re {([0-9]+):[^0-9\n]*\n} {
                    set connection_id $expect_out(1,string)
                    if {$connection_id > 2} {
                        # 选择连接
                        send "$connection_id\r"
                        expect "1:Connect"
                        # 选择删除
                        send "2\r"
                        expect "Are you sure you want to delete"
                        # 确认删除
                        send "1\r"
                        expect "Welcome to UniVPN!"
                        continue
                    }
                }
                "2:Exit" {
                    # 没有更多连接，退出
                    send "2\r"
                    break
                }
            }
        }
        timeout {
            send "2\r"
            break
        }
    }
}

expect eof
EOF

    log "Existing connections cleaned up"
}

# 创建新连接
create_connection() {
    local gateway="$1"
    local port="${2:-$DEFAULT_PORT}"
    
    log "Creating new connection: $CONNECTION_NAME"
    log "Gateway: $gateway, Port: $port"
    
    expect << EOF
set timeout 30
spawn $UNIVPN_CLIENT

# 等待主菜单
expect "Welcome to UniVPN!"

# 选择新建连接
send "1\r"

# 选择 SSL VPN
expect "Please choose Connection Type"
send "1\r"

# 输入连接名称
expect "1:Connection Name"
send "1\r"
expect "Please Input Connection Name"
send "$CONNECTION_NAME\r"

# 输入网关地址
expect "3:Gateway Address"
send "3\r"
expect "Please Input Gateway Address"
send "$gateway\r"

# 设置端口（如果不是默认的443）
if {"$port" != "443"} {
    expect "4:Port:443"
    send "4\r"
    expect "Please Input Port"
    send "$port\r"
}

# 保存配置
expect "7:Save"
send "7\r"

# 等待返回主菜单
expect "Welcome to UniVPN!"

# 退出
send "2\r"
expect eof
EOF

    if [ $? -eq 0 ]; then
        log "Connection created successfully: $CONNECTION_NAME"
        return 0
    else
        error "Failed to create connection"
        return 1
    fi
}

# 连接 VPN
connect_vpn() {
    local username="$1"
    local password="$2"
    
    log "Connecting to VPN with user: $username"
    
    # 在后台启动 UniVPN 连接
    expect << EOF &
set timeout 60
spawn $UNIVPN_CLIENT

# 等待主菜单并查找我们的连接
expect "Welcome to UniVPN!"

# 查找连接ID（应该是3或更高的数字）
expect {
    -re {([0-9]+):$CONNECTION_NAME} {
        set connection_id \$expect_out(1,string)
        send "\$connection_id\r"
    }
    timeout {
        puts "Connection not found in menu"
        exit 1
    }
}

# 选择连接
expect "1:Connect"
send "1\r"

# 等待用户名提示
expect {
    "Please input the login user name" {
        send "$username\r"
    }
    "Connect success." {
        send "$username\r"
    }
    timeout {
        puts "Username prompt not found"
        exit 1
    }
}

# 等待密码提示
expect {
    "Please input the login user password" {
        send "$password\r"
    }
    timeout {
        puts "Password prompt not found"
        exit 1
    }
}

# 等待连接成功
expect {
    "Connect Success,Enjoy!" {
        puts "VPN connected successfully"
        # 保持连接，等待断开信号
        expect "q:Disconnect"
        # 这里不发送 q，保持连接状态
        # 等待外部信号来断开连接
        while {1} {
            sleep 1
        }
    }
    "login failed" {
        puts "Login failed - invalid credentials"
        exit 1
    }
    timeout {
        puts "Connection timeout"
        exit 1
    }
}
EOF

    local expect_pid=$!
    echo $expect_pid > "$UNIVPN_PID_FILE"
    
    # 等待连接建立
    sleep 10
    
    # 检查进程是否还在运行
    if kill -0 $expect_pid 2>/dev/null; then
        log "VPN connection established successfully"
        log "PID: $expect_pid"
        return 0
    else
        error "VPN connection failed"
        return 1
    fi
}

# 断开 VPN 连接
disconnect_vpn() {
    log "Disconnecting VPN..."
    
    if [ -f "$UNIVPN_PID_FILE" ]; then
        local pid=$(cat "$UNIVPN_PID_FILE")
        if kill -0 $pid 2>/dev/null; then
            # 发送 q 命令断开连接
            echo "q" | kill -PIPE $pid 2>/dev/null || true
            sleep 2
            
            # 强制终止进程
            kill -TERM $pid 2>/dev/null || true
            sleep 2
            kill -KILL $pid 2>/dev/null || true
            
            log "VPN disconnected"
        else
            warn "VPN process not found"
        fi
        rm -f "$UNIVPN_PID_FILE"
    else
        warn "No active VPN connection found"
    fi
    
    # 清理连接配置
    cleanup_connections
}

# 检查 VPN 连接状态
check_vpn_status() {
    if [ -f "$UNIVPN_PID_FILE" ]; then
        local pid=$(cat "$UNIVPN_PID_FILE")
        if kill -0 $pid 2>/dev/null; then
            echo "connected"
            return 0
        fi
    fi
    echo "disconnected"
    return 1
}

# 主函数
main() {
    case "${1:-}" in
        "connect")
            if [ $# -lt 4 ]; then
                error "Usage: $0 connect <gateway> <username> <password> [port]"
                exit 1
            fi
            
            check_univpn_client
            cleanup_connections
            
            if create_connection "$2" "$5"; then
                if connect_vpn "$3" "$4"; then
                    log "VPN connection process completed successfully"
                    exit 0
                else
                    error "Failed to connect to VPN"
                    cleanup_connections
                    exit 1
                fi
            else
                error "Failed to create VPN connection"
                exit 1
            fi
            ;;
            
        "disconnect")
            disconnect_vpn
            ;;
            
        "status")
            check_vpn_status
            ;;
            
        *)
            echo "Usage: $0 {connect|disconnect|status}"
            echo ""
            echo "Commands:"
            echo "  connect <gateway> <username> <password> [port]  - Connect to VPN"
            echo "  disconnect                                       - Disconnect from VPN"
            echo "  status                                          - Check VPN status"
            echo ""
            echo "Examples:"
            echo "  $0 connect vpn.example.com myuser mypass"
            echo "  $0 connect vpn.example.com myuser mypass 9999"
            echo "  $0 disconnect"
            echo "  $0 status"
            exit 1
            ;;
    esac
}

# 脚本入口点
main "$@"
