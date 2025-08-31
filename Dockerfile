FROM ubuntu:24.04

# 避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 设置编码支持中文
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

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
    locales \
    kmod \
    udev \
    && rm -rf /var/lib/apt/lists/*

# 生成 UTF-8 locale
RUN locale-gen C.UTF-8

# 创建工作目录
WORKDIR /app

# 复制 UniVPN 安装包
COPY bin /app/bin

# 安装 UniVPN 客户端（仍需 root 权限）
RUN chmod +x /app/bin/univpn-linux-*.run && sudo /app/bin/univpn-linux-*.run

# 复制启动脚本（在用户创建之后，切换之前）
COPY entrypoint.sh /app/entrypoint.sh
COPY connect-vpn.sh /app/connect-vpn.sh
COPY univpn-wrapper.sh /app/univpn-wrapper.sh

# 设置脚本权限
RUN chmod +x /app/entrypoint.sh /app/connect-vpn.sh /app/univpn-wrapper.sh

# 默认使用 job container 模式
ENTRYPOINT ["/app/entrypoint.sh"]