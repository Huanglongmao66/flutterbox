# TVBox Flutter 重写开发计划

> 原项目：TVBoxOS（Java/Kotlin，Android TV 影视聚合）
> 目标：使用 Flutter 重写，覆盖原项目全部功能
> 平台：Android + Windows + macOS
> 启动日期：2026-08-05

## 一、关键决策（已与用户确认）

| 项 | 决策 | 说明 |
| --- | --- | --- |
| 目标平台 | Android + Windows/macOS 桌面 | 不含 iOS |
| 播放引擎 | Android 用 ExoPlayer 平台通道；桌面用 `media_kit`（libmpv） | 上层抽象统一 `VideoPlayerService` 接口 |
| JS Spider | 纯 Dart 实现 | 不复用原 JS，需用 Dart 重写站点源解析逻辑；保留 CSP/JSON 接口形态 |
| 迅雷 P2P | 替代方案 | 用 WebRTC / HTTP-P2P 社区方案，丢失原迅雷加速能力 |
| XWalk | WebView 替代 | `webview_flutter` + JS 注入实现嗅探解析 |
| DLNA | 社区库实现 | `dlna_dart` / 自封装 UPnP |
| 原生强依赖 | 全部保留，原生通道实现 | 必要时写 MethodChannel/Platform Channel |

## 二、技术栈

- **Flutter SDK**: 3.44.7 / Dart 3.12
- **状态管理**: Provider + ChangeNotifier（贴近原项目 ViewModel 风格）
- **路由**: go_router
- **网络**: dio + http
- **本地存储**: hive（替代 Hawk）+ drift（替代 Room）
- **图片**: cached_network_image
- **JS 执行**: 纯 Dart 重写，不引入 JS 引擎
- **播放器**: 平台通道 ExoPlayer（Android）+ media_kit（桌面）
- **WebView**: webview_flutter
- **DLNA**: dlna_dart 或自封装
- **弹幕**: 自绘 CustomPainter
- **字幕**: 自实现 SRT/ASS 解析 + 自绘
- **TV 焦点**: Flutter FocusNode + 自封装焦点树

## 三、目录结构

```
lib/
  main.dart
  app.dart                       # MaterialApp 入口
  core/
    constants/                   # 常量
    theme/                       # 主题
    utils/                       # 工具类
    network/                     # dio 封装
    storage/                     # hive/drift 封装
    focus/                       # TV 焦点管理
  data/
    models/                      # 数据模型（对应原 bean）
    api/                         # ApiConfig 等价
    spider/                      # 纯 Dart Spider 体系
    db/                          # 数据库
    repositories/
  features/
    home/                        # 首页
    detail/                      # 详情
    search/                      # 搜索 + 快速搜索
    live/                        # 直播
    player/                      # 播放器
    history/                     # 历史
    collect/                     # 收藏
    settings/                    # 设置
    local/                       # 本地文件
    push/                        # 推送
    cast/                        # DLNA 投屏
    subtitle/                    # 字幕
    danmu/                       # 弹幕
  widgets/                       # 通用组件
  routes/                        # 路由配置
  services/                      # 全局服务（播放器、控制服务等）
platforms/
  android/...                    # ExoPlayer 平台通道
  windows/...                    # media_kit 桥
  macos/...
```

## 四、功能映射表（原 → 新）

| 原项目类 | Flutter 对应 | 说明 |
| --- | --- | --- |
| `ApiConfig` | `data/api/api_config.dart` | 站点源、解析接口、直播源加载 |
| `SourceBean` | `data/models/source_bean.dart` | 站点源数据模型 |
| `Movie` / `VodInfo` | `data/models/movie.dart` / `vod_info.dart` | 影片信息 |
| `MovieSort` | `data/models/movie_sort.dart` | 分类 |
| `Spider` / `JarLoader` / `JsLoader` | `data/spider/*` | 纯 Dart 重写爬虫 |
| `HomeActivity` | `features/home/home_page.dart` | 首页 |
| `DetailActivity` | `features/detail/detail_page.dart` | 详情 |
| `SearchActivity` / `FastSearchActivity` | `features/search/*` | 搜索 |
| `LivePlayActivity` | `features/live/live_page.dart` | 直播 |
| `PlayFragment` + `MyVideoView` | `features/player/*` | 播放器 |
| `HistoryActivity` | `features/history/history_page.dart` | 历史 |
| `CollectActivity` | `features/collect/collect_page.dart` | 收藏 |
| `SettingActivity` | `features/settings/settings_page.dart` | 设置 |
| `LocalFileActivity` | `features/local/local_file_page.dart` | 本地 |
| `PushActivity` | `features/push/push_page.dart` | 推送 |
| `DLNACastManager` | `features/cast/*` | 投屏 |
| `SubtitleLoader` | `features/subtitle/*` | 字幕 |
| `DanmuHelper` | `features/danmu/*` | 弹幕 |
| `RemoteServer` / `ControlManager` | `services/remote_server.dart` | 远程控制 |
| `Hawk` | `core/storage/hawk_store.dart` | KV 存储 |
| `AppDataBase` (Room) | `data/db/app_database.dart` (drift) | 数据库 |

