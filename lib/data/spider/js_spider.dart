// Spider JS 适配：基于 flutter_js（QuickJS），执行 Spider 扩展 JS 脚本
// 兼容原 TVBox Spider 接口：init/homeContent/categoryContent/detailContent/searchContent/playerContent/liveContent
// JS 侧桥接工具：httpGet / httpPost / req（与 Java 版 req 调用风格一致）
import 'dart:async';
import 'dart:convert';

import 'package:flutter_js/flutter_js.dart';

import '../../core/network/http_client.dart';
import '../../core/utils/log.dart';
import 'jar_loader.dart';
import 'spider.dart';

class JsSpider extends Spider {
  JsSpider();

  // 每个 Spider 拥有独立 JS Runtime，避免变量相互污染
  JavascriptRuntime? _runtime;
  bool _jsLoaded = false;
  bool _jsSupported = true; // 当前平台是否支持 JS Runtime
  String? _preloadedJs; // 从 JAR 提取的预加载 JS 代码
  String _jarUrl = ''; // 站点级 JAR URL

  static final Map<String, JavascriptRuntime> _runtimeCache = {};

  /// 设置站点级 JAR URL（用于从 JAR 提取 JS）
  void setJarUrl(String jarUrl) {
    _jarUrl = jarUrl;
  }

  /// 预加载 JS 代码（从 JAR 提取），在 _loadJsIfNeeded 时优先使用
  void preloadJs(String jsCode) {
    _preloadedJs = jsCode;
    // 标记需要重新加载
    _jsLoaded = false;
  }

  Future<void> _ensureRuntime() async {
    if (_runtime != null) return;
    if (!_jsSupported) return;
    try {
      _runtime = getJavascriptRuntime();
      _registerDartBridge(_runtime!);
    } catch (e) {
      _jsSupported = false;
      LOG.e('JsSpider', '创建 JS Runtime 失败，当前平台不支持 flutter_js', e);
    }
  }

  void _registerDartBridge(JavascriptRuntime rt) {
    // 同步桥接工具 httpGet/httpPost：QuickJS 为同步执行，使用 sync HTTP
    // 由于 Dio 异步，先通过 fetch 同步函数不现实；这里用一个折中方案：
    // JS 侧调用 `httpGet(url)` / `httpPost(url,body)` 返回 Promise 字符串占位符，
    // 然后 Dart 端通过 dispatch 机制执行 HTTP 并回填。
    // 为简化实现，我们采用：
    // 1) JS 定义 async 函数（由 Dart 调用后返回 Promise 解析为 JSON 字符串）
    // 2) Dart 端通过 `await rt.evaluate('...')` 的 then 监听 Promise resolve

    // 注入基础 HTTP 工具（返回 Promise，需要 JS 侧用 await 调用）
    rt.onMessage('httpGet', (dynamic args) async {
      try {
        final list = args is List ? args : <dynamic>[];
        final url = list.isNotEmpty ? '${list[0]}' : '';
        final headers = list.length > 1 && list[1] is Map
            ? (list[1] as Map).map((k, v) => MapEntry('$k', '${v ?? ''}'))
            : null;
        return await HttpClient.get(url, headers: headers);
      } catch (e) {
        return '';
      }
    });
    rt.onMessage('httpPost', (dynamic args) async {
      try {
        final list = args is List ? args : <dynamic>[];
        final url = list.isNotEmpty ? '${list[0]}' : '';
        final data = list.length > 1 ? list[1] : null;
        final headers = list.length > 2 && list[2] is Map
            ? (list[2] as Map).map((k, v) => MapEntry('$k', '${v ?? ''}'))
            : null;
        return await HttpClient.post(url, data: data, headers: headers);
      } catch (e) {
        return '';
      }
    });
    rt.onMessage('httpGetBytes', (dynamic args) async {
      try {
        final list = args is List ? args : <dynamic>[];
        final url = list.isNotEmpty ? '${list[0]}' : '';
        final headers = list.length > 1 && list[1] is Map
            ? (list[1] as Map).map((k, v) => MapEntry('$k', '${v ?? ''}'))
            : null;
        final bytes = await HttpClient.getBytes(url, headers: headers);
        // 转为 Base64 方便 JS 侧处理
        return base64Encode(bytes);
      } catch (e) {
        return '';
      }
    });
    rt.onMessage('log', (dynamic args) {
      final list = args is List ? args : <dynamic>[];
      final tag = list.isNotEmpty ? '${list[0]}' : 'JS';
      final msg = list.length > 1 ? '${list[1]}' : '';
      LOG.i('JsSpider[$tag]', msg);
      return null;
    });
  }

