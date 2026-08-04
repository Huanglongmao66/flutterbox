// 影片详情，对应原项目 com.github.tvbox.osc.bean.VodInfo
// 由 Movie.Video 转换而来，承载剧集线路 + 播放状态
import 'movie.dart';

class VodInfo {
  VodInfo({
    this.last = '',
    this.id = '',
    this.tid = 0,
    this.name = '',
    this.type = '',
    this.dt = '',
    this.pic = '',
    this.lang = '',
    this.area = '',
    this.year = 0,
    this.state = '',
    this.note = '',
    this.actor = '',
    this.director = '',
    List<VodSeriesFlag>? seriesFlags,
    Map<String, List<VodSeries>>? seriesMap,
    this.des = '',
    this.playFlag,
    this.playIndex = 0,
    this.playNote = '',
    this.sourceKey = '',
    this.playerCfg = '',
    this.reverseSort = false,
  })  : seriesFlags = seriesFlags ?? <VodSeriesFlag>[],
        seriesMap = seriesMap ?? <String, List<VodSeries>>{};

  String last;
  String id;
  int tid;
  String name;
  String type;
  String dt;
  String pic;
  String lang;
  String area;
  int year;
  String state;
  String note;
  String actor;
  String director;
  List<VodSeriesFlag> seriesFlags;
  Map<String, List<VodSeries>> seriesMap;
  String des;
  String? playFlag;
  int playIndex;
  String playNote;
  String sourceKey;
  String playerCfg;
  bool reverseSort;

  /// 从 Movie.Video 填充详情字段 + 剧集
  void setVideo(MovieVideo video) {
    last = video.last;
    id = video.id;
    tid = video.tid;
    name = video.name;
    type = video.type;
    pic = video.pic;
    lang = video.lang;
    area = video.area;
    year = video.year;
    state = video.state;
    note = video.note;
    actor = video.actor;
    director = video.director;
    des = video.des;
    sourceKey = video.sourceKey;

    if (video.urlList.isNotEmpty) {
      final temp = <String, List<VodSeries>>{};
      seriesFlags = <VodSeriesFlag>[];
      for (final info in video.urlList) {
        if (info.episodes.isEmpty) continue;
        final list = info.episodes
            .map((e) => VodSeries(name: e.name, url: e.url))
            .toList();
        temp[info.flag] = list;
        seriesFlags.add(VodSeriesFlag(info.flag));
      }

      seriesMap = <String, List<VodSeries>>{};
      for (final flag in seriesFlags) {
        final list = temp[flag.name];
        if (list == null) continue;
        if (seriesFlags.length <= 5 && _shouldReverse(list)) {
          _reverseInPlace(list);
        }
        seriesMap[flag.name] = list;
      }
    }
  }

  void reverse() {
    for (final list in seriesMap.values) {
      _reverseInPlace(list);
    }
  }

  void _reverseInPlace(List<VodSeries> list) {
    int i = 0, j = list.length - 1;
    while (i < j) {
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
      i++;
      j--;
    }
  }

  static final _numReg = RegExp(r'\d+');

  int _extractNumber(String name) {
    final m = _numReg.firstMatch(name);
    if (m == null) return 0;
    return int.tryParse(m.group(0)!) ?? 0;
  }

  bool _shouldReverse(List<VodSeries> list) {
    int ascCount = 0, descCount = 0;
    final limit = (list.length - 1).clamp(0, 6);
    for (int i = 0; i < limit; i++) {
      final cur = _extractNumber(list[i].name);
      final next = _extractNumber(list[i + 1].name);
      if (cur < next) {
        ascCount++;
        if (ascCount == 2) return false;
      } else if (cur > next) {
        descCount++;
        if (descCount == 2) return true;
      }
    }
    return false;
  }
}

class VodSeriesFlag {
  VodSeriesFlag(this.name, {this.selected = false});

  String name;
  bool selected;
}

class VodSeries {
  VodSeries({this.name = '', this.url = '', this.selected = false});

  String name;
  String url;
  bool selected;
}
