# V1 发布门禁

本清单只把有代码和可复核验证结果支持的项目标记为完成。仓库内存在实现但没有运行证据、曾在旧工作树通过但当前又发生相关修改、或必须在真实账号/设备/环境中执行的项目均保持未勾选。

验证明细见[验证记录](./VERIFICATION.md)，生产操作见[运维手册](./OPERATIONS.md)。

## 已验证工程基线

### 客户端数据、认证与同步

- [x] 客户端只有“吃什么、记录、断食、我的”四个一级入口，没有好友、排行、会员等占位入口。证据：[导航实现](../apps/client/lib/app/shell/app_shell.dart)，候选版本 `flutter test` 为 `238 passed`。
- [x] Drift 数据库、SQLCipher 构建 hook、数据库版本迁移和缺失/非法密钥失败关闭已实现。证据：[workspace hook](../pubspec.yaml)、[数据库打开逻辑](../apps/client/lib/core/db/database_connection.dart)、[迁移测试](../apps/client/test/core/db/app_database_migration_test.dart)、[密钥测试](../apps/client/test/core/security/database_key_store_test.dart)。
- [x] Refresh Token、最小离线身份缓存与数据库密钥分别进入平台安全存储，按账号隔离的本地数据不会在切换账号时复用 Provider 状态。证据：[认证安全存储](../apps/client/lib/core/auth/secure_auth_token_store.dart)、[数据库密钥存储](../apps/client/lib/core/security/database_key_store.dart)、[账号作用域测试](../apps/client/test/features/auth/authenticated_account_scope_test.dart)。
- [x] 餐食、断食和偏好使用本地仓库与 Outbox；同步实现幂等写入、版本冲突、tombstone、分页游标及按账号隔离。证据：[同步引擎](../apps/client/lib/core/sync/sync_engine.dart)、[同步测试](../apps/client/test/core/sync/sync_engine_test.dart)、[本地仓库测试](../apps/client/test/core/db/local_repositories_test.dart)。
- [x] 同步协调器在认证账号作用域内运行，并覆盖首次登录/恢复、App resume、网络恢复、单飞、有限重试、销毁订阅和个人页手动重试；合法 `400/422` 坏操作会隔离为可观察冲突，不再永久阻塞后续 push/pull。证据：[同步协调器](../apps/client/lib/core/sync/sync_coordinator.dart)、[同步引擎](../apps/client/lib/core/sync/sync_engine.dart)、[同步测试](../apps/client/test/core/sync/sync_engine_test.dart)。
- [x] 手机号 OTP 登录、Token 刷新单飞、登出和登录恢复已接入；Release API 配置缺失或非 HTTPS 时失败关闭。证据：[认证仓库](../apps/client/lib/core/auth/auth_repository.dart)、[API origin 配置](../apps/client/lib/core/auth/api_base_url_config.dart)、`flutter test` 基线中的认证测试。
- [x] Dart API SDK 由提交的 OpenAPI 契约统一生成，并可在隔离临时目录中检查是否漂移。证据：[生成脚本](../apps/client/tool/generate_api_client.dart)，`dart run tool/generate_api_client.dart --check` 已通过。
- [x] 本地时间使用 IANA 时区并覆盖 DST、跨日、恢复和到期断食重算。证据：[时区转换](../apps/client/lib/core/time/time_zone_converter.dart)、[生命周期测试](../apps/client/test/core/bootstrap/app_lifecycle_coordinator_test.dart)、[时区测试](../apps/client/test/core/time/time_zone_converter_test.dart)。
- [x] 仅在明确网络不可达时允许同账号离线冷启动；401/403/422、5xx、协议错误和跨账号 epoch 均不会使用缓存身份兜底。证据：[认证仓库](../apps/client/lib/core/auth/auth_repository.dart)及认证/网络测试。
- [x] 相机/相册、图片本地校验、直传对象存储、识别轮询、低置信度/多菜修正、手工降级和保存餐食闭环已实现；取消、lost-data、上传失败和账号切换恢复均有测试。证据：[识别界面](../apps/client/lib/features/meals/presentation/recognition_sheet.dart)及[识别测试](../apps/client/test/features/meals/recognition_sheet_test.dart)。
- [x] 数据导出、确认短语注销、远端删除、六类本地数据清理、通知/token/session 清理和清理失败重试已实现。证据：[账号隐私控制器](../apps/client/lib/features/profile/application/account_privacy_controller.dart)及[账号隐私测试](../apps/client/test/features/profile/account_privacy_controller_test.dart)。

