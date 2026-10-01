# Mini Desk for iOS

Mini Desk 的原生移动伴侣：先记下来，回到桌面再继续。

使用 SwiftUI 构建，仅实现移动端。兼容 [Mini Desk 桌面端](https://github.com/xiangjianan/mini-desk) 当前手机速记协议，不需要修改桌面端或服务端。

## 功能

- 扫描桌面配对二维码、输入 12 位配对码或粘贴配对链接。
- 配对前验证服务端状态，配对码保存到设备钥匙串。
- 发送提醒事项或随手记，每行一条，拒绝超长文本而非静默截断。
- 默认原文发送，可启用现有服务端 AI 整理与提醒时间识别。
- 自动保存草稿，保留本机发送记录和失败条目。
- 失败后手动重试，沿用原消息 ID 和原工作区；更换配对不会把旧消息误发给新桌面。
- 系统 Liquid Glass 标签栏、工具栏、`.glass` / `.glassProminent` 按钮及少量 `glassEffect` 装饰。
- 跟随系统深浅色，支持 Dynamic Type、VoiceOver、iPhone 与 iPad。

## 打开运行

1. 用 **Xcode 26 或更新版本**打开 `MiniDesk.xcodeproj`（本项目使用 Xcode 27 / iOS 27 SDK 构建验证）。最低系统为 iOS 26。
2. 选择 `MiniDesk` target，在 Signing & Capabilities 中选择自己的 Team。必要时将 Bundle Identifier 改为个人唯一值。
3. 选择 iPhone / iPad 或已安装运行时的模拟器，运行。
4. 在 [桌面 Mini Desk](https://minidesk.online) 的工作区菜单打开「手机速记」，获取码或二维码。在 App 的「桌面」页配对。
5. 输入内容，选择提醒或随手记，发送。桌面端定时收取，或在桌面执行手动同步。

扫码需真机相机；没有相机的模拟器请手动输入配对码。现有 HTTPS 配对链接支持扫码及粘贴，未配置 Universal Links；自定义链接 `minidesk://pair#inbox=你的配对码` 可直接打开 App 的配对页。

提交的 Xcode 工程可直接打开；无需先安装 XcodeGen。修改工程配置时可运行：

```sh
brew install xcodegen
xcodegen generate
```

## 验证

```sh
swift test
xcodebuild -project MiniDesk.xcodeproj -scheme MiniDesk \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project MiniDesk.xcodeproj -scheme MiniDesk \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

2026-10-01：9 个自动化测试（参数化配对错误测试覆盖 3 个场景）通过；iOS 模拟器 SDK 双架构构建和真机 arm64 构建通过。测试覆盖码规范化、SHA-256 与 Web 协议一致性、嵌套 JSON、时间戳、UTC+8 时区、字符限制、HTTP 状态分类和 URLSession 请求/响应。

**尚未完成运行时和线上联调**：开发环境没有安装 iOS 模拟器运行时；从当前网络请求生产中转服务时 TLS 连接失败。SDK 编译不能代替 UI 运行、相机权限或真机收发验证。请在可访问中转服务的真机上完成以下验收：

- 有效码配对、未知码和已注销码拒绝配对。
- 扫码允许/拒绝相机权限；粘贴 HTTPS 配对链接。
- 提醒和便签各发送单行、多行，桌面同步核对内容。
- 飞行模式发送失败、重启 App 后重试，检查草稿和待发记录保留。
- 更换工作区后旧待发条目不向新工作区发送。
- AI 开关、相对提醒时间、深浅色和大字体。

## 协议与发送语义

协议参考上游 commit `dc13c6cd3db0b863cec523a6dc9fb3f0717bfc10` 的 `src/sync/`、`MobileInboxCapture.vue` 和 `server/app.py`。

默认地址：`https://relay.minidesk.online:8443`，可在 `MiniDesk/Core/Protocol.swift` 中修改 `RelayClient.defaultURL`。

- 12 位 Crockford Base32，去空白并大写，`I/L → 1`、`O → 0`。
- 路由键为规范化配对码的 SHA-256 hex。
- 配对：`GET /inbox/{hash}/status`，仅接受 `active`，网络错误保留原配对。
- 发送：`POST /inbox/{hash}`，外层 `{id, payload}`，`payload` 是 JSON **字符串**，内含 `kind`、`text`、毫秒 `createdAt`、布尔 `polish` 和向东为正的 `tzOffsetMinutes`。
- 15 秒超时，明确区分 400 / 404 / 409 / 410 / 413 / 429 和网络错误。
- “中转已接收”仅代表 HTTP 成功。服务端随后后台入库/整理，现有协议没有桌面已接收回执。桌面通常每 5 分钟拉取，焦点恢复也会触发拉取。
- 未尝试自动重试或后台发送。待发记录由用户在「记录」页重试；断网不会丢弃未发送内容。
- 相同 ID 供服务端覆盖去重使用。但网络超时后若桌面已经收取该 ID，再重试仍可能重新投递，现有协议无法保证端到端 exactly-once。
- 提醒的自然语言时间识别沿用服务端 AI 整理；关闭 AI 时仅原文发送，不额外添加本机通知或日期选择器。

## 数据

配对码使用 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` 钥匙串属性。草稿/AI 偏好保存在 App 自有 UserDefaults，发送记录以 iOS 完全文件保护保存到 Application Support。请求经系统 HTTPS，未关闭证书校验。

**当前协议不是端到端加密**：中转服务可读取消息，AI 开启后服务端模型会处理内容。本 App 不包含广告、分析 SDK 或跟踪。附带 PrivacyInfo.xcprivacy；上架前还需由服务运营者确认服务实际数据留存与 App Store 隐私问卷，并提供正式隐私政策。

本项目未配置开发者签名、TestFlight 或 App Store 发布。
