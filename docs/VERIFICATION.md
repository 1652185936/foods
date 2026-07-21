# 验证记录

本文只记录已经实际执行的工程验证。它不代替商店签名、物理真机验收、
GitHub Actions 结果或 production 演练；相关代码发生变化后必须重跑对应检查。

## 2026-07-20 候选版本

### 服务端

以下检查使用本地 PostgreSQL 18、Redis 7.4 和 MinIO 执行：

| 范围 | 命令或验证 | 结果 |
| --- | --- | --- |
| 依赖锁 | `uv lock --check` | 通过 |
| 格式 | `uv run --locked ruff format --check .` | 114 个文件通过 |
| 静态检查 | `uv run --locked ruff check .` | 通过 |
| 类型检查 | `uv run --locked mypy src tests scripts` | 108 个源文件通过 |
| 完整测试 | 同时启用普通和识别外部依赖测试后运行 `uv run --locked pytest` | `122 passed` |
| OpenAPI | `uv run --locked python scripts/export_openapi.py --check` | 契约一致 |
| 可逆迁移 | 临时测试库执行 `upgrade head -> downgrade base -> upgrade head -> alembic check` | 通过 |
| Compose 重建 | `docker compose --profile backend up --detach --build --wait` | 全部服务健康 |
| 完整黑盒 | `scripts/smoke_api.py` 启用识别与账号注销 | 核心 API、MinIO、Celery、账号隐私链路通过 |
| 受限镜像 | 非 root、只读根文件系统、移除 capabilities、`no-new-privileges` | 导入检查通过，版本 `0.1.0` |
| 生产 Compose | 四个服务均渲染为 `repository@sha256:<64 hex>`，迁移服务仅获得数据库变量 | 通过 |

完整黑盒命令使用一次性测试手机号，覆盖 OTP 登录、记录同步、图片直传、
异步识别轮询、数据导出和账号注销。命令不会输出 token、预签名 URL 或图片内容。

### Flutter 客户端

| 范围 | 命令 | 结果 |
| --- | --- | --- |
| 格式 | `dart format .` 及严格格式检查 | 251 个文件，0 个变化 |
| 静态检查 | `flutter analyze` | `No issues found` |
| 单元与 Widget 测试 | `flutter test` | `238 passed` |
| 生成代码 | `dart run tool/generate_api_client.dart --check` | 生成结果与 OpenAPI 一致 |
| Android AAB 编译检查 | 显式设置 `ORDIN_ALLOW_UNSIGNED_RELEASE_CHECK=1` 后执行 release appbundle 构建 | 通过，71,869,421 字节 |
| AAB 签名边界 | `jarsigner -verify` | `jar is unsigned`，不可分发 |
| Android 签名关门 | 无签名变量且无显式编译检查开关时构建 release AAB | 按预期失败 |

该轮测试覆盖认证并发与离线冷启动、账号隔离、SQLCipher 恢复、同步重试和坏操作
隔离、识别取消/恢复、断食状态和通知、餐食边界、数据导出与账号注销。

### Android 模拟器

设备为 `emulator-5554`、Android 14、1080x2400。以下均在真实 Android 平台插件
和本地 Compose 后端上执行，不是仅运行 Dart VM：

- `integration_test/release_smoke_test.dart`：`1 passed`。覆盖 OTP 登录、手工记录、
  偏好和餐食同步、服务端拉取、同步 UI、确认短语注销、远端 204 与注销后登录状态。
- `integration_test/sqlcipher_platform_test.dart`：`1 passed`。验证数据库文件头已加密、
  正确密钥可重开、错误密钥被类型化拒绝。
- 已人工检查 `docs/evidence/android/` 于 2026-07-20 至 2026-07-21 采集的 22 张
  1080x2400 截图（页面流程采集于 2026-07-21）：
  覆盖启动与登录、推荐与菜谱详情、餐食记录与识别、断食状态、个人页与账号确认操作、
  Launcher 图标，均无乱码、溢出、异常重叠或缺失资源。截图来自连接本地 Compose 后端的
  Android 14 模拟器，仅使用模拟账号和模拟数据，不包含真实个人信息。

这些结果是 Android 模拟器证据，不伪装成物理真机、iOS 或桌面平台证据。

### GitHub Actions

工程提交 `d7b9cd47fd93e223ed9c47c2701f8df6a1e30b4c` 的三组远程流水线均成功：

- [CI](https://github.com/1652185936/foods/actions/runs/29784411611)：Flutter、FastAPI、仓库密钥扫描全部绿色。
- [Platform release build checks](https://github.com/1652185936/foods/actions/runs/29784411410)：Android AAB、iOS 无签名、macOS、Windows release 编译和短期产物上传全部绿色。
- [Server container build check](https://github.com/1652185936/foods/actions/runs/29784411246)：生产镜像构建、受限运行和 digest 固定的生产 Compose 检查绿色。

## 尚需外部环境验证

- Android/iOS 物理真机上的相机、相册、通知授权拒绝/撤销、后台终止、弱网、跨时区、
  DST、系统大字号和屏幕阅读器验收。
- iOS、macOS 和 Windows 的本机 release 编译与运行；当前 Windows 主机未安装
  Visual Studio Desktop C++ 工具链，跨平台编译由远程 CI 复核。
- 使用正式凭据签名的 AAB/IPA 安装、升级、商店上传和分阶段发布。
- staging/production 的备份恢复、迁移、滚动或蓝绿发布、回滚、队列积压、对象清理、
  监控告警和值班演练。
