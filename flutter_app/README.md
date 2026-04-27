# Banana Flutter App

这是 Banana 面向用户侧的 Flutter 移动端工程骨架。

## 当前范围

当前目录已经按 `prd-app.md` 搭好了第一版基础结构，主要包括：

- `lib/core/`：配置、网络、存储、路由、主题等基础设施
- `lib/features/`：`auth`、`home`、`templates`、`generate`、`history`、`profile`
- `lib/shared/`：共享组件和通用视图能力
- `test/`：基础 smoke test

## 当前说明

用于当前脚手架搭建的机器没有安装 `flutter` CLI，因此这个工程骨架是手工创建的。

这意味着以下内容目前还没有生成：

- `android/`
- `ios/`
- `macos/`
- `linux/`
- `windows/`

也就是说，现在 `lib/`、配置文件和业务骨架已经在，但原生平台壳层还需要后续补齐。

## 下一步建议

等本机安装好 Flutter 后，在 `flutter_app/` 目录下执行：

```bash
flutter create .
```

这个命令会补齐原生平台工程，同时不会覆盖现有 `lib/` 下已经写好的业务骨架。

然后安装依赖：

```bash
flutter pub get
```

## 原生权限说明

图片预览页已经接入了通过 `gal` 保存图片到系统相册的能力。

在执行 `flutter create .` 生成原生目录后，请记得补充对应平台权限：

- iOS：`NSPhotoLibraryAddUsageDescription`
- iOS：`NSPhotoLibraryUsageDescription`
- Android：如果需要兼容较旧系统行为，请按 `gal` 官方说明补充对应配置

## 建议的 dart-define

当前工程通过编译期 `dart-define` 读取环境变量，建议开发时这样运行：

```bash
flutter run \
  --dart-define=APP_ENV=dev \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=IMAGE_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=ENABLE_DIO_LOG=true
```
