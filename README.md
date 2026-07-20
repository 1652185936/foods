# Ordin 好好吃饭

好好吃饭（技术标识 Ordin）是一个移动端优先、同时保留 Windows 与 macOS 工程的饮食生活应用。当前仓库包含可运行的 Flutter 客户端、FastAPI 业务服务、异步图片识别链路，以及面向生产环境的容器部署基线。

## 技术架构

- 客户端：Flutter `3.44.4`、Riverpod、Drift、SQLCipher、Dio 和由 OpenAPI 生成的类型安全 SDK。
- 账号与本地数据：手机号 OTP 登录、平台安全存储、按账号隔离的加密数据库、本地优先写入、Outbox 幂等同步和冲突处理。
- 服务端：Python `3.14`、FastAPI、SQLAlchemy、Alembic、PostgreSQL、Redis 和 Celery。
- 图片识别：S3 兼容对象存储；本地使用 MinIO；Celery Worker 负责图片校验、去除元数据、调用识别供应商、重试和过期对象清理。
- 发布：Android、iOS、Windows、macOS 构建检查，服务端非 root 容器，以及使用外部 PostgreSQL、Redis、S3 和反向代理网络的生产 Compose。

## 仓库结构

```text
apps/client/          Flutter 客户端
server/               FastAPI API、迁移和 Celery Worker
contracts/openapi/    提交到仓库的 OpenAPI 契约
deploy/               生产 Compose 与无凭据环境变量模板
docs/                 运维、验证和发布门禁文档
assets/app/           应用内图片素材
assets/brand/         品牌源图与平台图标生成脚本
```

产品与架构文档：

- [产品需求设计](./饮食生活App_需求设计文档PRD.md)
- [系统架构与技术选型](./饮食生活App_系统架构与技术选型.md)
- [发布门禁](./docs/RELEASE_READINESS.md)
- [生产运维](./docs/OPERATIONS.md)

## 已实现能力

- “吃什么”“记录”“断食”“我的”四个一级入口，以及适配手机和宽窗口的导航布局。
- 手机号 OTP 登录、Access Token 自动刷新、Refresh Token 轮换、严格受限的离线冷启动与退出登录。
- SQLCipher 加密的餐食、断食和偏好数据；断网时继续使用，恢复网络后自动同步。
- 餐食手动记录、每日汇总、14:10/16:8/18:6 断食计划、跨日和时区恢复。
- 相机/相册选择、直传、异步识别轮询、低置信度复核、人工修正、手工降级和源图持久化清理的完整链路。
- 账号数据 JSON 导出、确认短语注销、远端数据和对象删除，以及本机数据库、凭据与通知清理。
- PostgreSQL 持久化、Redis OTP/限流与队列、Celery Worker/Beat、MinIO 本地对象存储。
- 生产配置失败即关闭、不可变服务端镜像、受限容器运行参数、迁移和回滚操作手册。

尚未完成的发布条件不伪装成工程决策；签名证书、商店主体、生产域名与供应商账号等外部输入集中列在[发布门禁](./docs/RELEASE_READINESS.md)。

## 本地启动

### 完整后端

需要 Docker Desktop。仓库根目录执行：

```powershell
docker compose --profile backend up --build -d
docker compose ps
```

默认端点：

- API：`http://127.0.0.1:8000`
- 健康检查：`http://127.0.0.1:8000/api/v1/health`
- 就绪检查：`http://127.0.0.1:8000/api/v1/ready`
- OpenAPI：`http://127.0.0.1:8000/docs`
- MinIO 控制台：`http://127.0.0.1:9001`

停止服务：

```powershell
docker compose --profile backend down
```

开发环境数据保存在具名卷中；不要使用 `-v`，除非确实要删除本地数据库和对象。

### Flutter 客户端

需要 Flutter `3.44.4`。完整的调试、Android 端口反向代理、发布参数和签名说明见[客户端 README](./apps/client/README.md)。最短启动命令：

```powershell
cd apps/client
flutter pub get --enforce-lockfile
flutter run -d <device-id> --dart-define=ORDIN_API_BASE_URL=http://127.0.0.1:8000
```

Android 模拟器或 USB 真机需先执行 `adb reverse tcp:8000 tcp:8000`。

## 质量检查

从仓库根目录恢复工作区依赖并执行检查：

```powershell
dart pub get --enforce-lockfile
dart run melos run client:check
dart run melos run api:check
dart run melos run server:check
```

服务端外部集成测试还需要 PostgreSQL、Redis 和 MinIO；CI 已创建这些依赖并在迁移后执行测试。已执行的验证及尚未覆盖的验证见[验证记录](./docs/VERIFICATION.md)。

## 生产部署

`deploy/compose.production.yml` 只消费预构建且以 digest 固定的服务端镜像，并要求外部 TLS 入口、PostgreSQL、Redis 和 S3。它不会创建生产基础设施，也不包含任何真实凭据。部署、备份恢复、迁移、回滚和密钥轮换步骤见[运维手册](./docs/OPERATIONS.md)。
