# Android 发布截图证据

本目录截图采集于 2026-07-20 至 2026-07-21，设备为 `emulator-5554`
Android 14 模拟器，原始分辨率为 1080x2400。页面流程截图于 2026-07-21
通过 `adb reverse tcp:8000 tcp:8000` 和 `adb reverse tcp:9000 tcp:9000`
连接本地 Compose 后端；启动屏与 Launcher 静态证据沿用 2026-07-20 的采集结果。

截图中的账号、手机号、餐食和识别结果均为模拟账号与模拟数据，不包含真实个人信息。
所有 PNG 均为未缩放的模拟器原始截图，用于检查乱码、溢出、异常重叠、资源缺失和
主要操作不可达等问题。

## 截图索引

### 启动与桌面

| 文件 | 页面或状态 |
| --- | --- |
| [`00-splash-immediate.png`](./00-splash-immediate.png) | 原生启动屏首次显示 |
| [`01-splash-ready.png`](./01-splash-ready.png) | 原生启动品牌稳定状态 |
| [`90-launcher-icon.png`](./90-launcher-icon.png) | Android Launcher 图标与应用名称 |

### 登录

| 文件 | 页面或状态 |
| --- | --- |
| [`10-auth-phone.png`](./10-auth-phone.png) | 手机号输入页 |
| [`11-auth-code.png`](./11-auth-code.png) | 验证码输入页 |

### 吃什么

| 文件 | 页面或状态 |
| --- | --- |
| [`20-eat-takeout.png`](./20-eat-takeout.png) | 外卖推荐模式 |
| [`21-eat-home.png`](./21-eat-home.png) | 在家吃推荐模式 |
| [`22-recipe-detail-top.png`](./22-recipe-detail-top.png) | 菜谱详情页顶部 |

### 餐食记录与识别

| 文件 | 页面或状态 |
| --- | --- |
| [`30-meals-empty.png`](./30-meals-empty.png) | 当日暂无记录 |
| [`31-meals-manual-sheet.png`](./31-meals-manual-sheet.png) | 手工记录餐食表单 |
| [`32-meals-home.png`](./32-meals-home.png) | 当日记录与热量汇总 |
| [`33-meals-delete-dialog.png`](./33-meals-delete-dialog.png) | 删除餐食确认框 |
| [`34-meals-recognition-source.png`](./34-meals-recognition-source.png) | 拍照识别来源选择 |
| [`35-meals-recognition-progress.png`](./35-meals-recognition-progress.png) | 餐食识别进行中 |
| [`36-meals-recognition-result.png`](./36-meals-recognition-result.png) | 餐食识别结果复核 |

### 轻断食

| 文件 | 页面或状态 |
| --- | --- |
| [`40-fasting-idle.png`](./40-fasting-idle.png) | 断食计划选择与未开始状态 |
| [`41-fasting-active.png`](./41-fasting-active.png) | 断食进行中 |
| [`42-fasting-stop-dialog.png`](./42-fasting-stop-dialog.png) | 提前结束断食确认框 |

### 我的

| 文件 | 页面或状态 |
| --- | --- |
| [`50-profile-top.png`](./50-profile-top.png) | 个人页、偏好与同步状态 |
| [`51-profile-account.png`](./51-profile-account.png) | 数据导出、账号与登录操作区 |
| [`52-profile-logout-dialog.png`](./52-profile-logout-dialog.png) | 退出登录确认框 |
| [`53-profile-delete-account-dialog.png`](./53-profile-delete-account-dialog.png) | 永久删除账号确认框 |

## 已执行设备检查

```powershell
flutter test integration_test/release_smoke_test.dart -d emulator-5554 `
  --dart-define=ORDIN_API_BASE_URL=http://127.0.0.1:8000

flutter test integration_test/sqlcipher_platform_test.dart -d emulator-5554
```

发布冒烟测试覆盖 OTP 登录、520 kcal 手工餐食、Outbox 推送与拉取、可见的
`数据已同步` 状态、永久删除账号及最终退出登录状态。SQLCipher 平台测试验证了
加密文件头、使用正确密钥重新打开数据库，以及错误密钥的类型化拒绝。

这些截图和检查属于 Android 模拟器工程证据，不能替代 Android 物理设备上的相机厂商
兼容性、权限撤销、后台进程终止、电池策略或商店签名升级测试。
