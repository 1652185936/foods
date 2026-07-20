# 好好吃饭 Flutter 客户端

移动端优先的 Flutter 原生客户端，首发目标为 Android 与 iOS，同时保留 Windows 和 macOS 构建。客户端使用 Riverpod、Drift/SQLCipher、本地优先仓库、平台安全存储及 OpenAPI 生成的 Dart SDK。

## 环境

- Flutter `3.44.4`（对应 Dart `3.12.x`）
- Android 构建使用 JDK `17`
- Android 最低版本为 API 24
- iOS/macOS 发布需要相应版本的 Xcode 和 Apple 签名身份

仓库使用 Dart workspace。进入客户端目录恢复锁定依赖：

```powershell
cd apps/client
flutter pub get --enforce-lockfile
flutter devices
```

## 连接本地 API

Debug 默认 API origin 为 `http://127.0.0.1:8000`。也可以显式传入相同值：

```powershell
flutter run -d <device-id> `
  --dart-define=ORDIN_API_BASE_URL=http://127.0.0.1:8000 `
  --dart-define=ORDIN_APP_VERSION=1.0.0+1
```

客户端只允许 Debug 使用 `127.0.0.1` 明文 HTTP。不要改用 `10.0.2.2`；Android 模拟器或 USB 真机通过 ADB 将设备回环地址转发到开发机：

```powershell
adb devices
adb -s <device-serial> reverse tcp:8000 tcp:8000
flutter run -d <device-id> --dart-define=ORDIN_API_BASE_URL=http://127.0.0.1:8000
```

只有一个 Android 设备时可以省略 `-s <device-serial>`。iOS Simulator、Windows 和 macOS 开发运行可直接使用本机回环地址。局域网明文 HTTP 会被客户端配置拒绝。

## Release 配置

Release 启动必须同时提供：

- `ORDIN_API_BASE_URL`：只接受没有路径、查询参数或凭据的 HTTPS origin，例如 `https://api.example.com`。
- `ORDIN_APP_VERSION`：发送给服务端的客户端版本，需与发布构建版本一致，最长 32 个字符。

Android AAB 构建示例：

```powershell
flutter build appbundle --release `
  --dart-define=ORDIN_API_BASE_URL=https://api.example.com `
  --dart-define=ORDIN_APP_VERSION=1.0.0+1
```

正式 Android 签名只从进程环境读取以下四项，缺少任意一项都会失败，不会回退到 debug 签名：

| 环境变量 | 用途 |
| --- | --- |
| `ORDIN_ANDROID_KEYSTORE_PATH` | keystore 的本机绝对路径 |
| `ORDIN_ANDROID_KEYSTORE_PASSWORD` | keystore 密码 |
| `ORDIN_ANDROID_KEY_ALIAS` | key alias |
| `ORDIN_ANDROID_KEY_PASSWORD` | key 密码 |

不要把这些值写入命令历史、`--dart-define`、Gradle 文件或仓库。没有完整签名变量时，Android release 构建默认失败关闭。只有无凭据的编译检查可以显式设置 `ORDIN_ALLOW_UNSIGNED_RELEASE_CHECK=1`；该开关生成的产物不能发布。iOS 的 Team ID、证书和 Provisioning Profile 由 Xcode/CI 的安全签名配置提供，仓库不保存这些内容。

## API SDK

SDK 来源为仓库根目录的 `contracts/openapi/ordin-api-v1.json`。生成目录由脚本独占，不应手工修改。

校验提交的 SDK 与契约一致：

```powershell
dart run tool/generate_api_client.dart --check
```

服务端契约有意变更后，从仓库根目录依次执行：

```powershell
uv run --directory server --locked python scripts/export_openapi.py
dart run apps/client/tool/generate_api_client.dart
```

随后重新执行 `--check` 并审查契约与生成代码差异。不要单独运行带过滤条件的 `build_runner`，生成脚本会统一管理 SDK 和其他 Dart 生成文件。

## 检查与构建

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
dart run tool/generate_api_client.dart --check
```

无商店凭据的本地构建检查：

```powershell
$env:ORDIN_ALLOW_UNSIGNED_RELEASE_CHECK = '1'
try {
  flutter build appbundle --release `
    --dart-define=ORDIN_API_BASE_URL=https://api.example.com `
    --dart-define=ORDIN_APP_VERSION=1.0.0+1
} finally {
  Remove-Item Env:ORDIN_ALLOW_UNSIGNED_RELEASE_CHECK
}

flutter build windows --release `
  --dart-define=ORDIN_API_BASE_URL=https://api.example.com `
  --dart-define=ORDIN_APP_VERSION=1.0.0+1
```

iOS/macOS/Windows 构建由对应宿主系统执行。GitHub Actions 中的平台产物只有三天保留期且不含生产签名，不能作为可分发安装包。

## 安全边界

- Refresh Token 和数据库密钥写入平台安全存储，不写入 Drift 数据库。
- SQLite 在打开时验证 SQLCipher；现有数据库缺失密钥时会失败关闭，而不是新建密钥覆盖数据。
- Release API 仅接受 HTTPS；Debug 明文 HTTP 仅限 `127.0.0.1`。
- 生产凭据、OTP 供应商密钥和识别供应商密钥只属于服务端，禁止放入客户端构建。
