# 全平台心率推送工具

使用 Flutter 构建的跨平台心率推送 / 监控工具，面向直播、舞台、运动监测等需要实时心率数据的场景。

<div align="center">
  <img src="images/logo.png" alt="HR PUSH logo" width="140" />
</div>

## 效果预览

| 首页 | 配置页 |
| --- | --- |
| ![主界面](images/main.png) | ![配置界面](images/settings.png) |

## 核心功能
- **BLE 扫描与过滤**：自动跳过手机/PC 广播，优先匹配包含 180D 心率服务或常见穿戴品牌关键词的设备。
- **智能重连**：记忆最近成功设备，掉线自动重连；支持一键快速连接/断开。
- **实时心率展示**：解析广播/特征值，显示 BPM、更新时间、信号强度（RSSI）。
- **OSC / HTTP 推送**：将心率、在线状态、百分比等数据推送到本地或远端服务，默认 OSC 目标 `127.0.0.1:9000`。
- **调试视图**：查看附近广播名称、RSSI、Service UUID 片段与厂家数据长度，便于排查配对问题。
- **跨端一致性**：Android / iOS / Windows / macOS / Linux 统一 UI；桌面端固定竖屏窗口，方便演示与录屏。

## 快速开始
1. 安装 Flutter 3.10+（Dart 3.10+），并启用目标平台（例如 `flutter config --enable-macos-desktop`）。
2. 获取依赖：`flutter pub get`。
3. （macOS / iOS）进入对应目录执行 `pod install` 以安装 CocoaPods 依赖。
4. 连接测试设备并确保蓝牙已开启，运行：`flutter run -d <device>`。

## 配置项速查
| 配置项 | 说明 | 默认值 |
| --- | --- | --- |
| HTTP/WS 推送地址 | 留空则不推送 | 空 |
| OSC 目标地址 | `host:port` | `127.0.0.1:9000` |
| OSC 路径：在线状态 | 推送设备是否在线 | `/avatar/parameters/hr_connected` |
| OSC 路径：当前心率 | 推送当前 BPM | `/avatar/parameters/hr_val` |
| OSC 路径：心率百分比 | 基于最大心率计算 | `/avatar/parameters/hr_percent` |
| 最大心率 | 计算百分比的分母 | `200` |
| 推送/刷新间隔 (ms) | 节流推送与 UI 更新 | `1000` |

> 提示：若设备仅广播心率而不支持连接，仍可在“广播调试”视图中查看数据与信号强度。

## VRChat
- 默认 OSC 参数插件：https://booth.pm/zh-cn/items/5531594
## 平台支持与权限
- Android：需要开启蓝牙并授予扫描/连接权限（Android 12+ 无需定位，11 及以下需定位权限）。
- iOS / macOS：首次启动会请求蓝牙权限。
- Linux / Windows：需设备具备 BLE 硬件和驱动支持。
- Windows 额外提示：Flutter/CMake 在含中文或空格的路径下构建容易失败，建议将项目放在例如 `C:\\dev\\hr_osc` 的纯英文目录。运行时内置的 BLEServer 会自动解压到 ASCII 目录 `C:\\hr_osc_temp`，避免中文用户名导致的崩溃。
- Web：暂不支持（`flutter_blue_plus` 尚未覆盖 Web）。

## 开发说明
- 应用图标与产品 Logo 均由 `images/logo.png` 生成。
- 主要代码：`lib/main.dart`（UI 与交互）、`lib/heart_rate_manager.dart`（扫描、连接、心率订阅与推送）。
- 代码风格：2 空格缩进，`dart format .`；启用 `flutter_lints`（见 `analysis_options.yaml`）。
- 测试：`flutter test`。当前提供默认测试脚手架，可按需补充 BLE/OSC 逻辑的 mocks/fakes。

## 进阶/规划
- 数据留存与趋势图表（本地存储与导出）。
- 阈值告警（系统通知 / 震动）。
- 多设备偏好与后台保持策略。
- 可配置的浅色主题与更多刷新策略。

## 更新日志
- **v1.2.2**
  - Windows：内置 BLEServer 始终解压到 ASCII 目录 `C:\\hr_osc_temp`，彻底规避中文用户名/路径导致的启动失败。
  - Windows：最小化自动隐藏到系统托盘，悬停显示在线状态与心率摘要。
  - Android：发布构建启用 R8 混淆、资源压缩与 ABI 分包；Windows/macOS/iOS 开启链接优化以减小体积。
- **v1.2.1**
  - Windows：win_ble 临时目录改为 ASCII 路径（`C:\\hr_osc_temp`），解决构建产物放在中文目录或中文用户名下无法运行/崩溃的问题。
  - Windows：BLE 连接在数据长时间未更新时会主动重连，提升掉线恢复成功率。
- **v1.2.0**
  - Windows/macOS/Android/iOS 统一使用 `images/logo.png` 生成应用图标。
  - Windows：最小化/失焦时暂停心跳动画，降低 GPU 占用；检测心率数据长时间未更新时主动重连。
  - README 补充中文路径构建提示。
  - 依赖配置同步：`flutter_launcher_icons` 扩展桌面平台支持。

## 贡献与反馈
欢迎提交 Issue / PR，一起完善 BLE 兼容性与推送链路。若在特定设备或平台遇到问题，请附上日志与环境信息，便于复现。
