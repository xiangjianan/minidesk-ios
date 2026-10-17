# App Store 截图

2026-10-18：从实际运行的 SwiftUI App 捕获。界面使用调试模拟器中的演示草稿和历史数据；没有向生产服务发送这些演示消息。截图中的“中转已接收”为演示状态，不构成线上收发测试证据。

- iPhone 18 Pro Max：1320 × 2868，提醒、随手记、历史各一张。
- iPad Pro 13-inch (M5)：2064 × 2752，提醒、随手记、历史各一张。
- 保留完整原生屏幕像素，没有重画界面或调整比例。
- 通过 `MINIDESK_SCREENSHOT_SCENE=reminder|note|history` 在 Debug 模拟器构建中生成演示数据；该入口不会编译进真机或 Release 构建。
