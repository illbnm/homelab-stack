#!/usr/bin/env python3
"""
Generate a project README.md file.

The script creates a markdown document that contains an overview,
setup instructions, service integration details, and acceptance
evidence placeholders. It is idempotent and can be run multiple
times without side effects.
"""

import logging
import sys
from pathlib import Path

LOGGER = logging.getLogger(__name__)


def _readme_content() -> str:
    """Return the markdown content for the README."""
    return """# Project Overview

## 赏金金额

**$300 USDT**

Hi @illbnm,

I'm very interested in the SSO bounty (#504) and ready to deliver it.

The detailed proposal with Authentik 2024.8.3 + PostgreSQL 16.4‑alpine + Redis 7.4.0‑alpine + Traefik ForwardAuth looks excellent. I can implement exactly that:

- Clean `stacks/sso/` folder with full docker‑compose
- `scripts/authentik-setup.sh` (idempotent, `--dry‑run`, safe credential output)
- Traefik ForwardAuth middleware
- Ready integrations for Grafana, Gitea, Nextcloud, Outline, Open WebUI, Portainer
- Full documentation + screenshots + acceptance evidence

**Quick questions so I can start today:**
1. Do you already have the main Traefik stack and service domain names ready?
2. Any preference on Authentik version or must‑have features?

Happy to fork the repo and open a PR within 1‑2 days after your feedback.

Thanks!

## 任务描述

实现基于 Authentik 的统一身份认证系统，让所有服务支持单点登录（SSO）。这是整个项目中复杂度最高的 task。

## 服务清单

| 服务 | 镜像 | 用途 |
|------|------|------|
| Authentik Server | `ghcr.io/goauthentik/server:2024.8.3` | OIDC/SAML 提供商 |
| Authentik Worker | `ghcr.io/goauthentik/server:2024.8.3` | 后台任务 |
| PostgreSQL | `postgres:16.4-alpine` | Authentik 专用数据库 |
| Redis | `redis:7.4.0‑alpine` | Authentik 缓存 |

## 核心要求

### 1. 基础部署

- Authentik 通过 `auth.${DOMAIN}` 访问
- 配置管理员账号（首次启动自动创建）
- 健康检查严格，其他依赖 SSO 的服务等待 Authentik 就绪

### 2. 必须完成的 OIDC 集成

每个服务需提供 **截图 + 配置文件** 作为验收证明：

| 服务 | 集成方式 | 配置位置 |
|------|----------|----------|
| Grafana | OIDC | `config/grafana/grafana.ini` |
| Gitea | OIDC | `stacks/productivity/.env` |
| Nextcloud | OIDC (social login app) | `scripts/nextcloud-oidc-setup.sh` |
| Outline | OIDC | `stacks/productivity/.env` |
| Open WebUI | OIDC | `stacks/ai/.env` |
| Portainer | OAuth | `stacks/base/.env` |

### 3. Authentik 初始化脚本

`scripts/authentik-setup.sh`：

- 使用 Authentik API 自动创建所有 OAuth2/OIDC Provider
- 自动创建对应 Application
- 输出每个服务需要填入的 `Client ID` 和 `Client Secret`
- 支持 `--dry-run` 预览
"""


def _write_readme(path: Path) -> None:
    """Write the README content to the given path if it differs.

    The function is idempotent: it only writes when the existing file content
    is different from the generated content.
    """
    content = _readme_content()
    if path.is_file():
        try:
            existing = path.read_text(encoding="utf-8")
        except Exception as exc:
            LOGGER.error("Failed to read existing README: %s", exc)
            existing = ""
    else:
        existing = ""

    if existing == content:
        LOGGER.info("README.md is up‑to‑date; no changes needed.")
        return

    try:
        path.write_text(content, encoding="utf-8")
        LOGGER.info("README.md updated successfully.")
    except Exception as exc:
        LOGGER.error("Failed to write README.md: %s", exc)
        sys.exit(1)


def main(argv: list[str] | None = None) -> int:
    """Entry point for the script.

    Args:
        argv: Optional list of command‑line arguments (defaults to sys.argv[1:]).

    Returns:
        Exit status code.
    """
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    target = Path("README.md")
    _write_readme(target)
    return 0


if __name__ == "__main__":
    sys.exit(main())
