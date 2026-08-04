// CMS 接口响应解析，对应原项目 AbsJson / AbsXml
// 统一返回 MoviePage（含 videoList 与分页信息）
import 'dart:convert';

import 'movie.dart';

class AbsResponse {
  AbsResponse({this.page = 0, this.pagecount = 0, this.pagesize = 0, this.total = 0, List<MovieVideo>? list, this.msg = ''})
      : list = list ?? <MovieVideo>[];

  int page;
  int pagecount;
  int pagesize;
  int total;
  List<MovieVideo> list;
  String msg;

  MoviePage toMoviePage() => MoviePage(
        page: page,
        pagecount: pagecount,
        pagesize: pagesize,
        recordcount: total,
        videoList: list,
        msg: msg,
      );
}

/// 解析 CMS JSON 响应（Maccms/Lumen 等标准格式）
AbsResponse parseAbsJson(String body) {
  // body 可能是 json 或带前缀的 json
  final cleaned = _stripJsonWrapper(body);
  if (cleaned.isEmpty) return AbsResponse();
  dynamic decoded;
  try {
    decoded = _decodeJson(cleaned);
  } catch (_) {
    return AbsResponse();
  }
  if (decoded is! Map) return AbsResponse();
  final code = decoded['code'];
  final listRaw = decoded['list'];

  final resp = AbsResponse(
    page: _asInt(decoded['page']),
    pagecount: _asInt(decoded['pagecount']),
    pagesize: _asInt(decoded['limit']),
    total: _asInt(decoded['total']),
    msg: (decoded['msg'] ?? '').toString(),
  );

  if (code != null && code.toString() != '1' && listRaw == null) {
    return resp;
  }

  if (listRaw is List) {
    for (final item in listRaw) {
      if (item is! Map) continue;
      resp.list.add(_vodFromJson(item));
    }
  }
  return resp;
}

/// 解析 CMS XML 响应（旧版苹果CMS XML 接口）
AbsResponse parseAbsXml(String body) {
  // 简化实现：解析 <list page=.. pagecount=.. pagesize=.. recordcount=..><video>..</video></list>
  // 真实 XML 解析在 spider 层使用 xml 包；这里仅做兜底
  final resp = AbsResponse();
  if (body.isEmpty) return resp;
  // 提取属性
  final listMatch = RegExp(r'<list\b([^>]*)>', caseSensitive: false).firstMatch(body);
  if (listMatch != null) {
    final attrs = listMatch.group(1) ?? '';
    resp.page = _attrInt(attrs, 'page');
    resp.pagecount = _attrInt(attrs, 'pagecount');
    resp.pagesize = _attrInt(attrs, 'pagesize');
    resp.total = _attrInt(attrs, 'recordcount');
  }
  final videoReg = RegExp(r'<video\b([^>]*)>([\s\S]*?)</video>', caseSensitive: false);
  for (final m in videoReg.allMatches(body)) {
    final inner = m.group(2) ?? '';
    final video = MovieVideo();
    video.last = _innerTag(inner, 'last');
    video.id = _innerTag(inner, 'id');
    video.tid = int.tryParse(_innerTag(inner, 'tid')) ?? 0;
    video.name = _innerTag(inner, 'name');
    video.type = _innerTag(inner, 'type');
    video.pic = _innerTag(inner, 'pic');
    video.lang = _innerTag(inner, 'lang');
    video.area = _innerTag(inner, 'area');
    video.year = int.tryParse(_innerTag(inner, 'year')) ?? 0;
    video.state = _innerTag(inner, 'state');
    video.note = _innerTag(inner, 'note');
    video.actor = _innerTag(inner, 'actor');
    video.director = _innerTag(inner, 'director');
    video.des = _innerTag(inner, 'des');
    video.tag = _innerTag(inner, 'tag');
    resp.list.add(video);
  }
  return resp;
}

MovieVideo _vodFromJson(Map item) {
  final video = MovieVideo.fromJson(item.cast<String, dynamic>());
  // 解析 vod_play_from / vod_play_url 为剧集
  final playFrom = (item['vod_play_from'] ?? '').toString();
  final playUrl = (item['vod_play_url'] ?? '').toString();
  if (playFrom.isNotEmpty && playUrl.isNotEmpty) {
    final flags = playFrom.split(r'$$$');
    final urls = playUrl.split(r'$$$');
    for (int i = 0; i < flags.length && i < urls.length; i++) {
      final flag = flags[i].trim();
      final urlStr = urls[i].trim();
      if (flag.isEmpty || urlStr.isEmpty) continue;
      final episodes = <VideoEpisode>[];
      for (final pair in urlStr.split('#')) {
        if (pair.trim().isEmpty) continue;
        final idx = pair.indexOf('\$');
        if (idx > 0) {
          episodes.add(VideoEpisode(
            name: pair.substring(0, idx).trim(),
            url: pair.substring(idx + 1).trim(),
          ));
        } else {
          episodes.add(VideoEpisode(name: '${episodes.length + 1}', url: pair.trim()));
        }
      }
      video.urlList.add(VideoUrlInfo(flag: flag, urls: urlStr, episodes: episodes));
    }
  }
  return video;
}

String _stripJsonWrapper(String body) {
  var s = body.trim();
  // 去除可能的 jsonp 包裹
  if (s.startsWith('(') && s.endsWith(')')) {
    s = s.substring(1, s.length - 1);
  }
  return s;
}

dynamic _decodeJson(String s) => jsonDecode(s);

int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? 0;
}

int _attrInt(String attrs, String name) {
  final m = RegExp('$name="([^"]*)"').firstMatch(attrs);
  if (m == null) return 0;
  return int.tryParse(m.group(1)!) ?? 0;
}

String _innerTag(String inner, String tag) {
  final m = RegExp('<$tag\\b[^>]*>([\\s\\S]*?)</$tag>', caseSensitive: false).firstMatch(inner);
  if (m == null) return '';
  var s = m.group(1) ?? '';
  // 去 CDATA
  s = s.replaceAll(RegExp(r'<!\[CDATA\[([\s\S]*?)\]\]>'), r'$1');
  return s.trim();
}