## 五、开发阶段

### 阶段 1：基础架构（进行中）
- 项目骨架、依赖、主题、路由、存储、网络、日志
- 数据模型层（Source/Movie/VodInfo/Sort/Parse 等）
- ApiConfig 等价实现（站点源加载、JSON 解析）
- 远程控制服务骨架

### 阶段 2：Spider 体系
- Spider 抽象接口
- JsonSpider（CSP/JSON 站点）
- XmlSpider（XML 站点）
- 站点源默认配置

### 阶段 3：首页 + 详情 + 搜索
- 首页分类导航 + 网格
- 详情页（信息、剧集、源切换）
- 搜索页（普通 + 快速搜索）

### 阶段 4：播放器
- 平台通道 ExoPlayer（Android）
- media_kit 桌面桥
- 播放控制 UI（进度、倍速、轨道、手势）
- 解析接口嗅探（WebView）

### 阶段 5：历史 / 收藏 / 本地 / 设置
- 历史记录、收藏、本地文件
- 设置（API、解析、弹幕、备份、关于）

### 阶段 6：直播
- 频道列表、EPG、节目单
- 直播设置、源切换、IJK 替代

### 阶段 7：弹幕 / 字幕
- 弹幕加载与渲染
- 字幕解析与渲染（SRT/ASS 等）

### 阶段 8：投屏 / 推送 / 远程控制
- DLNA 投屏
- 推送接收
- 远程控制 Web 服务

### 阶段 9：原生强依赖功能
- 迅雷 P2P 替代方案
- 其他平台通道补全

### 阶段 10：TV 焦点适配与优化
- 遥控器焦点导航
- 性能优化、打包

## 六、开发进度记录

| 日期 | 阶段 | 进度 | 备注 |
| --- | --- | --- | --- |
| 2026-08-05 | 阶段 1 | 完成 | 项目骨架、依赖、core 层、数据模型、ApiConfig、Spider、路由、入口、首页、详情、设置 |
| 2026-08-05 | 阶段 2 | 完成 | Spider 抽象 + JsonSpider + XmlSpider + SpiderLoader |
| 2026-08-05 | 阶段 3 | 完成 | 首页/详情/搜索（普通搜索 + 快速搜索） |
| 2026-08-05 | 阶段 4 | 完成 | 播放器（media_kit 渲染 + ExoPlayer 平台通道 + 控制UI + 倍速 + 恢复进度） |
| 2026-08-05 | 阶段 5 | 完成 | 历史/收藏/本地文件/设置（API、解析、弹幕、备份） |
| 2026-08-05 | 阶段 6 | 完成 | 直播（频道分组、M3U/TXT 解析、播放） |
| 2026-08-05 | 阶段 7 | 完成 | 弹幕（滚动/顶部/底部 + 轨道管理）、字幕（SRT/ASS/SSA/VTT 解析渲染） |
| 2026-08-05 | 阶段 8 | 完成 | DLNA 投屏（SSDP 发现 + SOAP 控制）、推送（远程指令接收 + 历史）、远程控制 HTTP 服务 |
| 2026-08-05 | 阶段 10 | 完成 | TV 焦点适配（TvFocusable 通用组件 + 方向键导航 + 确认键激活 + 自动滚动可见） |

