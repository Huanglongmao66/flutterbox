# TVBox Flutter

> 原项目 [TVBoxOS](https://github.com/CatVodTVOfficial/TVBoxOSC)（Java/Kotlin，Android TV 影视聚合）的 Flutter 重写版
> 目标：覆盖原项目全部功能，支持 Android + Windows + macOS 三端

## 项目简介

TVBox Flutter 是一个跨平台影视聚合应用，通过站点源（JSON/XML/Spider）聚合多家视频站点内容，提供首页推荐、分类浏览、详情播放、搜索、直播、弹幕字幕、投屏等完整功能。

## 功能特性

### 核心功能
- **站点源聚合**：支持 JSON / XML / Spider（纯 Dart 实现）三种站点源类型
- **首页**：分类导航 + 推荐网格 + 分类分页加载
- **详情页**：影片信息 + 多线路切换 + 剧集列表
- **搜索**：普通搜索 + 快速搜索（多源并发）
- **播放器**：media_kit 渲染（桌面）+ ExoPlayer 平台通道（Android），支持倍速、进度恢复、手势控制
- **直播**：M3U / TXT 频道列表解析，频道分组，多线路切换
- **历史记录**：自动记录播放进度，支持续播
- **收藏管理**：收藏影片，快速访问
- **本地文件**：浏览播放本地视频文件

### 进阶功能
- **弹幕**：Bilibili XML/JSON 格式解析，滚动/顶部/底部三种模式，轨道防重叠，CustomPainter 自绘渲染
- **字幕**：SRT / ASS / SSA / VTT 多格式解析，可配置字号、延迟、开关
- **DLNA 投屏**：纯 `dart:io` 实现 SSDP 设备发现 + SOAP 控制（SetAVTransportURI/Play/Pause/Stop/Seek）
- **推送接收**：内置 HTTP 服务（端口 9978），接收远程指令（推送播放/搜索/URL），维护推送历史
- **远程控制**：通过 `/do?txt=<base64>` 接口接收远程推送，支持 clan 协议文件服务
- **TV 焦点适配**：遥控器方向键导航、确认键激活、焦点高亮、自动滚动可见

## 技术栈

| 类别 | 技术 | 说明 |
| --- | --- | --- |
| 框架 | Flutter 3.44.7 / Dart 3.12 | 跨平台 UI 框架 |
| 状态管理 | Provider + ChangeNotifier | 贴近原项目 ViewModel 风格 |
| 路由 | go_router | 声明式路由 |
| 网络 | dio + http | HTTP 客户端 |
| 本地存储 | hive + shared_preferences | KV 存储（替代 Hawk） |
| 数据库 | drift + sqlite3 | 关系型存储（替代 Room） |
| 图片 | cached_network_image | 图片缓存加载 |
| WebView | webview_flutter | 替代 XWalk，用于嗅探解析 |
| 播放器 | media_kit + ExoPlayer | 桌面用 libmpv，Android 用平台通道 |
| 弹幕 | CustomPainter 自绘 | 滚动/顶部/底部三模式 |
| 字幕 | 自实现解析 | SRT/ASS/SSA/VTT |
| DLNA | 纯 dart:io | SSDP + SOAP，无额外依赖 |
| TV 焦点 | FocusNode + FocusTraversalGroup | 遥控器适配 |

## 目录结构

```
lib/
├── main.dart / app.dart            # 应用入口与初始化
├── core/
│   ├── constants/                  # 常量（AppConstants / HawkConfig）
│   ├── focus/                      # TV 焦点管理（TvFocusable 等）
│   ├── network/                    # dio 封装（HttpClient）
│   ├── storage/                    # hive 封装（HawkStore）
│   ├── theme/                      # 主题（AppTheme / AppColors）
│   └── utils/                      # 工具类（LOG）
├── data/
│   ├── api/                        # ApiConfig 站点源配置管理
│   ├── models/                     # 数据模型（SourceBean / Movie / VodInfo 等）
│   ├── repositories/               # 仓库层（Source / History / Collect / Live）
│   └── spider/                     # 纯 Dart Spider 体系（Json / Xml）
├── features/
│   ├── home/                       # 首页
│   ├── detail/                     # 详情
│   ├── search/                     # 搜索
│   ├── live/                       # 直播
│   ├── player/                     # 播放器
│   ├── history/                    # 历史记录
│   ├── collect/                    # 收藏
│   ├── local/                      # 本地文件
│   ├── settings/                   # 设置
│   ├── push/                       # 推送
│   ├── cast/                       # DLNA 投屏
│   ├── subtitle/                   # 字幕
│   └── danmu/                      # 弹幕
├── routes/                         # go_router 路由配置
├── services/
│   ├── player/                     # 播放器服务（ExoPlayer 通道 + media_kit）
│   └── remote_server.dart          # 远程控制 HTTP 服务
└── widgets/                        # 通用组件（VodCard / 状态占位）
```

## 平台支持

| 平台 | 播放引擎 | 说明 |
| --- | --- | --- |
| Android | ExoPlayer（平台通道）+ media_kit | 主力平台，TV 焦点适配 |
| Windows | media_kit（libmpv） | 桌面端 |
| macOS | media_kit（libmpv） | 桌面端 |

## 快速开始

### 环境要求
- Flutter SDK ≥ 3.44.7
- Dart ≥ 3.12
- Android Studio / Xcode / Visual Studio（按目标平台）

### 运行

```bash
# 安装依赖
flutter pub get

# 运行（Android）
flutter run -d <android-device>

# 运行（Windows）
flutter run -d windows

# 运行（macOS）
flutter run -d macos
```

### 构建

```bash
# Android APK
flutter build apk --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release
```

## 使用说明

1. **首次启动**：进入「设置」→ 配置站点源 API URL
2. **首页**：浏览推荐内容，切换分类查看更多
3. **搜索**：支持多源并发搜索
4. **播放**：点击影片进入详情，选择剧集播放；支持倍速、弹幕、字幕、投屏
5. **直播**：在首页点击「直播」入口，加载直播源后选择频道
6. **远程推送**：应用启动后自动开启远程控制服务（端口 9978），可通过 HTTP 接口推送内容

## 与原项目差异

| 项 | 原项目 | Flutter 版 | 说明 |
| --- | --- | --- | --- |
| JS Spider | Rhino 执行 JS | 纯 Dart 重写 | 无法直接复用 JS 站点源生态 |
| IJK Player | IJK | ExoPlayer + media_kit | 部分加密 m3u8 兼容性可能下降 |
| 迅雷 P2P | 原生 SDK | 替代方案 | 丢失迅雷加速能力 |
| XWalk | XWalk WebView | webview_flutter | 嗅探解析 |
| DLNA | 第三方库 | 纯 dart:io | 自实现 SSDP + SOAP |

## 开发文档

详细的开发计划与进度记录见 [docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md)。

## 许可证

本项目仅供学习交流使用，不得用于商业用途。
