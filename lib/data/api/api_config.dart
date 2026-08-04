// 站点源配置管理，对应原项目 com.github.tvbox.osc.api.ApiConfig
// 负责：加载站点配置 JSON、解析 sites/parses/flags/lives/hosts/rules/doh
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/hawk_config.dart';
import '../../core/network/http_client.dart';
import '../../core/storage/hawk_store.dart';
import '../../core/utils/log.dart';
import '../models/models.dart';
import '../spider/spider_loader.dart';

typedef LoadConfigCallback = void Function({required bool success, String? error});

class ApiConfig {
  ApiConfig._();
  static final ApiConfig instance = ApiConfig._();

  final Map<String, SourceBean> _sourceBeanList = {};
  final List<SourceBean> _searchSourceList = [];
  final List<ParseBean> _parseBeanList = [];
  final List<String> _vipParseFlags = [];
  final Map<String, String> _myHosts = {};

  SourceBean? _homeSource;
  ParseBean? _defaultParse;
  String _spider = '';
  String _wallpaper = '';
  String _danmaku = '';
  String _currentPlaySourceKey = '';
  String? _tempKey;

  // 公共访问器
  List<SourceBean> get sources => _sourceBeanList.values.toList();
  List<SourceBean> get searchSources => _searchSourceList;
  List<ParseBean> get parses => _parseBeanList;
  List<String> get vipParseFlags => _vipParseFlags;
  Map<String, String> get myHosts => _myHosts;
  SourceBean? get homeSource => _homeSource;
  ParseBean? get defaultParse => _defaultParse;
  String get spider => _spider;
  String get wallpaper => _wallpaper;
  String get danmaku => _danmaku;
  String get currentPlaySourceKey => _currentPlaySourceKey;

  SourceBean? getSource(String key) => _sourceBeanList[key];

  void setSourceBean(SourceBean sb) {
    _homeSource = sb;
    HawkStore.put(HawkConfig.homeApi, sb.key);
  }

  void setDefaultParse(ParseBean pb) {
    pb.isDefault = true;
    for (final p in _parseBeanList) {
      p.isDefault = (p == pb);
    }
    _defaultParse = pb;
    HawkStore.put(HawkConfig.defaultParse, pb.name);
  }

  /// 加载主配置
  Future<void> loadConfig({bool useCache = true, required LoadConfigCallback callback}) async {
    final apiUrl = HawkStore.get<String>(HawkConfig.apiUrl, defaultValue: '') ?? '';
    if (apiUrl.isEmpty) {
      callback(success: false, error: '-1');
      return;
    }
    final cacheFile = await _cacheFile(apiUrl);
    if (useCache && cacheFile.existsSync()) {
      try {
        final json = cacheFile.readAsStringSync(encoding: utf8);
        // 多源集合切换
        if (_switchApiCollectionIfNeeded(apiUrl, json)) {
          await loadConfig(useCache: false, callback: callback);
          return;
        }
        _clearApiLinesIfUnmatched(apiUrl);
        _parseJson(apiUrl, json);
        callback(success: true);
        return;
      } catch (e) {
        LOG.e('ApiConfig', '缓存读取失败', e);
      }
    }
    final configUrl = _configUrl(apiUrl);
    final configKey = _tempKey;
    try {
      final body = await HttpClient.get(configUrl);
      if (body.isEmpty) {
        callback(success: false, error: '拉取配置失败：空响应');
        return;
      }
      var json = _findResult(body, configKey);
      json = _fixContentPath(apiUrl, json);
      if (_switchApiCollectionIfNeeded(apiUrl, json)) {
        cacheFile.writeAsStringSync(json, encoding: utf8);
        await loadConfig(useCache: false, callback: callback);
        return;
      }
      _clearApiLinesIfUnmatched(apiUrl);
      _parseJson(apiUrl, json);
      cacheFile.writeAsStringSync(json, encoding: utf8);
      callback(success: true);
    } catch (e) {
      // 回退缓存
      if (cacheFile.existsSync()) {
        try {
          final json = cacheFile.readAsStringSync(encoding: utf8);
          if (_switchApiCollectionIfNeeded(apiUrl, json)) {
            await loadConfig(useCache: false, callback: callback);
            return;
          }
          _clearApiLinesIfUnmatched(apiUrl);
          _parseJson(apiUrl, json);
          callback(success: true);
          return;
        } catch (_) {}
      }
      callback(success: false, error: '拉取配置失败\n$e');
    }
  }

