// JSON CMS Spider，对应 type=1 的标准苹果CMS（Maccms）JSON 接口
// 实现标准 provide/vod 接口：ac=list / ac=detail / ac=vide
import 'dart:convert';

import '../../core/utils/log.dart';
import '../models/abs_response.dart';
import '../models/movie.dart';
import 'spider.dart';

class JsonSpider extends Spider {
  JsonSpider();

  late String _api; // CMS api 根地址（如 https://x.com/api.php/provide/vod）

  void _ensureApi() {
    _api = ext;
  }

  /// 检查 api 是否为有效 HTTP URL
  /// 编译型 JAR 降级时 ext 可能是 Jar 类名（如 csp_XXX），不是有效 URL
  bool get _isValidApi {
    return _api.startsWith('http://') || _api.startsWith('https://');
  }

  /// 构造完整请求 URL
  String _buildUrl(Map<String, String> params) {
    var base = _api;
    if (base.isEmpty) return '';
    final sep = base.contains('?') ? '&' : '?';
    final q = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return '$base$sep$q';
  }

  @override
  Future<String> homeContent({bool filter = true}) async {
    _ensureApi();
    if (!_isValidApi) return '{}';
    final url = _buildUrl({'ac': 'list'});
    final body = await httpGet(url);
    try {
      final map = json.decode(body) as Map<String, dynamic>;
      // 转换 class_list -> class 数组
      final classList = map['class'];
      if (classList is List) {
        map['class'] = classList.map((c) => {
              'type_id': (c as Map)['type_id']?.toString() ?? '',
              'type_name': c['type_name']?.toString() ?? '',
            }).toList();
      } else if (classList is Map) {
        map['class'] = classList.values.map((c) => {
              'type_id': (c as Map)['type_id']?.toString() ?? '',
              'type_name': c['type_name']?.toString() ?? '',
            }).toList();
      }
      // 首页推荐（ac=list 默认返回部分列表）
      if (!map.containsKey('list')) map['list'] = <dynamic>[];
      map['filters'] = <String, dynamic>{};
      return json.encode(map);
    } catch (e) {
      LOG.e('JsonSpider', 'homeContent 解析失败', e);
      return '{}';
    }
  }

  @override
  Future<String> homeVideoContent() async {
    _ensureApi();
    if (!_isValidApi) return '{}';
    final url = _buildUrl({'ac': 'detail', 'pg': '1'});
    return httpGet(url);
  }

  @override
  Future<String> categoryContent({
    required String tid,
    required int page,
    bool filter = true,
    Map<String, String> extend = const {},
  }) async {
    _ensureApi();
    if (!_isValidApi) return '{"list":[],"page":"$page","pagecount":0,"limit":0,"total":0}';
    final params = <String, String>{
      'ac': 'list',
      't': tid,
      'pg': '$page',
    };
    // 筛选参数
    extend.forEach((k, v) {
      if (v.isNotEmpty) params[k] = v;
    });
    final url = _buildUrl(params);
    final body = await httpGet(url);
    // 标准化字段
    try {
      final map = json.decode(body) as Map<String, dynamic>;
      final resp = parseAbsJson(body);
      map['list'] = resp.list.map(_vodToJson).toList();
      map['page'] = resp.page;
      map['pagecount'] = resp.pagecount;
      map['limit'] = resp.pagesize;
      map['total'] = resp.total;
      return json.encode(map);
    } catch (_) {
      return body;
    }
  }

  @override
  Future<String> detailContent(List<String> ids) async {
    _ensureApi();
    if (!_isValidApi || ids.isEmpty) return '{"list":[]}';
    final url = _buildUrl({'ac': 'detail', 'ids': ids.join(',')});
    final body = await httpGet(url);
    try {
      final map = json.decode(body) as Map<String, dynamic>;
      final resp = parseAbsJson(body);
      map['list'] = resp.list.map(_vodToJson).toList();
      return json.encode(map);
    } catch (_) {
      return body;
    }
  }

  @override
  Future<String> searchContent({
    required String key,
    bool quick = false,
    String page = '1',
  }) async {
    _ensureApi();
    if (!_isValidApi) return '{"list":[]}';
    final url = _buildUrl({'ac': 'detail', 'wd': key, 'pg': page});
    final body = await httpGet(url);
    try {
      final resp = parseAbsJson(body);
      return json.encode({'list': resp.list.map(_vodToJson).toList()});
    } catch (_) {
      return body;
    }
  }

  @override
  Future<String> playerContent({
    required String flag,
    required String id,
    List<String> vipFlags = const [],
  }) async {
    // 标准 JSON CMS 直接返回 id 作为播放地址
    return json.encode({
      'parse': 0,
      'playUrl': '',
      'url': id,
      'header': '',
    });
  }

  @override
  Future<String> liveContent(String url) async => '';

  Map<String, dynamic> _vodToJson(vod) {
    // 透传原始字段
    if (vod is MovieVideo) {
      return {
        'vod_id': vod.id,
        'vod_name': vod.name,
        'vod_pic': vod.pic,
        'vod_remarks': vod.note,
        'type_name': vod.type,
        'vod_year': '${vod.year}',
        'vod_area': vod.area,
        'vod_lang': vod.lang,
        'vod_actor': vod.actor,
        'vod_director': vod.director,
        'vod_content': vod.des,
      };
    }
    return Map<String, dynamic>.from(vod as Map);
  }
}
