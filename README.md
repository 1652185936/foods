# 饮食生活助手

一个移动端优先的饮食生活 App，当前处于 Phase 1 开发迭代。仓库采用 Flutter 原生客户端与 Python/FastAPI 服务端的 monorepo 结构，首发目标为 iOS 和 Android，并保留 Windows、macOS 工程。

## 仓库结构

```text
apps/client/          Flutter 客户端
server/               FastAPI 服务端
contracts/openapi/    已提交的 OpenAPI 契约
assets/app/           原型阶段的视觉素材源文件
```

产品需求和架构决策分别见：

- [`饮食生活App_需求设计文档PRD.md`](./饮食生活App_需求设计文档PRD.md)
- [`饮食生活App_系统架构与技术选型.md`](./饮食生活App_系统架构与技术选型.md)

## 当前已实现

- Flutter 自适应应用骨架：手机使用底部导航，较宽窗口使用侧边导航。
- “吃什么”“记录”“断食”“我的”四个可进入的一级页面。
- 本地菜品随机选择、居家推荐与菜谱详情演示。
- 饮食记录概览和拍照识别结果交互演示。
- 14:10、16:8、18:6 断食方案与基于起止时间计算的计时状态。
- FastAPI 应用骨架、`GET /api/v1/health` 健康检查及已提交的 OpenAPI 契约。
- Flutter 与 Python 的格式、静态检查、测试和契约检查 CI。

## 当前边界

- 拍照识别仍是使用内置图片和延时状态的交互演示，尚未调用相机、相册、对象存储或 AI 服务。
- 客户端状态目前保存在内存中；尚未接入 Drift/SQLite、加密持久化、离线同步或账号系统，重启 App 后状态会重置。
- 服务端当前只有最小健康检查；PostgreSQL、Redis、Celery、识别任务、认证和业务 API 尚未实现。
- 客户端尚未接入生成的 Dart API SDK，也未配置商店签名、推送和生产环境发布流程。
- 好友互勉属于后续迭代，不在当前四入口版本中。

## 本地运行

从仓库根目录可通过 Melos 执行统一检查：

```powershell
dart pub get --enforce-lockfile
dart run melos run client:check
dart run melos run server:check
```

### 客户端

需要 Flutter `3.44.4` 及对应 Dart SDK。进入客户端目录后执行：

```powershell
cd apps/client
flutter pub get --enforce-lockfile
flutter devices
flutter run -d <device-id>
```

运行客户端质量检查：

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

### 服务端

需要 CPython `3.14` 和 uv `0.11.29`。进入服务端目录后执行：

```powershell
cd server
uv python install 3.14
uv sync --locked --all-groups
uv run --locked uvicorn ordin.api.main:app --reload
```

开发服务默认提供：

- 健康检查：`http://127.0.0.1:8000/api/v1/health`
- OpenAPI 文档：`http://127.0.0.1:8000/docs`

运行服务端质量检查：

```powershell
uv lock --check
uv run --locked ruff format --check .
uv run --locked ruff check .
uv run --locked mypy src tests scripts
uv run --locked pytest
uv run --locked python scripts/export_openapi.py --check
```

`export_openapi.py --check` 只校验应用生成的 OpenAPI 是否与 `contracts/openapi/ordin-api-v1.json` 一致，不会改写契约文件。
