// Spider 抽象接口，对应原项目 com.github.catvod.crawler.Spider
// 返回值为 JSON 字符串（与原 Spider 一致），由调用方解析
import '../../core/network/http_client.dart';

abstract class Spider {
  String siteKey = '';
  String ext = '';

  void init(String siteKey, {String extend = ''}) {
    this.siteKey = siteKey;
    ext = extend;
  }

  /// 首页数据内容（含分类）
  /// 返回 JSON: {class:[{type_id,type_name}], list:[...vod], filters:{tid:[...]}}
  Future<String> homeContent({bool filter = true});

  /// 首页最近更新数据
  Future<String> homeVideoContent();

  /// 分类数据
  /// 返回 JSON: {list:[...vod], page, pagecount, limit, total}
  Future<String> categoryContent({
    required String tid,
    required int page,
    bool filter = true,
    Map<String, String> extend = const {},
  });

  /// 详情数据
  /// ids 通常为单元素列表
  /// 返回 JSON: {list:[...vod detail]}
  Future<String> detailContent(List<String> ids);

  /// 搜索数据
  /// 返回 JSON: {list:[...vod]}
  Future<String> searchContent({
    required String key,
    bool quick = false,
    String page = '1',
  });

  /// 播放信息
  /// 返回 JSON: {parse, url, header,}
  Future<String> playerContent({
    required String flag,
    required String id,
    List<String> vipFlags = const [],
  });

  /// webview 解析时判断 url 是否是视频
  bool isVideoFormat(String url) => false;

  /// 是否手动检测 webview 加载的 url
  bool manualVideoCheck() => false;

  /// 直播 list
  Future<String> liveContent(String url);

  /// 销毁
  void destroy() {}

  /// 取消请求
  void cancelByTag() {}

  /// HTTP 工具
  Future<String> httpGet(String url, {Map<String, dynamic>? headers}) =>
      HttpClient.get(url, headers: headers);

  Future<String> httpPost(String url,
          {dynamic data, Map<String, dynamic>? headers}) =>
      HttpClient.post(url, data: data, headers: headers);
}
