# 🚨 灾难恢复指南

## 恢复场景

### 场景 1: 本地文件误删恢复

```bash
# 1. 查看可用快照
docker exec backup-restic restic -r /backups/local snapshots

# 2. 恢复指定快照到临时目录
docker exec backup-restic restic -r /backups/local restore <snapshot-id> --target /tmp/restore

# 3. 复制恢复的文件
docker cp backup-restic:/tmp/restore/data/* /path/to/restore/
```

### 场景 2: 云端恢复（本地磁盘损坏）

```bash
# 1. 使用 B2 恢复
B2_ACCOUNT_ID=xxx B2_ACCOUNT_KEY=xxx docker exec backup-restic \
    restic -r b2:bucket:/ restore latest --target /tmp/restore

# 2. 或使用 R2 恢复
AWS_ACCESS_KEY_ID=xxx AWS_SECRET_ACCESS_KEY=xxx docker exec backup-restic \
    restic -r s3:https://xxx.r2.cloudflarestorage.com/bucket restore latest --target /tmp/restore
```

### 场景 3: 完整系统重建

```bash
# 1. 克隆备份仓库
docker run --rm -v $(pwd)/backups:/backups restic/restic:latest \
    restore latest --repo /backups/local --target /tmp/full-restore

# 2. 复制数据到新系统
scp -r /tmp/full-restore/new-server:/data/
```

### 场景 4: 单文件恢复

```bash
# 从快照中恢复单个文件
docker exec backup-restic restic -r /backups/local restore latest \
    --target /tmp/restore --include /specific/file.txt
```

## 恢复检查清单

- [ ] 确认恢复目标路径有足够空间
- [ ] 确认 Restic 密码正确
- [ ] 检查快照完整性 (`restic check`)
- [ ] 验证恢复的文件 checksum
- [ ] 更新恢复后的文件权限

## 数据完整性验证

```bash
# 检查所有仓库完整性
docker exec backup-restic restic -r /backups/local check

# 使用云端存储检查
docker exec backup-restic env B2_ACCOUNT_ID=xxx B2_ACCOUNT_KEY=xxx \
    restic -r b2:bucket:/ check
```

## 紧急联系

在发生重大数据灾难时：

1. **立即停止写入** - 防止数据覆盖
2. **评估损失** - 确定需要恢复的范围
3. **联系团队** - 通知相关人员
4. **执行恢复** - 按本指南操作
5. **验证数据** - 确认恢复完整性

## 预防措施

- ✅ 定期测试恢复流程（每季度）
- ✅ 保持至少 2 份有效备份
- ✅ 记录关键系统配置
- ✅ 监控备份任务状态
- ✅ 设置自动告警

## 恢复时间目标 (RTO)

| 数据类型 | RTO |
|----------|-----|
| 误删文件 | < 1 小时 |
| 单盘故障 | < 4 小时 |
| 全系统灾难 | < 24 小时 |

## 恢复优先级

1. **关键业务数据** - 数据库、配置文件
2. **用户数据** - 上传的文件、文档
3. **系统数据** - 日志、历史记录