### 阶段 1 完成清单
- `lib/core/`: log / hawk_config / app_constants / hawk_store / http_client / app_theme
- `lib/data/models/`: source_bean / movie / vod_info / movie_sort / parse_bean / abs_response
- `lib/data/api/api_config.dart`: 站点配置加载、JSON 解析、缓存、多源集合
- `lib/data/spider/`: spider 抽象 + json_spider + xml_spider + spider_loader
- `lib/data/repositories/source_repository.dart`: 调用 Spider 转模型
- `lib/routes/app_router.dart`: go_router 路由
- `lib/app.dart` / `lib/main.dart`: 入口与初始化
- `lib/features/home/`: 首页 ViewModel + 页面（分类导航 + 推荐网格 + 分类分页）
- `lib/features/detail/`: 详情 ViewModel + 页面（信息 + 线路 + 剧集）
- `lib/features/settings/`: 设置页（API 配置 + 调试开关）
- 其余页面（搜索/直播/历史/收藏/本地/推送/播放器）占位
- `flutter analyze` 0 error

### 阶段 7 完成清单（弹幕 / 字幕）
- `lib/features/danmu/danmu_item.dart`: 弹幕数据模型（DanmuItem / DanmuMode）
- `lib/features/danmu/danmu_loader.dart`: Bilibili XML/JSON 弹幕解析
- `lib/features/danmu/danmu_view.dart`: CustomPainter 渲染，滚动/顶部/底部三模式，轨道防重叠
- `lib/features/subtitle/subtitle_parser.dart`: SRT/ASS/SSA/VTT 字幕解析
- `lib/features/subtitle/subtitle_view.dart`: 字幕渲染，可配置字号/延迟/开关
- `lib/features/player/player_page.dart`: 集成弹幕/字幕叠加层 + 顶栏开关 + 本地字幕选择

### 阶段 8 完成清单（投屏 / 推送 / 远程控制）
- `lib/services/remote_server.dart`: 内置 HTTP 服务（端口 9978），接收 `/do?txt=<base64>` 指令（推送播放/搜索/URL）、`/files` 文件服务、`/status` 状态查询；端口占用自动递增
- `lib/features/cast/cast_manager.dart`: 纯 dart:io 实现 DLNA——SSDP M-SEARCH 设备发现、设备描述 XML 解析（friendlyName + AVTransport controlURL）、SOAP 控制（SetAVTransportURI/Play/Pause/Stop/Seek）+ DIDL-Lite 元数据
- `lib/features/cast/cast_page.dart`: 投屏设备列表 UI，支持搜索/选中/投屏/播放控制
- `lib/features/push/push_service.dart`: 监听 RemoteServer 事件，维护推送历史（最多 100 条）
- `lib/features/push/push_page.dart`: 推送历史列表 + 远程服务状态卡片（启停控制）
- `lib/app.dart`: bootstrap 中启动 RemoteServer + PushService
- `lib/routes/app_router.dart`: 新增 `/cast` 路由
- `lib/features/player/player_page.dart`: 顶栏新增投屏入口按钮
- `flutter analyze` 0 error / 0 warning

### 阶段 10 完成清单（TV 焦点适配）
- `lib/core/focus/tv_focus.dart`: TV 焦点通用组件
  - `TvFocusable`: 焦点高亮（边框 + 缩放）+ 确认键/OK 键回调 + 焦点获得时自动滚动可见
  - `TvIconButton`: 图标+文字按钮（顶栏用），可聚焦
  - `TvNavChip`: 胶囊导航项（分类标签用），可聚焦
  - `TvFocusScope`: 应用根焦点分组，启用 ReadingOrder 遍历策略，遥控器方向键自动空间导航
- `lib/app.dart`: 根节点包裹 `TvFocusScope`
- `lib/features/home/home_page.dart`: 顶栏操作改用 `TvIconButton`、分类导航改用 `TvNavChip`、新增推送入口
- `flutter analyze` 0 error / 0 warning（仅剩 24 个 info 级风格建议）

## 七、已知限制 / 待定

1. **JS Spider 兼容性**：纯 Dart 重写无法直接复用现有 JS 站点源生态，需逐个适配或维护兼容层。后续可考虑 `flutter_js` 作为兜底。
2. **IJK Player**：无 Flutter 等价，用 ExoPlayer + media_kit 替代，部分 IJK 专属格式（如某些 m3u8 加密）兼容性可能下降。
3. **迅雷 P2P**：替代方案仅能覆盖 HTTP/WebRTC，原迅雷链接无法解析。
4. **桌面 ExoPlayer**：ExoPlayer 仅 Android，桌面走 media_kit。
5. **TV 焦点**：Flutter TV 焦点较 Android 原生复杂，需自封装焦点树。
