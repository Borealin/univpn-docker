FROM ubuntu:22.04

# 避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 安装必要的依赖
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    unzip \
    net-tools \
    iputils-ping \
    iproute2 \
    iptables \
    sudo \
    expect \
    tcl \
    && rm -rf /var/lib/apt/lists/*

# 创建工作目录
WORKDIR /app

# 复制 UniVPN 安装包
COPY bin/univpn-linux-*.run /app/univpn-installer.run
RUN chmod +x /app/univpn-installer.run

# 安装 UniVPN 客户端
RUN /app/univpn-installer.run --quiet --accept-license || true

# 验证安装
RUN ls -la /usr/local/UniVPN/ || echo "UniVPN installation directory not found"

# 复制启动脚本
COPY entrypoint.sh /app/entrypoint.sh
COPY connect-vpn.sh /app/connect-vpn.sh
COPY univpn-wrapper.sh /app/univpn-wrapper.sh
RUN chmod +x /app/entrypoint.sh /app/connect-vpn.sh /app/univpn-wrapper.sh

# 设置入口点
ENTRYPOINT ["/app/entrypoint.sh"]

