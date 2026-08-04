// 详情页 ViewModel，对应原项目 DetailActivity + SourceViewModel 的详情逻辑
import 'package:flutter/foundation.dart';

import '../../data/api/api_config.dart';
import '../../data/models/models.dart';
import '../../data/repositories/collect_repository.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/source_repository.dart';

enum DetailLoadState { idle, loading, loaded, error }

class DetailViewModel extends ChangeNotifier {
  DetailViewModel();

  DetailLoadState _state = DetailLoadState.idle;
  String _errorMsg = '';
  MovieVideo? _video;
  VodInfo? _vodInfo;
  String _currentFlag = '';
  int _currentEpisode = 0;
  bool _collected = false;

  // 多源切换
  final List<SourceBean> _sameNameSources = [];
  int _sourceIndex = 0;

  DetailLoadState get state => _state;
  String get errorMsg => _errorMsg;
  MovieVideo? get video => _video;
  VodInfo? get vodInfo => _vodInfo;
  String get currentFlag => _currentFlag;
  int get currentEpisode => _currentEpisode;
  bool get collected => _collected;
  List<VideoUrlInfo> get urlList => _video?.urlList ?? [];
  List<VideoEpisode> get episodes =>
      _video?.urlList.where((u) => u.flag == _currentFlag).expand((u) => u.episodes).toList() ?? [];
  List<SourceBean> get sameNameSources => _sameNameSources;
  int get sourceIndex => _sourceIndex;

  Future<void> load({required String sourceKey, required String vodId, String title = ''}) async {
    _state = DetailLoadState.loading;
    notifyListeners();
    try {
      var source = ApiConfig.instance.getSource(sourceKey);
      if (source == null) {
        _state = DetailLoadState.error;
        _errorMsg = '站点不存在：$sourceKey';
        notifyListeners();
        return;
      }
      final v = await SourceRepository.instance.detailContent(source, vodId);
      if (v == null) {
        _state = DetailLoadState.error;
        _errorMsg = '获取详情失败';
        notifyListeners();
        return;
      }
      _video = v;
      _vodInfo = VodInfo();
      _vodInfo!.setVideo(v);
      if (v.urlList.isNotEmpty) {
        _currentFlag = v.urlList.first.flag;
      }
      // 恢复历史播放位置
      _restoreFromHistory(sourceKey, vodId);
      // 检查收藏状态
      _collected = CollectRepository.instance.exists(sourceKey, vodId);
      _state = DetailLoadState.loaded;
      _errorMsg = '';
    } catch (e) {
      _state = DetailLoadState.error;
      _errorMsg = '$e';
    }
    notifyListeners();
  }

  /// 从历史记录恢复线路与集数
  void _restoreFromHistory(String sourceKey, String vodId) {
    final h = HistoryRepository.instance.get(sourceKey, vodId);
    if (h == null) return;
    if (h.flag.isNotEmpty) {
      _currentFlag = h.flag;
    }
    _currentEpisode = h.episodeIndex;
  }

  void selectFlag(String flag) {
    if (_currentFlag == flag) return;
    _currentFlag = flag;
    _currentEpisode = 0;
    notifyListeners();
  }

  void selectEpisode(int index) {
    _currentEpisode = index;
    notifyListeners();
  }

  /// 选中并记录历史（点击播放时调用）
  Future<void> selectEpisodeAndRecord(int index) async {
    _currentEpisode = index;
    notifyListeners();
    await _recordHistory();
  }

  /// 记录/更新历史
  Future<void> _recordHistory() async {
    final v = _video;
    if (v == null) return;
    final eps = episodes;
    final epIndex = _currentEpisode;
    final ep = epIndex < eps.length ? eps[epIndex] : null;
    final id = HistoryRecord.buildId(v.sourceKey, v.id);
    final existing = HistoryRepository.instance.get(v.sourceKey, v.id);
    await HistoryRepository.instance.upsert(HistoryRecord(
      id: id,
      sourceKey: v.sourceKey,
      vodId: v.id,
      name: v.name,
      pic: v.pic,
      flag: _currentFlag,
      episodeIndex: epIndex,
      episodeName: ep?.name ?? '',
      episodeUrl: ep?.url ?? '',
      positionMs: existing?.positionMs ?? 0,
      durationMs: existing?.durationMs ?? 0,
      note: v.note,
      updateTime: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  /// 切换收藏
  Future<void> toggleCollect() async {
    final v = _video;
    if (v == null) return;
    final id = CollectRecord.buildId(v.sourceKey, v.id);
    if (_collected) {
      await CollectRepository.instance.removeById(id);
      _collected = false;
    } else {
      await CollectRepository.instance.upsert(CollectRecord(
        id: id,
        sourceKey: v.sourceKey,
        vodId: v.id,
        name: v.name,
        pic: v.pic,
        note: v.note,
        type: v.type,
        year: v.year,
        area: v.area,
        actor: v.actor,
        director: v.director,
        updateTime: DateTime.now().millisecondsSinceEpoch,
      ));
      _collected = true;
    }
    notifyListeners();
  }

  /// 更新播放进度（播放器回调）
  Future<void> updatePlayProgress(int positionMs, int durationMs) async {
    final v = _video;
    if (v == null) return;
    await HistoryRepository.instance.updateProgress(
      v.sourceKey,
      v.id,
      positionMs: positionMs,
      durationMs: durationMs,
    );
  }
}
