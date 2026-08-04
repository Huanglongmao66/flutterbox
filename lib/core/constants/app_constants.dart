// 应用常量
import 'package:flutter/foundation.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'TVBox';

  // 播放器类型，对应原 HawkConfig.PLAY_TYPE
  static const int playerTypeSystem = 0;
  static const int playerTypeIjk = 1;
  static const int playerTypeExo = 2;
  static const int playerTypeMx = 10;
  static const int playerTypeDefault = -1;

  // 站点源类型，对应 SourceBean.type
  static const int sourceTypeXml = 0;
  static const int sourceTypeJson = 1;
  static const int sourceTypeSpider = 3;

  // 解析类型，对应 ParseBean.type
  static const int parseTypeSniff = 0; // 普通嗅探
  static const int parseTypeJson = 1;
  static const int parseTypeJsonExt = 2;
  static const int parseTypeAggregate = 3;

  // 默认 UA
  static const String defaultUa =
      'Mozilla/5.0 (Linux; U; Android 11; zh-cn; Mi 11 Build/RKQ1.200826.002) AppleWebKit/533.1 (KHTML, like Gecko) Version/5.0 Mobile Safari/533.1';

  // 主机端口（远程控制服务）
  static const int remoteServerPort = 9978;
}

// 平台判断扩展
bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;
bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;
bool get isWindows => defaultTargetPlatform == TargetPlatform.windows;
bool get isMacOS => defaultTargetPlatform == TargetPlatform.macOS;
bool get isLinux => defaultTargetPlatform == TargetPlatform.linux;
bool get isDesktop => isWindows || isMacOS || isLinux;
bool get isMobile => isAndroid || isIOS;