  /// 解析配置 JSON
  void _parseJson(String apiUrl, String jsonStr) {
    _resetConfigData();
    final trimmed = _trimJsonObject(jsonStr);
    if (trimmed.isEmpty) return;
    Map<String, dynamic> info;
    try {
      info = (json.decode(trimmed) as Map).cast<String, dynamic>();
    } catch (e) {
      LOG.e('ApiConfig', '配置 JSON 解析失败', e);
      return;
    }
    _spider = (info['spider'] ?? '').toString();
    _wallpaper = (info['wallpaper'] ?? '').toString();
    _danmaku = (info['danmaku'] ?? '').toString();

    SourceBean? firstSite;
    final sites = info['sites'];
    if (sites is List) {
      for (final opt in sites) {
        if (opt is! Map) continue;
        final sb = SourceBean.fromJson(opt.cast<String, dynamic>());
        if (sb.key.startsWith('py_')) sb.filterable = 1;
        if (firstSite == null) firstSite = sb;
        _sourceBeanList[sb.key] = sb;
      }
    }
    if (_sourceBeanList.isNotEmpty) {
      final homeKey = HawkStore.get<String>(HawkConfig.homeApi, defaultValue: '') ?? '';
      final sh = getSource(homeKey);
      setSourceBean(sh ?? firstSite!);
    }

    // flags
    final flags = info['flags'];
    if (flags is List) {
      _vipParseFlags
          .addAll(flags.map((e) => e.toString()).where((s) => s.isNotEmpty));
    }

    // parses
    _parseBeanList.clear();
    final parses = info['parses'];
    if (parses is List) {
      for (final opt in parses) {
        if (opt is! Map) continue;
        _parseBeanList.add(ParseBean.fromJson(opt.cast<String, dynamic>()));
      }
      if (_parseBeanList.isNotEmpty) _addSuperParse();
    }
    if (_parseBeanList.isNotEmpty) {
      final defaultName =
          HawkStore.get<String>(HawkConfig.defaultParse, defaultValue: '') ?? '';
      ParseBean? found;
      if (defaultName.isNotEmpty) {
        found = _parseBeanList.firstWhere(
          (p) => p.name == defaultName,
          orElse: () => _parseBeanList.first,
        );
      }
      setDefaultParse(found ?? _parseBeanList.first);
    }

    // hosts
    _myHosts.clear();
    final hosts = info['hosts'];
    if (hosts is List) {
      for (final entry in hosts) {
        final s = entry.toString();
        final idx = s.indexOf('=');
        if (idx > 0) {
          _myHosts[s.substring(0, idx)] = s.substring(idx + 1);
        }
      }
    }

    // lives 简化：仅记录 URL，直播频道解析在 live 阶段实现
    final liveApiUrl = HawkStore.get<String>(HawkConfig.liveApiUrl, defaultValue: '') ?? '';
    if (liveApiUrl.isEmpty || liveApiUrl == apiUrl) {
      final lives = info['lives'];
      if (lives is List && lives.isNotEmpty) {
        final first = lives.first;
        if (first is Map) {
          final url = (first['url'] ?? '').toString();
          if (url.isNotEmpty) {
            HawkStore.put(HawkConfig.liveApiUrl, url);
          }
        }
      }
    }

    // 初始化 SpiderLoader jar 引用
    SpiderLoader.instance.configure(jar: _spider);
    LOG.i('ApiConfig', '配置加载完成：sources=${_sourceBeanList.length}, parses=${_parseBeanList.length}');
  }

  void _addSuperParse() {
    // 占位：聚合解析，后续在播放器阶段实现
  }

  void _resetConfigData() {
    _sourceBeanList.clear();
    _searchSourceList.clear();
    _parseBeanList.clear();
    _vipParseFlags.clear();
    _myHosts.clear();
    _homeSource = null;
    _defaultParse = null;
    _currentPlaySourceKey = '';
  }

  String _configUrl(String apiUrl) {
    _tempKey = null;
    const pk = ';pk;';
    String configUrl;
    if (apiUrl.contains(pk)) {
      final a = apiUrl.split(pk);
      _tempKey = a.length > 1 ? a[1] : null;
      final head = a[0];
      if (head.startsWith('clan')) {
        configUrl = _clanToAddress(head);
      } else if (head.startsWith('http')) {
        configUrl = head;
      } else {
        configUrl = 'http://$head';
      }
    } else if (apiUrl.startsWith('clan')) {
      configUrl = _clanToAddress(apiUrl);
    } else if (!apiUrl.startsWith('http')) {
      configUrl = 'http://$apiUrl';
    } else {
      configUrl = apiUrl;
    }
    return configUrl;
  }

  String _clanToAddress(String clanUrl) {
    // clan://localhost/path -> http://127.0.0.1:9978/files/...
    // 桌面/Android 远程 clan 简化处理
    var s = clanUrl.replaceFirst('clan://', '');
    s = s.replaceFirst('localhost/', '');
    if (s.startsWith('http')) return s;
    return 'http://127.0.0.1:${AppConstants.remoteServerPort}/files/$s';
  }