  /// 注入 JS 端 Promise 包装函数，使得 JS 代码可以 await 调用 Dart 侧通道消息
  static const String _polyfillJs = r'''
if (typeof globalThis === 'undefined') { var globalThis = this; }
(function(){
  // 包装 sendMessage 返回 Promise
  globalThis.__dartCall = function(channel, args) {
    return new Promise(function(resolve, reject) {
      try {
        if (typeof sendMessage !== 'function') { resolve(''); return; }
        // flutter_js 中 sendMessage(channel, payload) 返回 Promise
        var result = sendMessage(channel, Array.isArray(args) ? args : [args]);
        if (result && typeof result.then === 'function') {
          result.then(function(v){ resolve(v == null ? '' : String(v)); })
                .catch(function(e){ resolve(''); });
        } else {
          resolve(result == null ? '' : String(result));
        }
      } catch (e) { resolve(''); }
    });
  };
  // 常用工具
  globalThis.httpGet = function(url, headers) { return globalThis.__dartCall('httpGet', [url, headers || null]); };
  globalThis.httpPost = function(url, data, headers) { return globalThis.__dartCall('httpPost', [url, data == null ? null : data, headers || null]); };
  globalThis.httpGetBytes = function(url, headers) { return globalThis.__dartCall('httpGetBytes', [url, headers || null]); };
  // 兼容部分脚本 console.log
  if (typeof console === 'undefined') {
    globalThis.console = { log: function(){ var a=Array.prototype.slice.call(arguments); try{ sendMessage('log', ['console', a.join(' ')]); }catch(_){} } };
  }
  // req(obj)：类似 Java 版 SpiderUtils.req，参数：{url, method:'GET'|'POST', headers:{}, data:body, timeout}
  // 返回 Promise<String>（响应 body）
  globalThis.req = function(o) {
    if (!o) return Promise.resolve('');
    var url = o.url || '';
    var method = (o.method || 'GET').toUpperCase();
    if (method === 'POST') {
      return globalThis.httpPost(url, o.data == null ? null : o.data, o.headers || null);
    }
    return globalThis.httpGet(url, o.headers || null);
  };
  // Java 占位（避免脚本报 ReferenceError），具体正则/AES 等后续可扩展
  if (typeof java === 'undefined') globalThis.java = { util: { regex: { Matcher: { match: function(p, s) { try { return new RegExp(p).exec(s) || []; } catch(e){return [];} } } } };
})();
''';

  /// 判断字符串是否可能是 JS 代码（包含关键字），否则视为 JS 脚本 URL 需要先下载
  static bool _looksLikeJsCode(String s) {
    final t = s.trim();
    if (t.isEmpty) return false;
    // 1) URL → 需要下载
    if (t.startsWith('http://') || t.startsWith('https://')) return false;
    // 2) Jar 类名模式（常见前缀 csp_/js_，通常是驼峰 + Guard/Driver 后缀）→ 不是 JS
    final jarPattern = RegExp(r'^(csp_|js_|jar_)[A-Za-z0-9_]+(Guard|Driver|Spider|Parser)?$');
    if (jarPattern.hasMatch(t)) return false;
    // 3) 纯 JSON 对象（key 不带引号且无 function/var/let 等 JS 语句特征）→ 通常是配置而非可执行 JS
    if (t.startsWith('{') && t.endsWith('}')) {
      // 如果内部没有出现 JS 关键字则判定为 JSON（非 JS 代码）
      if (!t.contains('function') &&
          !t.contains('=>') &&
          !t.contains(' return ') &&
          !t.contains(';') &&
          !t.contains('var ') &&
          !t.contains('const ') &&
          !t.contains('let ')) {
        return false;
      }
    }
    // 4) 包含 JS 关键字特征
    return t.contains('function') ||
        t.contains('=>') ||
        t.contains('var ') ||
        t.contains('const ') ||
        t.contains('let ') ||
        t.contains('class ') ||
        t.startsWith('(');
  }