### 服务端与数据链路

- [x] PostgreSQL、Redis、MinIO、FastAPI、Celery Worker 和 Beat 已接入本地 Compose，API 到异步识别任务的真实依赖链路完成 smoke test。证据：[开发 Compose](../compose.yaml)；`scripts/smoke_api.py` 普通模式及 `--include-recognition` 黑盒 smoke 均通过，详见[验证记录](./VERIFICATION.md)。
- [x] Alembic 能在临时空库执行 `upgrade head -> downgrade base -> upgrade head`，最终 `alembic check` 通过。证据：[迁移目录](../server/migrations/versions/)、[验证记录](./VERIFICATION.md)。
- [x] OTP、会话轮换、用户/健康资料、餐食、断食、同步和识别接口已进入 OpenAPI。证据：[提交的契约](../contracts/openapi/ordin-api-v1.json)，`uv run --locked python scripts/export_openapi.py --check` 已通过。
- [x] 同步写接口覆盖幂等、版本冲突、tombstone 和用户边界；用户不能读取其他账号的记录。证据：[记录 API 集成测试](../server/tests/integration/test_records_api.py)、[用户 API 集成测试](../server/tests/integration/test_users_api.py)，完整服务端测试 `122 passed`。
- [x] 上传链路校验大小、SHA-256、MIME、文件魔数、解码尺寸和单帧格式，并重新编码移除 EXIF/其他元数据。证据：[图片净化实现](../server/src/ordin/infrastructure/image_processing.py)、[图片测试](../server/tests/unit/test_image_processing.py)、[识别集成测试](../server/tests/integration/test_recognition_external.py)。
- [x] 识别 Worker 覆盖幂等 claim、低置信度复核、有界重试、最终失败、原图删除重试、源对象过期清理及注销并发下的持久化对象清理。证据：[Worker 测试](../server/tests/unit/test_recognition_worker.py)、[识别服务测试](../server/tests/unit/test_recognition_service.py)，完整服务端测试 `122 passed`。
- [x] 服务端格式、lint、类型、外部依赖测试和契约检查在含 PostgreSQL/Redis/MinIO 的环境全部通过。证据：[验证记录](./VERIFICATION.md)：Ruff、mypy、pytest `122 passed`、OpenAPI check 均通过。

### 发布工程基线

- [x] 通用 CI 固定 Flutter/Python/uv 版本，恢复锁文件，启动 PostgreSQL/Redis/MinIO，执行迁移、客户端/服务端测试与契约检查。证据：[CI 工作流](../.github/workflows/ci.yml)。该项只证明工作流定义已进入仓库，不代表当前提交的 GitHub run 已成功。
- [x] Android、iOS 无签名、Windows、macOS 的 release-mode 编译检查已进入独立 CI，产物明确标记为不可分发。证据：[平台构建工作流](../.github/workflows/platform-builds.yml)。
- [x] 本地 Android release AAB 编译检查已通过；产物经 `jarsigner` 确认为未签名，缺少签名变量且不开显式检查开关时构建会失败关闭。证据：[验证记录](./VERIFICATION.md)。
- [x] Android 14 模拟器已完成 OTP、餐食、同步、识别依赖链路、数据导出/注销和 SQLCipher 平台测试，并人工检查 9 张 1080x2400 截图。证据：[Android 证据](./evidence/android/README.md)。
- [x] 服务端镜像以非 root 用户运行；CI 检查只读文件系统、移除 capabilities 和 `no-new-privileges`。证据：[Dockerfile](../server/Dockerfile)、[镜像构建工作流](../.github/workflows/server-image-build.yml)。
- [x] 生产 Compose 由仓库名和 64 位 SHA-256 强制构造 `repository@sha256:digest`，并使用外部 TLS 入口和托管 PostgreSQL/Redis/S3，设置只读根文件系统、资源限制、健康检查、滚动更新和回滚策略。证据：[生产 Compose](../deploy/compose.production.yml)及[镜像工作流](../.github/workflows/server-image-build.yml)。
- [x] production/staging 配置拒绝 HTTP origin、无 TLS 数据库/Redis、弱密码、开发 OTP 与模板凭据。证据：[服务端配置](../server/src/ordin/infrastructure/config.py)、[安全配置测试](../server/tests/unit/test_security_config.py)。
- [x] 数据库迁移、备份/恢复、健康检查、识别 smoke、回滚、队列积压、对象清理和密钥轮换均有可执行运维步骤。证据：[运维手册](./OPERATIONS.md)。该项只证明 runbook 已具备，不代表 staging/production 已演练。
- [x] 工程提交 `d7b9cd4` 的 GitHub `CI`、`Platform release build checks` 和 `Server container build check` 全部绿色；Android、iOS、Windows、macOS 和服务端镜像均有远程构建证据。证据：[验证记录](./VERIFICATION.md)。

