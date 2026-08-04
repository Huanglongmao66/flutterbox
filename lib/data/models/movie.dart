// 影片信息，对应原项目 com.github.tvbox.osc.bean.Movie
// 同时作为列表项和详情数据载体（原 Movie.Video + VodInfo 合并场景在 vod_info.dart）
class MovieVideo {
  MovieVideo({
    this.last = '',
    this.id = '',
    this.tid = 0,
    this.name = '',
    this.type = '',
    this.pic = '',
    this.lang = '',
    this.area = '',
    this.year = 0,
    this.state = '',
    this.note = '',
    this.actor = '',
    this.director = '',
    List<VideoUrlInfo>? urlList,
    this.des = '',
    this.sourceKey = '',
    this.tag = '',
    this.action = '',
  }) : urlList = urlList ?? <VideoUrlInfo>[];

  String last;
  String id;
  int tid;
  String name;
  String type;
  String pic;
  String lang;
  String area;
  int year;
  String state;
  String note;
  String actor;
  String director;
  List<VideoUrlInfo> urlList;
  String des;
  String sourceKey;
  String tag;
  String action;

  factory MovieVideo.fromJson(Map<String, dynamic> json) {
    return MovieVideo(
      last: (json['last'] ?? json['vod_time'] ?? '').toString(),
      id: (json['id'] ?? json['vod_id'] ?? '').toString(),
      tid: int.tryParse('${json['tid'] ?? json['type_id'] ?? 0}') ?? 0,
      name: (json['name'] ?? json['vod_name'] ?? '').toString(),
      type: (json['type'] ?? json['type_name'] ?? '').toString(),
      pic: (json['pic'] ?? json['vod_pic'] ?? '').toString(),
      lang: (json['lang'] ?? json['vod_lang'] ?? '').toString(),
      area: (json['area'] ?? json['vod_area'] ?? '').toString(),
      year: int.tryParse('${json['year'] ?? json['vod_year'] ?? 0}') ?? 0,
      state: (json['state'] ?? json['vod_state'] ?? '').toString(),
      note: (json['note'] ?? json['vod_remarks'] ?? '').toString(),
      actor: (json['actor'] ?? json['vod_actor'] ?? '').toString(),
      director: (json['director'] ?? json['vod_director'] ?? '').toString(),
      des: (json['des'] ?? json['vod_content'] ?? '').toString(),
      tag: (json['tag'] ?? json['vod_tag'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      urlList: const [],
    );
  }
}

class VideoUrlInfo {
  VideoUrlInfo({this.flag = '', this.urls = '', List<VideoEpisode>? episodes})
      : episodes = episodes ?? <VideoEpisode>[];

  String flag; // 播放线路名（如 zuidam3u8）
  String urls; // 原始拼接串
  List<VideoEpisode> episodes; // 解析后的剧集列表
}

class VideoEpisode {
  VideoEpisode({this.name = '', this.url = ''});

  String name;
  String url;

  @override
  String toString() => 'VideoEpisode($name, $url)';
}

/// 列表分页信息，对应原 Movie 顶层
class MoviePage {
  MoviePage({
    this.page = 0,
    this.pagecount = 0,
    this.pagesize = 0,
    this.recordcount = 0,
    List<MovieVideo>? videoList,
    this.msg = '',
  }) : videoList = videoList ?? <MovieVideo>[];

  int page;
  int pagecount;
  int pagesize;
  int recordcount;
  List<MovieVideo> videoList;
  String msg;
}
