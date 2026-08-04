// Spider 加载器，对应原项目 JarLoader/JsLoader
// 根据 SourceBean.type 返回对应 Spider 实例
// 纯 Dart 实现，不加载 jar/JS
import '../../core/constants/app_constants.dart';
import '../models/source_bean.dart';
import 'json_spider.dart';
import 'spider.dart';
import 'xml_spider.dart';

class SpiderLoader {
  SpiderLoader._();
  static final SpiderLoader instance = SpiderLoader._();

  final Map<String, Spider> _cache = {};

  void configure({required String jar}) {
    _cache.clear();
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
        // 自定义 Spider 站点：纯 Dart 无法直接执行 JS
        // 降级为 JSON Spider，ext 视为 api 地址
        // TODO(phase-x): 评估 flutter_js 兜底兼容 JS 站点源
        spider = JsonSpider();
        break;
      default:
        spider = JsonSpider();
    }
    // ext 优先，否则用 api
    final extend = source.ext.isNotEmpty ? source.ext : source.api;
    spider.init(key, extend: extend);
    _cache[key] = spider;
    return spider;
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
