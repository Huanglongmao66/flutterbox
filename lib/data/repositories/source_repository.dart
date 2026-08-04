// 数据仓库，对应原项目 com.github.tvbox.osc.viewmodel.SourceViewModel
// 调用 Spider，把返回的 JSON 字符串转换为模型
import 'dart:convert';

import '../models/models.dart';
import '../spider/spider_loader.dart';
import '../api/api_config.dart';

class SourceRepository {
  SourceRepository._();
  static final SourceRepository instance = SourceRepository._();

  /// 首页内容（分类 + 推荐）
  Future<({List<SortData> classes, List<MovieVideo> recommend})> homeContent(
      SourceBean source) async {
    final spider = SpiderLoader.instance.getSpider(source);
    final body = await spider.homeContent(filter: source.filterable == 1);
    List<SortData> classes = [];
    List<MovieVideo> recommend = [];
    if (body.isEmpty) return (classes: classes, recommend: recommend);
    try {
      final map = json.decode(body) as Map<String, dynamic>;
      final cls = map['class'];
      if (cls is List) {
        // 站点自定义分类优先于 categories
        classes = cls
            .map((c) => SortData(
                  id: (c is Map ? (c['type_id'] ?? c['id'] ?? '').toString() : ''),
                  name: (c is Map ? (c['type_name'] ?? c['name'] ?? '').toString() : ''),
                ))
            .where((s) => s.name.isNotEmpty)
            .toList();
      }
      if (classes.isEmpty && source.categories.isNotEmpty) {
        classes = source.categories
            .asMap()
            .entries
            .map((e) => SortData(id: '${e.key + 1}', name: e.value))
            .toList();
      }
      final list = map['list'];
      if (list is List) {
        recommend = list
            .whereType<Map>()
            .map((m) => _videoFromMap(m.cast<String, dynamic>()))
            .toList();
      }
    } catch (_) {}
    return (classes: classes, recommend: recommend);
  }

  /// 分类列表
  Future<MoviePage> categoryContent(
      SourceBean source, SortData sort, int page,
      {Map<String, String> extend = const {}}) async {
    final spider = SpiderLoader.instance.getSpider(source);
    final body = await spider.categoryContent(
      tid: sort.id,
      page: page,
      filter: source.filterable == 1,
      extend: extend,
    );
    return _parsePage(body);
  }

  /// 详情
  Future<MovieVideo?> detailContent(SourceBean source, String id) async {
    final spider = SpiderLoader.instance.getSpider(source);
    final body = await spider.detailContent([id]);
    if (body.isEmpty) return null;
    try {
      final map = json.decode(body) as Map<String, dynamic>;
      final list = map['list'];
      if (list is List && list.isNotEmpty) {
        final v = _videoFromMap(list.first.cast<String, dynamic>());
        v.sourceKey = source.key;
        return v;
      }
    } catch (_) {}
    return null;
  }

  /// 搜索
  Future<List<MovieVideo>> searchContent(
      SourceBean source, String key,
      {bool quick = false, String page = '1'}) async {
    final spider = SpiderLoader.instance.getSpider(source);
    final body = await spider.searchContent(key: key, quick: quick, page: page);
    if (body.isEmpty) return [];
    try {
      final map = json.decode(body) as Map<String, dynamic>;
      final list = map['list'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((m) {
              final v = _videoFromMap(m.cast<String, dynamic>());
              v.sourceKey = source.key;
              return v;
            })
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// 播放信息
  Future<({int parse, String url, String header, String playUrl})> playerContent(
      SourceBean source, String flag, String id) async {
    final spider = SpiderLoader.instance.getSpider(source);
    final body = await spider.playerContent(
      flag: flag,
      id: id,
      vipFlags: ApiConfig.instance.vipParseFlags,
    );
    if (body.isEmpty) {
      return (parse: 0, url: id, header: '', playUrl: '');
    }
    try {
      final map = json.decode(body) as Map<String, dynamic>;
      return (
        parse: (map['parse'] is int ? map['parse'] as int : int.tryParse('${map['parse']}') ?? 0),
        url: (map['url'] ?? '').toString(),
        header: (map['header'] ?? '').toString(),
        playUrl: (map['playUrl'] ?? '').toString(),
      );
    } catch (_) {
      return (parse: 0, url: id, header: '', playUrl: '');
    }
  }

  MoviePage _parsePage(String body) {
    if (body.isEmpty) return MoviePage();
    try {
      final map = json.decode(body) as Map<String, dynamic>;
      final list = map['list'];
      final videos = <MovieVideo>[];
      if (list is List) {
        for (final m in list.whereType<Map>()) {
          videos.add(_videoFromMap(m.cast<String, dynamic>()));
        }
      }
      return MoviePage(
        page: (map['page'] is int ? map['page'] as int : int.tryParse('${map['page']}') ?? 0),
        pagecount: (map['pagecount'] is int
            ? map['pagecount'] as int
            : int.tryParse('${map['pagecount']}') ?? 0),
        pagesize: (map['limit'] is int ? map['limit'] as int : int.tryParse('${map['limit']}') ?? 0),
        recordcount:
            (map['total'] is int ? map['total'] as int : int.tryParse('${map['total']}') ?? 0),
        videoList: videos,
      );
    } catch (_) {
      return MoviePage();
    }
  }

  MovieVideo _videoFromMap(Map<String, dynamic> m) {
    final v = MovieVideo.fromJson(m);
    // 剧集线路
    final playFrom = (m['vod_play_from'] ?? '').toString();
    final playUrl = (m['vod_play_url'] ?? '').toString();
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
        v.urlList.add(VideoUrlInfo(flag: flag, urls: urlStr, episodes: episodes));
      }
    }
    return v;
  }
}
