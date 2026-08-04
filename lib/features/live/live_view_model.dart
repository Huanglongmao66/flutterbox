// 直播 ViewModel，对应原项目 LivePlayActivity 的数据逻辑
import 'package:flutter/foundation.dart';

import '../../data/models/live_channel.dart';
import '../../data/repositories/live_repository.dart';

enum LiveLoadState { idle, loading, loaded, empty, error }

class LiveViewModel extends ChangeNotifier {
  LiveViewModel();

  LiveLoadState _state = LiveLoadState.idle;
  String _errorMsg = '';
  List<LiveGroup> _groups = <LiveGroup>[];
  List<LiveChannel> _filteredChannels = <LiveChannel>[];
  int _currentGroupIndex = 0;
  int _currentChannelIndex = -1;
  int _currentUrlIndex = 0;
  String _keyword = '';

  LiveLoadState get state => _state;
  String get errorMsg => _errorMsg;
  List<LiveGroup> get groups => _groups;
  List<LiveChannel> get channels => _filteredChannels;
  int get currentGroupIndex => _currentGroupIndex;
  int get currentChannelIndex => _currentChannelIndex;
  int get currentUrlIndex => _currentUrlIndex;
  String get keyword => _keyword;

  LiveChannel? get currentChannel =>
      _currentChannelIndex >= 0 && _currentChannelIndex < _filteredChannels.length
          ? _filteredChannels[_currentChannelIndex]
          : null;

  List<String> get groupNames => _groups.map((g) => g.name).toList();

  Future<void> load() async {
    _state = LiveLoadState.loading;
    notifyListeners();
    try {
      _groups = await LiveRepository.instance.load();
      if (_groups.isEmpty) {
        _state = LiveLoadState.empty;
        _errorMsg = '未配置直播源或加载失败';
      } else {
        _state = LiveLoadState.loaded;
        _applyFilter();
      }
    } catch (e) {
      _state = LiveLoadState.error;
      _errorMsg = '$e';
    }
    notifyListeners();
  }

  void selectGroup(int index) {
    if (index < 0 || index >= _groups.length) return;
    _currentGroupIndex = index;
    _applyFilter();
    _currentChannelIndex = -1;
    notifyListeners();
  }

  void setKeyword(String kw) {
    _keyword = kw;
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    if (_groups.isEmpty) {
      _filteredChannels = <LiveChannel>[];
      return;
    }
    // 关键词搜索跨组，否则当前组
    if (_keyword.isNotEmpty) {
      final kw = _keyword.toLowerCase();
      _filteredChannels = _groups
          .expand((g) => g.channels)
          .where((c) => c.name.toLowerCase().contains(kw))
          .toList();
    } else if (_currentGroupIndex < _groups.length) {
      _filteredChannels = _groups[_currentGroupIndex].channels;
    } else {
      _filteredChannels = <LiveChannel>[];
    }
  }

  /// 选中频道，返回要播放的 URL
  LiveChannelUrl? selectChannel(int index) {
    if (index < 0 || index >= _filteredChannels.length) return null;
    _currentChannelIndex = index;
    _currentUrlIndex = 0;
    notifyListeners();
    final ch = _filteredChannels[index];
    return ch.urls.isNotEmpty ? ch.urls.first : null;
  }

  /// 切换当前频道的备用线路
  LiveChannelUrl? switchLine(int offset) {
    final ch = currentChannel;
    if (ch == null || ch.urls.isEmpty) return null;
    _currentUrlIndex = (_currentUrlIndex + offset) % ch.urls.length;
    if (_currentUrlIndex < 0) _currentUrlIndex += ch.urls.length;
    notifyListeners();
    return ch.urls[_currentUrlIndex];
  }

  /// 切换到上/下一个频道
  LiveChannelUrl? switchChannel(int offset) {
    if (_filteredChannels.isEmpty) return null;
    var next = _currentChannelIndex + offset;
    if (next < 0) next = 0;
    if (next >= _filteredChannels.length) next = _filteredChannels.length - 1;
    return selectChannel(next);
  }
}