  // Jar 类名模式与 SpiderLoader 同步，避免无效 JS 加载
  static final RegExp _jarClassPattern =
      RegExp(r'^(csp_|js_|jar_)[A-Za-z0-9_]+(Guard|Driver|Spider|Parser)?$');

  /// 加载 JS 脚本：优先使用预加载 JS，否则从 ext 加载
  Future<void> _loadJsIfNeeded() async {
    await _ensureRuntime();
    if (_runtime == null || _jsLoaded) return;

    try {
      // 优先使用从 JAR 提取的预加载 JS
      if (_preloadedJs != null && _preloadedJs!.isNotEmpty) {
        // 先注入 polyfill
        final r1 = await _runtime!.evaluateAsync(_polyfillJs);
        _evalResultToString(r1);
        // 加载预加载的 JS 脚本
        final r2 = await _runtime!.evaluateAsync(_preloadedJs!);
        _evalResultToString(r2);
        _jsLoaded = true;
        LOG.i('JsSpider', '预加载 JS 脚本执行成功');
        return;
      }

      final extTrim = ext.trim();
      // Jar 类名 → 从 JAR 提取 JS 脚本
      if (_jarClassPattern.hasMatch(extTrim)) {
        LOG.i('JsSpider', '检测到 Jar 类名，从 JAR 提取 JS: $extTrim');
        final js = await JarLoader.instance.getJsFromJar(
          extTrim,
          jarUrl: _jarUrl.isNotEmpty ? _jarUrl : null,
        );
        if (js.isEmpty) {
          LOG.w('JsSpider', 'JAR 中未找到 JS: $extTrim');
          _jsLoaded = false;
          return;
        }
        // 先注入 polyfill
        final rp = await _runtime!.evaluateAsync(_polyfillJs);
        _evalResultToString(rp);
        // 加载提取到的 JS 脚本
        final r2 = await _runtime!.evaluateAsync(js);
        _evalResultToString(r2);
        _jsLoaded = true;
        LOG.i('JsSpider', 'JAR JS 脚本加载成功: $extTrim');
        return;
      }

      // 无 ext → 不加载
      if (extTrim.isEmpty) {
        _jsLoaded = false;
        return;
      }
      // 先注入 polyfill
      final r1 = await _runtime!.evaluateAsync(_polyfillJs);
      _evalResultToString(r1);
      // 再加载用户脚本
      String jsCode;
      if (_looksLikeJsCode(extTrim)) {
        jsCode = extTrim;
      } else if (extTrim.startsWith('http://') || extTrim.startsWith('https://')) {
        LOG.i('JsSpider', '下载 JS 脚本：$extTrim');
        jsCode = await HttpClient.get(extTrim);
      } else {
        // 非 URL 又不像 JS 代码（如 JSON 配置、类名）→ 不加载
        _jsLoaded = false;
        return;
      }
      if (jsCode.isEmpty) {
        LOG.w('JsSpider', 'JS 脚本为空');
        _jsLoaded = false;
        return;
      }
      // 加载用户脚本
      final r2 = await _runtime!.evaluateAsync(jsCode);
      _evalResultToString(r2);
      _jsLoaded = true;
    } catch (e) {
      _jsLoaded = false;
      LOG.e('JsSpider', '加载 JS 脚本失败', e);
    }
  }

