# Changelog

本文件记录 HR PUSH 的完整更新日志。其他语言版本见 [README_EN.md](README_EN.md) / [README_JA.md](README_JA.md)。

## v1.8.0
- **Redmi/小米手表兼容性**：扫描过滤支持 Redmi 与未命名的心率广播设备；连接超时修复、重连风暴治理（指数退避 + 连续失败上限）、无数据僵尸连接检测、小米轮换 MAC 按名称重连；未找到心率服务时自动弹出「心率广播」开启引导（三语）。
- **设置页全面重构**：按协议分组折叠、全字段行内校验与错误提示、HTTP/WS/OSC/MQTT 一键测试连接、未保存离开确认与保存反馈、OSC 实时推送状态显示、首次使用向导。
- **MQTT 增强**：TLS (mqtts/8883)、密码可见切换、遗嘱主题 (LWT)、稳定默认 Client ID。
- **推送性能**：HTTP 持久连接复用（不再每次推送重建 TCP/TLS）、协议并行扇出（慢端点不再阻塞 VRChat OSC）、WebSocket 指数退避重连、OSC DNS 缓存、`hr_connected` 按状态变化发送。
- **数据格式**：payload 补齐 `event/connected/device` 字段并新增 `heart_rate` 兼容键；连接/断开事件同步推送至 HTTP/WS/MQTT。
- **新增平台特性**：iOS 实时活动（锁屏/灵动岛实时心率，iOS 16.1+）、Windows 托盘最小化后台运行。
- **体验与无障碍**：状态文案全面三语本地化（含 Android 通知）、解除系统字号缩放锁定、语义标签、心率动画渲染优化（RepaintBoundary/固定阴影）。
- **稳定性**：Android 扫描节流自愈、附近设备列表扩容至 15 个并防闪烁、资源释放链修复；移除 5 个死代码模块；测试覆盖 25 → 51 项。

## v1.7.3
- **设置即时生效**：修复 OSC 路径、ChatBox 开关和模板等配置保存后仍沿用旧推送实例的问题，无需重启应用即可生效。
- **回归测试**：新增 PushCoordinator 单元测试，确保 OSC 配置更新后下一次推送立即使用新配置。

## v1.7.2
- **OSC 编码修复**：OSC ChatBox 文本改为 UTF-8 编码，修复 Windows/VRChat 下中文、emoji 或模板文本乱码问题。
- **显示与推送同步**：心率 UI 显示改为跟随最后一次发布快照，确保本机显示值与 VRChat OSC 参数刷新节奏一致。
- **BLE 稳定性增强**：修复部分断连场景下自动重连被阻断的问题；新增 notification 失败后 fallback 到 indication 的订阅策略，提升小米手环等设备兼容性。
- **测试覆盖**：新增 OSC 编码、心率发布快照同步、BLE indication fallback 单元测试。

## v1.7.0
- **CI/CD 优化**：新增 CI 工作流（代码分析 + 测试）；优化 Release 构建时间，合并步骤并移除冗余操作。
- **版本自动同步**：新增 `sync-version.sh` 脚本，发布时自动同步版本号到代码中。
- **文档补充**：新增 `CONTRIBUTING.md` 贡献指南和 `ARCHITECTURE.md` 架构文档。
- **国际化完善**：中/英/日三语种新增 15+ 翻译键值，支持更多 UI 状态本地化。
- **代码架构优化**：新增 `lib/services/` 模块，提取 OSC、MQTT、HTTP/WS 推送服务为独立类。

## v1.6.1
- **Android 优化**：更新 Proguard 规则，优化构建混淆。
- **BLE 适配器微调**：优化 `universal_ble` 适配层，提升连接稳定性。
- **Windows 构建增强**：升级 C++ 标准至 20，并修复编译告警；CI 现在会自动上传 Windows 构建产物。

## v1.6.0
- **BLE 架构升级**：引入 `universal_ble` 库，使用原生 WinRT API 替代不稳定的 `win_ble`，大幅提升 Windows 平台蓝牙连接稳定性。
- **跨平台统一**：新增 BLE 抽象层 (`lib/ble/`)，同一套代码支持 Windows/macOS/iOS/Android/Linux。
- **设备兼容性增强**：支持所有标准 BLE 心率服务 (0x180D) 设备，包括 Polar、Garmin、Wahoo、小米手环等。
- **代码优化**：移除 Windows 专用的连接重试逻辑和设备名编码修复，由统一的 BLE 层处理。

