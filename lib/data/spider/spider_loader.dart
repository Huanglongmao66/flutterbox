// Spider 加载器，对应原项目 JarLoader/JsLoader
// 根据 SourceBean.type 返回对应 Spider 实例：
//  - type=0(XML) -> XmlSpider
//  - type=1(JSON) -> JsonSpider
//  - type=3(Spider) -> JsSpider（基于 flutter_js/QuickJS），兜底 JsonSpider
import '../../core/constants/app_constants.dart';
import '../../core/utils/log.dart';
import '../models/source_bean.dart';
import 'jar_loader.dart';
import 'json_spider.dart';
import 'js_spider.dart';
import 'spider.dart';
import 'xml_spider.dart';

class SpiderLoader {
  SpiderLoader._();
  static final SpiderLoader instance = SpiderLoader._();

  final Map<String, Spider> _cache = {};

  void configure({required String jar}) {
    clear();
    JarLoader.instance.setGlobalJar(jar);
    // 异步预热：下载并检测全局 JAR 类型
    if (jar.isNotEmpty) {
      JarLoader.instance.preCheckJar(jar).then((_) {
        final compiled = JarLoader.instance.isKnownCompiled(jar);
        LOG.i('SpiderLoader', '全局 JAR 预检完成，编译型: $compiled');
        // 预检完成后清除缓存，让后续 getSpider 根据预检结果创建正确的 Spider
        if (compiled) {
          clear();
        }
      });
    }
  }

  // Jar 类名模式（Java Spider）：需要从 JAR 中提取 JS 脚本
  static final RegExp _jarClassPattern =
      RegExp(r'^(csp_|js_|jar_)[A-Za-z0-9_]+(Guard|Driver|Spider|Parser)?$');

  /// 判断是否应该使用 JsSpider（ext 需疑似 JS 代码 或 JS/脚本 URL）
  bool _useJsSpider(SourceBean s) {
    final e = s.ext.trim();
    if (e.isEmpty) return false;
    // Jar 类名 → 尝试从 JAR 加载 JS
    if (_jarClassPattern.hasMatch(e)) return true;
    // HTTP(S) URL → 下载后再判断内容是否是 JS（.js/.txt 脚本资源通常是）
    if (e.startsWith('http://') || e.startsWith('https://')) {
      return true;
    }
    // ext 包含明显的 JSON 配置结构（key 如 json/api/xml）而不是 JS → 不走 JsSpider
    if (e.startsWith('{') &&
        (e.contains('"json"') ||
            e.contains(': json') ||
            RegExp(r'\bjson\s*:\s*https?://').hasMatch(e))) {
      return false;
    }
    // 包含 JS 关键字 → 用 JsSpider
    return e.contains('function') ||
        e.contains('=>') ||
        e.contains('var ') ||
        e.contains('const ') ||
        e.contains('let ') ||
        e.contains('class ') ||
        e.startsWith('(');
  }

  /// 获取站点对应的 Spider
  Spider getSpider(SourceBean source) {
    final key = source.key;
    final cached = _cache[key];
    if (cached != null) return cached;

    final Spider spider;
    switch (source.type) {
      case AppConstants.sourceTypeXml:
        spider = XmlSpider();
        break;
      case AppConstants.sourceTypeJson:
        spider = JsonSpider();
        break;
      case AppConstants.sourceTypeSpider:
        spider = _createSpiderSpider(source);
        break;
      default:
        spider = _useJsSpider(source) ? JsSpider() : JsonSpider();
    }
    // ext 优先，否则用 api
    final extend = source.ext.isNotEmpty ? source.ext : source.api;
    spider.init(key, extend: extend);
    // 对 JsSpider 设置站点级 JAR URL
    if (spider is JsSpider && source.jar.isNotEmpty) {
      spider.setJarUrl(source.jar);
    }
    _cache[key] = spider;
    return spider;
  }

  /// type=3 Spider 的创建逻辑
  /// 1. ext/api 为 Jar 类名：
  ///    a. JAR 已知编译型 → 降级 JsonSpider
  ///    b. JAR 未知/含 JS → JsSpider（首次调用时自动从 JAR 加载 JS）
  /// 2. ext/api 为 JS 代码/URL → 直接 JsSpider
  /// 3. 非 JS → 降级 JsonSpider
  Spider _createSpiderSpider(SourceBean source) {
    // ext 优先，api 兜底
    final ext = source.ext.trim().isNotEmpty
        ? source.ext.trim()
        : source.api.trim();

    // Jar 类名
    if (_jarClassPattern.hasMatch(ext)) {
      final jarUrl = source.jar.isNotEmpty ? source.jar : JarLoader.instance.globalJar;
      // 已知编译型 JAR → 降级 JsonSpider
      if (jarUrl.isNotEmpty && JarLoader.instance.isKnownCompiled(jarUrl)) {
        LOG.i('SpiderLoader',
            '${source.key} Jar 编译型，降级 JsonSpider ($ext)');
        return JsonSpider();
      }
      // 未知或含 JS → JsSpider 尝试从 JAR 加载
      LOG.i('SpiderLoader',
          '${source.key} Jar Spider ($ext), jar=${jarUrl.isNotEmpty ? jarUrl : "(全局)"}');
      return JsSpider();
    }

    // 非 Jar 类名，判断是否 JS
    if (_useJsSpider(source)) {
      LOG.i('SpiderLoader', '${source.key} 使用 JsSpider (ext=${_shortExt(source)})');
      return JsSpider();
    }

    LOG.i('SpiderLoader',
        '${source.key} 降级 JsonSpider (ext=${_shortExt(source)})');
    return JsonSpider();
  }

  String _shortExt(SourceBean s) {
    final e = s.ext.isEmpty ? s.api : s.ext;
    return e.length > 50 ? '${e.substring(0, 50)}...' : e;
  }

  void clear() {
    for (final s in _cache.values) {
      try {
        s.destroy();
      } catch (_) {}
    }
    _cache.clear();
  }
}