  String _findResult(String json, String? configKey) {
    var content = json;
    try {
      if (_isJson(content)) return content;
      final m = RegExp(r'[A-Za-z0-9]{8}\*\*').firstMatch(content);
      if (m != null) {
        content = content.substring(content.indexOf(m.group(0)!) + 10);
        content = utf8.decode(base64.decode(content));
      }
      content = content.trim();
      if (content.startsWith('2423')) {
        // 加密配置，完整实现见 AES；此处先尝试结构化解密
        // TODO(phase-x): 接入 AES.CBC 解密
        return content;
      } else if (configKey != null && configKey.isNotEmpty && !_isJson(content)) {
        // TODO(phase-x): AES.ECB 解密
        return content;
      }
      return content;
    } catch (e) {
      LOG.e('ApiConfig', 'FindResult 失败', e);
      return json;
    }
  }

  bool _isJson(String s) {
    final t = s.trim();
    if (!t.startsWith('{') && !t.startsWith('[')) return false;
    try {
      json.decode(t);
      return true;
    } catch (_) {
      return false;
    }
  }

  String _fixContentPath(String apiUrl, String content) {
    // clan 内容修正：clan:// -> 实际地址
    if (apiUrl.startsWith('clan')) {
      final addr = _clanToAddress(apiUrl);
      return content.replaceAll('clan://', addr.replaceAll('/files/', '/') + 'files/');
    }
    return content;
  }

  bool _switchApiCollectionIfNeeded(String apiUrl, String jsonStr) {
    final apiLines = _parseApiCollection(jsonStr);
    if (apiLines.isEmpty) return false;
    final firstApi = _getApiLineUrl(apiLines.first);
    if (firstApi.isEmpty || firstApi == apiUrl) return false;
    HawkStore.put(HawkConfig.apiLineList, apiLines);
    HawkStore.put(HawkConfig.apiLineSource, apiUrl);
    HawkStore.put(HawkConfig.apiUrl, firstApi);
    final liveApiUrl = HawkStore.get<String>(HawkConfig.liveApiUrl, defaultValue: '') ?? '';
    if (liveApiUrl.isEmpty || liveApiUrl == apiUrl) {
      HawkStore.put(HawkConfig.liveApiUrl, firstApi);
    }
    return true;
  }

  List<String> _parseApiCollection(String jsonStr) {
    final lines = <String>[];
    try {
      final json = _trimJsonObject(jsonStr);
      if (json.isEmpty) return lines;
      final decoded = jsonDecode(json);
      if (decoded is! Map) return lines;
      if (decoded.containsKey('sites') || !decoded.containsKey('urls')) return lines;
      final urls = decoded['urls'];
      if (urls is! List) return lines;
      for (final element in urls) {
        String url = '';
        if (element is Map) {
          url = (element['url'] ?? element['api'] ?? '').toString();
        } else {
          url = element.toString();
        }
        if (url.isNotEmpty) {
          lines.add(url);
        }
      }
    } catch (_) {}
    return lines;
  }

  String _getApiLineUrl(String line) => line;

  void _clearApiLinesIfUnmatched(String apiUrl) {
    final lines = HawkStore.get<List>(HawkConfig.apiLineList, defaultValue: const []) ?? const [];
    if (lines.isEmpty) return;
    // 简化：保留逻辑，后续 HistoryHelper 补全
  }

  String _trimJsonObject(String content) {
    if (content.isEmpty) return '';
    final t = content.trim();
    final start = t.indexOf('{');
    final end = t.lastIndexOf('}');
    if (start >= 0 && end > start) return t.substring(start, end + 1);
    return t;
  }

  Future<File> _cacheFile(String apiUrl) async {
    final dir = await getApplicationDocumentsDirectory();
    final md5 = _md5(apiUrl);
    return File('${dir.path}/$md5');
  }

  String _md5(String s) {
    // 简化哈希，避免引入额外依赖；冲突概率可接受
    var h = 0;
    for (int i = 0; i < s.length; i++) {
      h = (h * 31 + s.codeUnitAt(i)) & 0x7fffffff;
    }
    return 'cfg_$h';
  }

  /// 加载默认 API（首次启动用）
  Future<void> loadDefaultConfig() async {
    final apiUrl = HawkStore.get<String>(HawkConfig.apiUrl, defaultValue: '') ?? '';
    if (apiUrl.isEmpty) {
      // 使用内置默认测试源，首次启动自动写入
      await HawkStore.put(HawkConfig.apiUrl, HawkConfig.defaultApiUrl);
      LOG.i('ApiConfig', '首次启动，写入默认 API URL');
      // 触发一次拉取并缓存（异步，不阻塞启动）
      final c = Completer<void>();
      unawaited(loadConfig(useCache: true, callback: ({required bool success, String? error}) {
        if (success) {
          LOG.i('ApiConfig', '默认源加载成功');
        } else {
          LOG.w('ApiConfig', '默认源加载失败: $error');
        }
        if (!c.isCompleted) c.complete();
      }));
      // 最多等 10 秒，避免阻塞过久
      try {
        await c.future.timeout(const Duration(seconds: 10));
      } catch (_) {}
    }
  }
}
