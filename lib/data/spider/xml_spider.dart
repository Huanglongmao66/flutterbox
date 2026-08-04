// XML CMS Spider，对应 type=0 的旧版苹果CMS XML 接口
// 接口形态：?ac=list&t=&pg= / ?ac=vide&ids= / ?ac=detail&ids=
// 返回 XML，需解析为统一 JSON
import 'dart:convert';

import '../../core/utils/log.dart';
import '../models/abs_response.dart';
import '../models/movie.dart';
import 'spider.dart';

class XmlSpider extends Spider {
  XmlSpider();

  late String _api;

  void _ensureApi() {
    _api = ext;
  }

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
    final url = _buildUrl({'ac': 'list'});
    final body = await httpGet(url);
    // XML 接口首页返回 <class><ty id=.. name=.. /></class>
    final classList = <Map<String, dynamic>>[];
    final tyReg = RegExp(r'<ty\b([^>]*)>([^<]*)</ty>', caseSensitive: false);
    for (final m in tyReg.allMatches(body)) {
      final attrs = m.group(1) ?? '';
      final name = (m.group(2) ?? '').trim();
      final idMatch = RegExp(r'id="([^"]*)"').firstMatch(attrs);
      classList.add({
        'type_id': idMatch?.group(1) ?? '',
        'type_name': name,
      });
    }
    return json.encode({
      'class': classList,
      'list': <dynamic>[],
      'filters': <String, dynamic>{},
    });
  }

  @override
  Future<String> homeVideoContent() async {
    _ensureApi();
    final url = _buildUrl({'ac': 'vide', 'pg': '1'});
    final body = await httpGet(url);
    final resp = parseAbsXml(body);
    return json.encode({'list': resp.list.map(_vodToJson).toList()});
  }

  @override
  Future<String> categoryContent({
    required String tid,
    required int page,
    bool filter = true,
    Map<String, String> extend = const {},
  }) async {
    _ensureApi();
    final params = <String, String>{
      'ac': 'vide',
      't': tid,
      'pg': '$page',
    };
    extend.forEach((k, v) {
      if (v.isNotEmpty) params[k] = v;
    });
    final url = _buildUrl(params);
    final body = await httpGet(url);
    final resp = parseAbsXml(body);
    return json.encode({
      'list': resp.list.map(_vodToJson).toList(),
      'page': resp.page,
      'pagecount': resp.pagecount,
      'limit': resp.pagesize,
      'total': resp.total,
    });
  }

  @override
  Future<String> detailContent(List<String> ids) async {
    _ensureApi();
    if (ids.isEmpty) return '{"list":[]}';
    final url = _buildUrl({'ac': 'vide', 'ids': ids.join(',')});
    final body = await httpGet(url);
    try {
      final resp = parseAbsXml(body);
      return json.encode({'list': resp.list.map(_vodToJson).toList()});
    } catch (e) {
      LOG.e('XmlSpider', 'detailContent 解析失败', e);
      return '{"list":[]}';
    }
  }

  @override
  Future<String> searchContent({
    required String key,
    bool quick = false,
    String page = '1',
  }) async {
    _ensureApi();
    final url = _buildUrl({'ac': 'vide', 'wd': key, 'pg': page});
    final body = await httpGet(url);
    final resp = parseAbsXml(body);
    return json.encode({'list': resp.list.map(_vodToJson).toList()});
  }

  @override
  Future<String> playerContent({
    required String flag,
    required String id,
    List<String> vipFlags = const [],
  }) async {
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