  String _evalResultToString(dynamic r) {
    try {
      if (r == null) return '';
      if (r is String) return r;
      if (r is JsEvalResult) {
        return r.stringResult;
      }
      return '$r';
    } catch (_) {
      return '';
    }
  }

  /// 调用 JS 中定义的异步 Spider 方法
  Future<String> _callJs(String methodName, List<dynamic> args) async {
    await _loadJsIfNeeded();
    final rt = _runtime;
    if (rt == null || !_jsLoaded) return '';
    // 参数 JSON 序列化后传参，避免类型转换丢失
    final argsJson = args.map((a) => json.encode(a)).toList();
    final callExpr = StringBuffer();
    callExpr.write('(async function(){');
    callExpr.write('  if (typeof $methodName !== "function") return "";');
    callExpr.write('  var r = await $methodName(');
    callExpr.write(argsJson.join(','));
    callExpr.write(');');
    callExpr.write('  if (r == null) return "";');
    callExpr.write('  if (typeof r === "string") return r;');
    callExpr.write('  try { return JSON.stringify(r); } catch(_) { return String(r); }');
    callExpr.write('})()');
    try {
      final result = await rt.evaluateAsync(callExpr.toString());
      final raw = _evalResultToString(result);
      return raw;
    } catch (e) {
      LOG.e('JsSpider', '调用 $methodName 失败', e);
      return '';
    }
  }

  @override
  void init(String siteKey, {String extend = ''}) {
    super.init(siteKey, extend: extend);
    // 每个 siteKey 复用同一个 Runtime 缓存（同 key Spider 间共享变量）
    final cached = _runtimeCache[siteKey];
    if (cached != null) {
      _runtime = cached;
      _jsLoaded = true;
      return;
    }
  }

  // ---------- Spider 接口实现 ----------

  @override
  Future<String> homeContent({bool filter = true}) async {
    // 兼容不同 JS 脚本函数命名风格
    var r = await _callJs('homeContent', [filter]);
    if (r.isEmpty) r = await _callJs('home', [filter]);
    return r.isEmpty ? '{}' : r;
  }

  @override
  Future<String> homeVideoContent() async {
    final r = await _callJs('homeVideoContent', const []);
    return r.isEmpty ? '{}' : r;
  }

  @override
  Future<String> categoryContent({
    required String tid,
    required int page,
    bool filter = true,
    Map<String, String> extend = const {},
  }) async {
    final r = await _callJs(
      'categoryContent',
      [tid, page, filter, extend],
    );
    return r.isEmpty ? '{}' : r;
  }

  @override
  Future<String> detailContent(List<String> ids) async {
    final r = await _callJs('detailContent', [ids]);
    return r.isEmpty ? '{"list":[]}' : r;
  }

  @override
  Future<String> searchContent({
    required String key,
    bool quick = false,
    String page = '1',
  }) async {
    var r = await _callJs('searchContent', [key, quick, page]);
    if (r.isEmpty) r = await _callJs('search', [key, quick, page]);
    return r.isEmpty ? '{"list":[]}' : r;
  }

  @override
  Future<String> playerContent({
    required String flag,
    required String id,
    List<String> vipFlags = const [],
  }) async {
    final r = await _callJs('playerContent', [flag, id, vipFlags]);
    return r.isEmpty
        ? '{"parse":0,"playUrl":"","url":"${id.replaceAll('"', '\\"')}","header":""}'
        : r;
  }

  @override
  Future<String> liveContent(String url) async {
    final r = await _callJs('liveContent', [url]);
    return r.isEmpty ? '' : r;
  }

  @override
  void destroy() {
    final rt = _runtime;
    if (rt != null) {
      try {
        rt.dispose();
      } catch (_) {}
      _runtimeCache.remove(siteKey);
    }
    _runtime = null;
    _jsLoaded = false;
    super.destroy();
  }
}
