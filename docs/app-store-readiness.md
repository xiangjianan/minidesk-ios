# App Store 发布检查

检查日期：2026-10-18。`1.0.0 (1)`、`1.0.0 (2)` 均已成功上传 Apple，尚未提交审核或上架。

## 最新进展

- 已创建 App Store Connect 应用记录，Apple ID `6823998088`，SKU `minidesk-ios`。
- 已保存简体中文介绍、推广文本、关键词、支持/营销网址、副标题及效率分类。
- 用户确认新版 Apple Developer Program 协议已接受。
- 已核实开发者团队 `4B4U2WGR79`，工程与 XcodeGen 配置均使用该团队和自动签名。
- 签名归档成功：`/tmp/MiniDesk-AppStore-Signed.xcarchive`。
- App Store 分发导出成功：`/tmp/minidesk-appstore-export/MiniDesk.ipa`。
- 上传日志确认 `Upload succeeded`；TestFlight 页面已显示 `1.0.0 (1)`，后续已处理完成；构建可用不等于审核通过。
- 已完成 Xcode 必需组件安装，模拟器重新可用，已完成截图及 AI 确认弹窗的 UI 验证。
- 免费定价已保存，基准为中国大陆 CNY ¥0.00；发行范围已保存为仅中国大陆（1 个国家或地区）。用户尚未完成 App 备案，先完成其余准备。
- 正式隐私政策已发布并验证 HTTP 200：https://xiangjianan.github.io/minidesk-ios/ 。通过独立 `gh-pages` 分支发布，`site/index.html` 保留同一网页源码。
- 用户确认运营主体为项佳男，隐私邮箱为 xiang9872@126.com，中转服务器位于成都，使用 DeepSeek，消息约 30 天清理。
- 政策网址已保存到 App Store Connect；应用内配对前、配对后均已添加入口。
- 已添加开启 AI 前的 DeepSeek 告知与确认弹窗，实际模拟器窗口验证可显示。
- iPhone 1320 × 2868、iPad 2064 × 2752，各三张原生截图（提醒、随手记、历史）已上传，后台均显示 3/10。
- 截图使用 Debug 模拟器中的演示内容，不能作为生产服务成功收发的证据。
- Build 2 签名归档成功并上传成功：`/tmp/MiniDesk-AppStore-Build2.xcarchive`，日志 `/tmp/minidesk-appstore-build2-upload.log`。Apple 已处理完成，已选为 1.0.0 的审核构建；设备预览图标已验证正常显示。
- 本次同步包含签名配置、版本号、政策入口、AI 告知和截图数据入口。截图入口仅在 Debug 模拟器编译，不进入 Release。
- 年龄分级问卷已保存，系统计算为 4+（部分地区使用本地分级）。
- 审核联系人已保存；“需要登录”已关闭，审核说明写明使用配对码，无账户登录。私人联系电话不保存在本仓库。

## 已验证

- Bundle ID：`online.minidesk.ios`；最新归档版本：`1.0.0 (2)`。
- iOS 26 起，支持 iPhone 和 iPad。
- Release 真机架构无签名归档成功：`/tmp/MiniDesk-AppStore.xcarchive`。此归档用于编译验证，不能直接作为已签名上传包。
- `swift test`：13 项通过。
- App Store 图标为 1024 × 1024 PNG，无透明通道。
- 包含相机用途说明、隐私清单，以及非豁免加密声明。

## 当前阻塞

1. 中国大陆发行所需 App ICP 备案尚未完成。不能据此宣布可在大陆上架。
2. 尚未完成 TestFlight / 真机端到端收发验证。
3. 内容版权和隐私标签尚未完成。
4. 从当前 Mac 访问 `https://relay.minidesk.online:8443` 时 TLS 连接失败。该结果只证明本机此刻连接失败；提交前需在可用网络完成配对、发送和桌面收取验证。
5. 未准备持续有效的审核专用配对码。应用未配对时无法进入核心功能，需为审核提供可用工作区、配对信息和操作说明。

## 继续准备

- 完成内容权利及隐私问卷。
- 隐私问卷须结合服务端事实填写：消息内容会发送到中转服务，用户开启 AI 时还会被服务端模型处理；不能仅凭无广告或分析 SDK 就声明不收集数据。
- 原始截图与说明位于 `outputs/app-store-screenshots/`。
- 完成真机收发、离线重试、相机权限与审核路径验证。
- 等待已上传构建处理，先验证 TestFlight，再提交审核；最终上架取决于备案信息及 Apple 审核结果。

## Apple 参考

- https://developer.apple.com/app-store/submitting/
- https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
