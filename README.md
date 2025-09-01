# UniVPN Docker

一个 Docker 镜像，用于在 GitHub Actions 工作流中提供 UniVPN 网络环境。支持作为 job container 使用，让整个工作流通过 UniVPN 网络运行。

## 功能特性

- 🐳 提供预配置 UniVPN 环境的 Docker 镜像
- 🔒 在 GitHub Actions job container 中建立 UniVPN 连接
- 🌐 整个工作流通过 UniVPN 网络运行
- ⚙️ 支持自定义连接参数和端口设置
- 🔄 自动重连和连接监控
- 🛡️ 自动处理连接失败和清理

## 使用方法

### 方式一：使用 GitHub Action（推荐）

```yaml
name: Test with UniVPN
on: [push]

jobs:
  test-with-vpn:
    runs-on: ubuntu-latest
    container:
      image: borealin/univpn-docker:latest
      options: --privileged
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup UniVPN Connection
        uses: ./  # 如果在同一仓库，或使用 borealin/univpn-docker@main
        with:
          server: ${{ secrets.UNIVPN_SERVER }}
          username: ${{ secrets.UNIVPN_USERNAME }}
          password: ${{ secrets.UNIVPN_PASSWORD }}
          port: ${{ secrets.UNIVPN_PORT || '443' }}
      
      - name: Test VPN connectivity
        run: |
          echo "Testing connectivity through VPN..."
          curl -s https://ipinfo.io/ip
          ping -c 3 internal.company.com
      
      - name: Run your tests
        run: |
          # 所有命令都通过 VPN 网络执行
          npm install
          npm test
      
      - name: Deploy to internal server
        run: |
          # 部署到内网服务器
          scp ./dist/* user@internal.server:/var/www/
      
      - name: Cleanup VPN Connection
        if: always()
        uses: ./cleanup-action.yml  # 或使用 borealin/univpn-docker/cleanup-action@main
```

### 方式二：作为 Job Container（手动连接）

```yaml
name: Test with UniVPN
on: [push]

jobs:
  test-with-vpn:
    runs-on: ubuntu-latest
    # 使用 UniVPN Docker 镜像作为 job container
    container:
      image: borealin/univpn-docker:latest
      env:
        UNIVPN_SERVER: ${{ secrets.UNIVPN_SERVER }}
        UNIVPN_USERNAME: ${{ secrets.UNIVPN_USERNAME }}
        UNIVPN_PASSWORD: ${{ secrets.UNIVPN_PASSWORD }}
        UNIVPN_PORT: ${{ secrets.UNIVPN_PORT || '443' }}
      options: >-
        --privileged
    
    steps:
      - name: Setup VPN Connection
        run: |
          echo "Establishing VPN connection..."
          # 由于 container 模式会覆盖 ENTRYPOINT，需要手动启动 VPN 连接
          if /app/univpn-wrapper.sh connect "$UNIVPN_SERVER" "$UNIVPN_USERNAME" "$UNIVPN_PASSWORD" "$UNIVPN_PORT"; then
            echo "VPN connection established successfully"
            curl -s --max-time 10 https://ipinfo.io/ip
          else
            echo "Failed to establish VPN connection"
            exit 1
          fi
      
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Test VPN connectivity
        run: |
          echo "Testing connectivity through VPN..."
          curl -s https://ipinfo.io/ip
          ping -c 3 internal.company.com
      
      - name: Run your tests
        run: |
          # 所有命令都通过 VPN 网络执行
          npm install
          npm test
      
      - name: Deploy to internal server
        run: |
          # 部署到内网服务器
          scp ./dist/* user@internal.server:/var/www/
      
      - name: Cleanup VPN Connection
        if: always()
        run: |
          echo "Cleaning up VPN connection..."
          /app/univpn-wrapper.sh disconnect || echo "VPN disconnect completed"
```

### 方式三：直接运行 Docker 容器

```bash
# 本地测试（自动连接）
docker run --rm -it \
  --privileged \
  -e UNIVPN_SERVER=vpn.example.com \
  -e UNIVPN_USERNAME=myuser \
  -e UNIVPN_PASSWORD=mypass \
  -e UNIVPN_PORT=9999 \
  borealin/univpn-docker:latest

# 手动连接模式
docker run --rm -it --privileged \
  -e UNIVPN_SERVER=vpn.example.com \
  -e UNIVPN_USERNAME=myuser \
  -e UNIVPN_PASSWORD=mypass \
  -e UNIVPN_PORT=9999 \
  borealin/univpn-docker:latest \
  bash -c "/app/univpn-wrapper.sh connect \$UNIVPN_SERVER \$UNIVPN_USERNAME \$UNIVPN_PASSWORD \$UNIVPN_PORT && bash"

# 在容器内执行命令
docker exec -it <container_id> bash
curl https://ipinfo.io/ip  # 显示 VPN IP
```

