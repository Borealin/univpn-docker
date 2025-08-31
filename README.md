# Connect UniVPN GitHub Action

一个 GitHub Action，用于在工作流执行过程中连接到 UniVPN 环境，实现网络环境的切换。

## 功能特性

- 🔒 在 GitHub Actions 工作流中建立 UniVPN 连接
- 🌐 自动配置网络路由和环境
- 📊 提供连接状态和 IP 地址输出
- ⚙️ 支持自定义连接参数和超时设置
- 🛡️ 自动处理连接失败和清理

## 使用方法

### 基本用法

```yaml
name: Test with UniVPN
on: [push]

jobs:
  test-with-vpn:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Connect to UniVPN
        uses: ./
        with:
          server: ${{ secrets.UNIVPN_SERVER }}
          username: ${{ secrets.UNIVPN_USERNAME }}
          password: ${{ secrets.UNIVPN_PASSWORD }}
          port: '9999'  # 可选，默认 443
          timeout: '60'  # 可选，默认 30 秒
      
      - name: Test network connectivity
        run: |
          echo "Testing connectivity through VPN..."
          curl -s https://ipinfo.io/ip
          ping -c 3 internal.company.com
      
      - name: Run your tests
        run: |
          # 你的测试命令
          npm test
```

### 高级用法

```yaml
name: Deploy with UniVPN
on: [push]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Connect to UniVPN
        id: vpn
        uses: ./
        with:
          server: ${{ secrets.UNIVPN_SERVER }}
          username: ${{ secrets.UNIVPN_USERNAME }}
          password: ${{ secrets.UNIVPN_PASSWORD }}
          port: '9999'  # 如果不是默认端口
          timeout: '120'
          disconnect-on-failure: 'true'
      
      - name: Verify VPN connection
        run: |
          echo "Connection Status: ${{ steps.vpn.outputs.connection-status }}"
          echo "VPN IP Address: ${{ steps.vpn.outputs.ip-address }}"
      
      - name: Deploy to internal server
        if: steps.vpn.outputs.connection-status == 'connected'
        run: |
          # 部署到内网服务器
          scp -o StrictHostKeyChecking=no ./dist/* user@internal.server:/var/www/
```

## 输入参数

| 参数 | 描述 | 必需 | 默认值 |
|------|------|------|--------|
| `server` | UniVPN 服务器地址 | ✅ | - |
| `username` | UniVPN 用户名 | ✅ | - |
| `password` | UniVPN 密码 | ✅ | - |
| `port` | UniVPN 服务器端口 | ❌ | '443' |
| `timeout` | 连接超时时间（秒） | ❌ | '30' |
| `disconnect-on-failure` | 工作流失败时是否断开 VPN | ❌ | 'true' |

## 输出参数

| 参数 | 描述 |
|------|------|
| `connection-status` | VPN 连接状态（'connected' 或 'failed'） |
| `ip-address` | 分配的 VPN IP 地址 |

## 环境要求

### UniVPN 客户端

在使用此 Action 之前，你需要：

1. 从华为官网下载 UniVPN Linux 安装包（.run 文件）
2. 将安装包放置在 `bin/` 目录下
3. 确保文件名格式为 `univpn-linux-*.run`

```bash
mkdir -p bin
# 下载 UniVPN 安装包到 bin/ 目录
# 例如：bin/univpn-linux-64-10781.18.1.0512.run
```

### GitHub Secrets

建议将敏感信息存储在 GitHub Secrets 中：

- `UNIVPN_SERVER`: VPN 服务器地址
- `UNIVPN_USERNAME`: VPN 用户名
- `UNIVPN_PASSWORD`: VPN 密码

## 工作原理

1. **容器化环境**: 使用轻量级 Docker 容器提供隔离的网络环境
2. **自动安装**: 从 .run 文件自动安装 UniVPN 客户端到 `/usr/local/UniVPN/`
3. **命令行交互**: 直接使用 UniVPN 的命令行工具 `UniVPNCS`
4. **交互自动化**: 使用 expect 脚本自动化 UniVPN 客户端的交互流程
5. **连接管理**: 自动创建连接配置、登录并建立 VPN 连接
6. **状态监控**: 持续监控 VPN 连接状态，支持自动重连
7. **自动清理**: 工作流结束时自动断开连接并清理配置

## 故障排除

### 常见问题

1. **UniVPN 安装包未找到**
   ```
   Error: UniVPN client not found at /usr/local/UniVPN/serviceclient/UniVPNCS
   ```
   解决方案：确保 UniVPN 安装包（.run 文件）正确放置在 `bin/` 目录下

2. **连接超时**
   ```
   Timeout waiting for VPN connection
   ```
   解决方案：增加 `timeout` 参数值或检查服务器配置

3. **认证失败**
   ```
   Failed to establish VPN connection
   ```
   解决方案：检查用户名、密码和服务器地址是否正确

### 调试模式

如需调试，可以在工作流中添加：

```yaml
- name: Enable debug mode
  run: echo "RUNNER_DEBUG=1" >> $GITHUB_ENV

- name: Connect to UniVPN
  uses: ./
  with:
    # ... 你的配置
```

## 安全注意事项

- 🔐 始终使用 GitHub Secrets 存储敏感信息
- 🚫 不要在日志中暴露密码或密钥
- 🔍 定期审查和更新访问凭据
- 🛡️ 确保 VPN 服务器的安全配置

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

## 贡献

欢迎提交 Issue 和 Pull Request！

## 致谢

本项目参考了 [jesusdf/huawei-vpn](https://github.com/jesusdf/huawei-vpn) 的实现思路。