## 当前仍需工程验证或实现

- [ ] 断食完成通知在 Android/iOS/macOS/Windows 实际调度、取消并在冷启动后重建，拒绝/撤销权限时不影响数据库已提交状态。
- [ ] 在 iOS、Windows、macOS 实际安装运行，验证 SQLCipher 已加载、数据库文件不可明文读取、错误密钥失败、升级读取和安全存储丢失恢复；Android 模拟器的加密文件、重开和错误密钥已通过。
- [ ] Android/iOS 真机覆盖相机、相册、通知权限拒绝/撤销、后台终止、冷启动、弱网、跨日、DST 和账号切换；Windows/macOS 完成核心桌面 smoke。
- [ ] 在物理 Android/iOS 上复跑核心端到端流程；Android 模拟器到真实 API、对象存储、Worker、同步和账号注销的整链路已通过。
- [ ] 完成系统大字号、屏幕阅读器语义、对比度和不小于 44x44 pt 触控目标的真机无障碍验收。
- [ ] 在 staging 执行备份恢复、迁移、识别队列积压、过期对象清理、旧客户端兼容、滚动发布和回滚演练。
- [ ] 生成带正式签名、版本号和校验值的 AAB/IPA，并保存源码提交、锁文件和构建记录；当前 CI artifact 不能发布。

## 仅能由用户或组织提供的外部输入

以下项目不是普通工程实现选择。其余代码结构、测试方式、错误处理、数据库与部署细节由开发流程自主完成，不再要求用户逐项决策。

### 签名与商店主体

- [ ] Apple Developer/App Store Connect 组织、Team ID、Distribution 证书、Provisioning Profile 和受保护的 CI 签名凭据。
- [ ] Google Play Console 组织、Play App Signing 或正式 upload keystore，以及需要自动发布时的服务账号。
- [ ] 最终产品/商店展示名称、Android application ID、Apple bundle ID、品牌和图标的合法所有权确认。
- [ ] 商店截图、描述、支持联系方式、年龄分级、隐私问卷、审核账号及最终人工提审。

### 生产基础设施

- [ ] 容器仓库与固定 image digest、生产域名/DNS/TLS、反向代理网络，以及 CDN（如使用）的组织账号。
- [ ] 托管 PostgreSQL、Redis、S3 兼容私有对象存储、Secret Manager 的连接信息与最小权限身份。
- [ ] 备份保留策略与可用恢复点；RPO/RTO 由业务责任人接受后才能作为生产 SLO。

### 外部供应商与数据授权

- [ ] 手机 OTP 供应商账号、签名/模板审批、生产配额、Webhook 凭据和故障联系人。
- [ ] 图片识别供应商的生产 endpoint/token、区域、配额、数据保留/训练条款和故障联系人。
- [ ] 菜品与营养数据的合法许可证、数据文件或 API 凭据，以及允许缓存、修改和向用户展示的用途范围。

### 法律、隐私与运营责任

- [ ] 运营主体、首发地区、隐私政策、服务条款、公开 URL、支持邮箱和第三方处理者清单由合格负责人提供。
- [ ] 健康/营养估算免责声明、账号注销/数据导出/删除时限、图片保留说明和跨境处理要求由法律/隐私负责人确认。
- [ ] 观测供应商生产项目、采集范围、访问凭据、告警接收渠道和实际值班人员；代码不能代替组织建立值班责任。

## 最终上线门禁

- [ ] 上述“当前仍需工程验证或实现”全部关闭，并附当前提交的 CI、真机、E2E、staging 演练记录。
- [ ] 所有适用于首发地区和渠道的外部输入已通过 Secret Manager、签名系统或正式文档交付，仓库中不存在真实凭据。
- [ ] production 迁移前备份成功，部署后 `/api/v1/health`、`/api/v1/ready`、OTP、同步、上传与识别 Worker smoke 全部通过。
- [ ] 签名 AAB/IPA 的版本、校验值、源码提交和依赖锁可追溯，分阶段发布比例、暂停条件与回滚负责人已记录。
- [ ] 上线后的 API 延迟/错误率、识别队列、同步失败、对象清理、崩溃与 ANR 告警已接入真实值班入口。