## 镜像发布

### 自动发布

每次推送到 `main` 分支或创建 Release 时，GitHub Actions 会自动构建并发布 Docker 镜像到 Docker Hub。

- **最新版本**: `your-username/univpn-docker:latest`
- **分支版本**: `your-username/univpn-docker:main`
- **标签版本**: `your-username/univpn-docker:v1.0.0`

### 手动构建

```bash
# 构建镜像
docker build -t univpn-docker:local .

# 运行测试（完整权限）
docker run --rm -it \
  --privileged \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  --device=/dev/net/tun \
  --sysctl net.ipv6.conf.all.disable_ipv6=0 \
  -e UNIVPN_SERVER=your.vpn.server \
  -e UNIVPN_USERNAME=username \
  -e UNIVPN_PASSWORD=password \
  univpn-docker:local
```

## 环境变量

| 变量 | 描述 | 必需 | 默认值 |
|------|------|------|--------|
| `UNIVPN_SERVER` | UniVPN 服务器地址 | ✅ | - |
| `UNIVPN_USERNAME` | UniVPN 用户名 | ✅ | - |
| `UNIVPN_PASSWORD` | UniVPN 密码 | ✅ | - |
| `UNIVPN_PORT` | UniVPN 服务器端口 | ❌ | '443' |
| `UNIVPN_TIMEOUT` | 连接超时时间（秒） | ❌ | '30' |

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

在 GitHub Actions 中使用时，建议将敏感信息存储在 GitHub Secrets 中：

- `UNIVPN_SERVER`: VPN 服务器地址
- `UNIVPN_USERNAME`: VPN 用户名
- `UNIVPN_PASSWORD`: VPN 密码
- `UNIVPN_PORT`: VPN 端口（可选）

### Docker Hub 设置

如果你要发布到 Docker Hub，需要在 GitHub Secrets 中设置：

- `DOCKER_USERNAME`: 你的 Docker Hub 用户名
- `DOCKER_PASSWORD`: 你的 Docker Hub 访问令牌（推荐）或密码

### 本地开发

本地使用 Docker Compose：

```bash
# 复制环境变量模板
cp env.example .env
# 编辑 .env 文件，填入真实的 VPN 配置

# 启动容器
docker-compose up -d

# 进入容器测试
docker-compose exec univpn bash
curl https://ipinfo.io/ip
```

## 工作原理

1. **容器化环境**: 使用轻量级 Docker 容器提供隔离的网络环境
2. **自动安装**: 从 .run 文件自动安装 UniVPN 客户端到 `/usr/local/UniVPN/`
3. **命令行交互**: 直接使用 UniVPN 的命令行工具 `UniVPNCS`
4. **交互自动化**: 使用 expect 脚本自动化 UniVPN 客户端的交互流程
5. **连接管理**: 自动创建连接配置、登录并建立 VPN 连接
6. **网络接口**: 创建 `cnem_vnic` 虚拟网络接口，提供完整的网络隧道
7. **状态监控**: 持续监控 VPN 连接状态，支持自动重连
8. **自动清理**: 工作流结束时自动断开连接并清理配置

## 故障排除

### 常见问题

1. **Container 模式下 VPN 未自动连接**
   ```
   VPN connection not established automatically in job container
   ```
   **原因**：GitHub Actions 的 `container:` 模式会覆盖 Docker 的 `ENTRYPOINT`，导致自动连接脚本无法运行。
   
   **解决方案**：
   - **推荐**：使用提供的 GitHub Action（方式一）
   - **手动**：在第一个 step 中手动调用连接脚本（方式二）
   - **确保清理**：使用 `if: always()` 条件确保 VPN 连接在作业结束时被正确断开

2. **UniVPN 安装包未找到**
   ```
   Error: UniVPN client not found at /usr/local/UniVPN/serviceclient/UniVPNCS
   ```
   解决方案：确保 UniVPN 安装包（.run 文件）正确放置在 `bin/` 目录下

3. **网络扩展失败**
   ```
   Failed to enable network extension
   ```
   解决方案：确保运行时包含所有必需的权限：
   ```bash
   # GitHub Actions
   options: --privileged
   
   # Docker 命令行
   docker run --privileged your-image
   ```

4. **连接超时**
   ```
   Timeout waiting for VPN connection
   ```
   解决方案：增加 `timeout` 参数值或检查服务器配置

5. **认证失败**
   ```
   Failed to establish VPN connection
   ```
   解决方案：检查用户名、密码和服务器地址是否正确

6. **VPN 连接未正确清理**
   ```
   VPN connection still active after job completion
   ```
   解决方案：确保在 workflow 中添加清理步骤：
   ```yaml
   - name: Cleanup VPN Connection
     if: always()
     run: /app/univpn-wrapper.sh disconnect || echo "Cleanup completed"
   ```

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