## v1.5.0
- **UI 重构**：首页心率动画重构，采用更自然的仿生“Lub-Dub”跳动节奏与波纹扩散效果。
- **功能增强**：Android 端状态栏通知全新改版为 Native 布局（类似 iOS 实时活动风格），适配 Android 12+ (ColorOS 14) 系统，修复了部分机型不显示通知的问题。
- **兼容性**：修复了小米手环 10 (Xiaomi Smart Band 10) 及部分以 `Mi` / `Xiaomi` 命名的设备无法被扫描到的问题；增加了详细的 BLE 服务发现日志以便排查连接问题。
- **优化**：移除未使用的资源文件，精简代码逻辑。

## v1.4.0
- Android：状态栏/导航栏颜色同步与沉浸式刷新优化（含部分定制 ROM 适配）。
- Android：常驻通知通道与样式升级，权限请求与颜色配置更稳定。
- Android：Play Core 适配 targetSdk 34（迁移至 feature-delivery），Release 构建签名更完整。
- 性能：心率 UI 刷新节流，降低无效重建提升流畅度。
- 工程：全平台包名统一为 `moe.iacg.hrpush`。

## v1.3.4
- OSC：新增 ChatBox 心率推送，支持 `{hr}/{percent}` 模板与节流/去重，避免刷屏。
- UI：设置页新增 ChatBox 开关与模板输入；移除旧的 ChatBox 建议提示文案。
- 文档与仓库：README 结构重构；新增 MIT License；.gitignore 增加本地发布脚本忽略。

## v1.3.3
- UI：应用标题统一为“心率推送”（桌面窗口、应用标题、iOS 显示名、测试文案）。
- UI：主页/配置页布局调整，设置按钮与保存按钮样式统一。
- OSC：推送心率时强制同步在线状态，避免状态滞后。
- Android：常驻通知通道更新，避免旧通道冲突。
- CI：Release 流程移除未签名 iOS 打包步骤。
- Release：发布包命名统一为 `hr-push` 前缀（macOS/Windows）。
- 文档：新增/更新 VRChat 与安卓截图、补充已测试设备清单与 Windows 中文路径已知问题说明。
- 资源：替换主界面/配置页/VRChat 截图。
- 开发：忽略 `.vscode/settings.json`，测试用例标题同步新名称。

## v1.3.1
- Windows：最小化到托盘后支持点击托盘图标恢复窗口。
- Windows：掉线后自动重连更稳定（扫描卡死自愈、广播心率候选识别增强、陈旧连接句柄清理）。
- UI：减少无关重建，整体交互更流畅。
- OSC：`/avatar/parameters/hr_connected` 更贴合实际在线状态（抗抖动与掉线恢复）。

## v1.3.0
- 新增 MQTT 推送（Broker 填写即启用，端口/Topic/鉴权可配）。
- Android 新增通知栏常驻心率卡片，并自动按刷新间隔更新。
- RSSI 轮询刷新间隔与配置一致，连接后持续刷新信号。
- 自动重连逻辑与按钮状态修复，避免重连死锁和重复连接。
- Windows：BLEServer 在中文用户名/路径下运行更稳定（Public ASCII 临时目录 + 正确工作目录）。

## v1.2.2
- Windows：最小化自动隐藏到系统托盘，悬停显示在线状态与心率摘要。
- Android：发布构建启用 R8 混淆、资源压缩与 ABI 分包；Windows/macOS/iOS 开启链接优化以减小体积。

## v1.2.1
- Windows：BLE 连接在数据长时间未更新时会主动重连，提升掉线恢复成功率。

## v1.2.0
- Windows/macOS/Android/iOS 统一使用 `images/logo.png` 生成应用图标。
- Windows：最小化/失焦时暂停心跳动画，降低 GPU 占用；检测心率数据长时间未更新时主动重连。
- README 补充中文路径构建提示。
- 依赖配置同步：`flutter_launcher_icons` 扩展桌面平台支持。
