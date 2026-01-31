# Contributing to HR PUSH

感谢你有兴趣为 HR PUSH 项目做贡献！本文档将指导你完成开发环境设置和代码提交流程。

## 开发环境设置

### 前置要求
- Flutter SDK 3.10+ (建议使用 beta channel)
- Dart SDK 3.0+
- 任意支持 Flutter 的 IDE (VS Code, Android Studio, IntelliJ)

### 克隆与运行
```bash
git clone https://github.com/Ero-Cat/hr_push.git
cd hr_push
flutter pub get
flutter run
```

### 平台特定配置
- **Windows**: 需要支持 BLE 的蓝牙适配器
- **macOS**: 需要 macOS 11+ 和 Xcode 命令行工具
- **Android**: 需要 Android 6.0+ 设备，SDK 34
- **iOS**: 需要 iOS 13+ 设备，Xcode 14+

## 代码风格

- **缩进**: 2 空格
- **行宽**: 不超过 120 字符
- **格式化**: 提交前运行 `dart format .`
- **静态分析**: 确保 `flutter analyze` 无警告

## 提交流程

1. **Fork** 本仓库并创建你的分支
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **开发** 你的功能或修复

3. **测试** 确保代码正常工作
   ```bash
   flutter analyze
   flutter test
   ```

4. **提交** 使用规范的 commit message
   ```
   feat: 添加新功能描述
   fix: 修复问题描述
   docs: 更新文档
   refactor: 代码重构
   ```

5. **推送** 并创建 Pull Request

## 测试

目前项目主要依赖手动测试，因为 BLE 功能需要真实硬件。贡献时请：
- 确保代码通过 `flutter analyze`
- 测试你修改的功能在至少一个平台上正常工作
- 如果添加新功能，更新 README 文档

## 问题反馈

提交 Issue 时请包含：
- 操作系统和版本
- Flutter 版本 (`flutter --version`)
- 心率设备型号
- 问题复现步骤
- 相关日志（设置页开启日志后获取）

## 许可

贡献的代码将采用 MIT License 发布。
