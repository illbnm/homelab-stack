# Productivity Stack

自托管生产力工具套件，包含代码托管、密码管理、团队知识库、PDF 工具和在线白板。

## 服务架构

```
┌─────────────────────────────────────────────────────────┐
│                  Productivity Stack                        │
├─────────────────────────────────────────────────────────┤
│                                                          │
│   Gitea                                                 │
│   ├── Git 代码托管                                      │
│   ├── OIDC 认证                                         │
│   └── SSH/Git 协议支持                                 │
│                                                          │
│   Vaultwarden                                           │
│   ├── 密码管理器                                        │
│   ├── Bitwarden 兼容 API                               │
│   └── 浏览器扩展支持                                    │
│                                                          │
│   Outline                                               │
│   ├── 团队知识库                                        │
│   ├── Markdown 编辑                                     │
│   └── OIDC 认证                                        │
│                                                          │
│   Stirling PDF                                          │
│   ├── PDF 处理工具                                      │
│   └── 合并/分割/转换                                  │
│                                                          │
│   Excalidraw                                            │
│   ├── 在线白板                                          │
│   └── 实时协作                                          │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## 服务列表

| 服务 | 地址 | 说明 |
|------|------|------|
| Gitea | https://git.${DOMAIN} | Git 代码托管 |
| Vaultwarden | https://vault.${DOMAIN} | 密码管理器 |
| Outline | https://docs.${DOMAIN} | 团队知识库 |
| Stirling PDF | https://pdf.${DOMAIN} | PDF 工具 |
| Excalidraw | https://draw.${DOMAIN} | 在线白板 |

## 快速开始

### 1. 配置环境变量

```bash
cd homelab-stack
cp stacks/productivity/.env.example stacks/productivity/.env
nano stacks/productivity/.env
```

### 2. 初始化数据库

Vaultwarden 和 Outline 需要数据库。在 `../databases/init-databases.sh` 中添加：

```bash
# Vaultwarden
create_db "vaultwarden" "vaultwarden_secret"

# Outline
create_db "outline" "outline_secret"
```

### 3. 启动服务

```bash
docker compose -f stacks/productivity/docker-compose.yml up -d
```

## Gitea

### 功能

- 私有 Git 仓库
- Pull Request 管理
- Wiki 页面
- OIDC 认证集成

### 访问

- URL: https://git.${DOMAIN}
- 首次访问时配置管理员账户

### SSH 配置

Gitea SSH 端口映射到 2222：

```bash
# Clone with SSH
git clone ssh://git@git.yourdomain.com:2222/username/repo.git
```

### OIDC 认证

Gitea 支持通过 Authentik OIDC 登录：

1. 在 Authentik 中创建 Gitea 应用
2. 在 Gitea 管理面板 -> OIDC -> 添加提供商

## Vaultwarden

### 功能

- 密码存储
- 浏览器扩展
- Bitwarden 兼容 API
- 文件附件支持

### 访问

- URL: https://vault.${DOMAIN}
- 用户注册需管理员开启或使用邀请码

### 管理员界面

- URL: https://vault.${DOMAIN}/admin
- Token: VAULTWARDEN_ADMIN_TOKEN

### 安全设置

Vaultwarden 要求 HTTPS 连接。确保通过 Traefik 访问。

## Outline

### 功能

- Markdown 知识库
- 实时协作
- OIDC 认证
- 文件上传

### 访问

- URL: https://docs.${DOMAIN}
- 使用 Authentik 账号登录

### OIDC 配置

Outline 已配置 Authentik OIDC：
- Client ID: OUTLINE_OAUTH_CLIENT_ID
- Client Secret: OUTLINE_OAUTH_CLIENT_SECRET

### 上传限制

- 最大文件大小: 25MB
- 存储后端: 本地文件系统

## Stirling PDF

### 功能

- PDF 合并/分割
- PDF 转换 (图片、Word、Excel)
- PDF 压缩
- PDF 密码保护
- OCR 识别

### 访问

- URL: https://pdf.${DOMAIN}
- 无需认证，直接使用

### 功能列表

- Merge/Split PDF
- Convert PDF to Images, Word, Excel
- Compress PDF
- Password Protect PDF
- OCR (Optical Character Recognition)
- PDF/A 转换

## Excalidraw

### 功能

- 在线白板
- 实时协作
- 导出 PNG/SVG
- 多人同步编辑

### 访问

- URL: https://draw.${DOMAIN}
- 无需账号，直接使用

## OIDC 认证

所有服务（除 Stirling PDF 和 Excalidraw）都支持通过 Authentik OIDC 单点登录。

### 配置 Authentik

1. 在 Authentik 中创建应用
2. 获取 Client ID 和 Secret
3. 配置重定向 URI

### 用户组权限

| 组 | Vaultwarden | Outline | Gitea |
|----|-------------|---------|-------|
| homelab-admins | 完全访问 | 完全访问 | 完全访问 |
| homelab-users | 基本访问 | 基本访问 | 仓库创建 |
| media-users | 无访问 | 只读 | 无访问 |

## 故障排除

### Vaultwarden 连接失败

1. 确认 HTTPS 配置正确
2. 检查浏览器扩展设置
3. 查看日志: `docker logs vaultwarden`

### Outline OIDC 登录失败

1. 确认 Authentik 应用配置正确
2. 检查 Redirect URI 是否匹配
3. 确认 OUTLINE_OAUTH_CLIENT_ID/SECRET 正确

### Gitea SSH 无法推送

1. 确认 SSH 端口映射: 2222:2222
2. 检查 SSH 密钥配置
3. 查看 Gitea SSH 设置

## 相关文档

- [Gitea 文档](https://docs.gitea.io/)
- [Vaultwarden 文档](https://github.com/dani-garcia/vaultwarden)
- [Outline 文档](https://www.getoutline.com/)
- [Stirling PDF](https://github.com/Stirling-Tools/Stirling-PDF)
- [Excalidraw](https://excalidraw.com/)
