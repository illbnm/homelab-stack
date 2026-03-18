## 任务
Closes #8

## 交付 (7个脚本 + 配置)
- setup-cn-mirrors.sh: Docker镜像加速(交互式)
- localize-images.sh: gcr.io/ghcr.io替换国内镜像 (--cn/--restore/--dry-run/--check)
- check-connectivity.sh: 网络连通性检测
- install.sh: 一键安装 (Ubuntu/Debian/CentOS/Arch)
- wait-healthy.sh: 等待容器健康 + 超时日志
- diagnose.sh: 一键诊断报告
- config/cn-mirrors.yml: 完整镜像映射表
- curl_retry包装函数(指数退避)
