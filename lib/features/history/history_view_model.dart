// 历史记录 ViewModel，对应原项目 HistoryActivity 的数据逻辑
import 'package:flutter/foundation.dart';

import '../../data/models/history_record.dart';
import '../../data/repositories/history_repository.dart';

enum HistoryLoadState { idle, loading, loaded, empty }

class HistoryViewModel extends ChangeNotifier {
  HistoryViewModel();

  HistoryLoadState _state = HistoryLoadState.idle;
  List<HistoryRecord> _records = <HistoryRecord>[];
  String _keyword = '';

  HistoryLoadState get state => _state;
  List<HistoryRecord> get records => _records;
  String get keyword => _keyword;

  List<HistoryRecord> get filtered {
    if (_keyword.isEmpty) return _records;
    final kw = _keyword.toLowerCase();
    return _records
        .where((r) => r.name.toLowerCase().contains(kw))
        .toList();
  }

  Future<void> refresh() async {
    _state = HistoryLoadState.loading;
    notifyListeners();
    _records = HistoryRepository.instance.all;
    _state = _records.isEmpty ? HistoryLoadState.empty : HistoryLoadState.loaded;
    notifyListeners();
  }

  void setKeyword(String kw) {
    _keyword = kw;
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await HistoryRepository.instance.removeById(id);
    await refresh();
  }

  Future<void> clearAll() async {
    await HistoryRepository.instance.clear();
    await refresh();
  }
}
