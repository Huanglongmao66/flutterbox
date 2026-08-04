// 历史记录仓库，对应原项目 HistoryRepository + Room history 表
// 基于 HawkStore (Hive) 存储，按 updateTime 倒序
import '../../core/storage/hawk_store.dart';
import '../models/history_record.dart';

class HistoryRepository {
  HistoryRepository._();
  static final HistoryRepository instance = HistoryRepository._();

  List<HistoryRecord> _cache = <HistoryRecord>[];

  /// 加载到内存（启动时调用一次）
  Future<void> init() async {
    _cache = _readAll();
  }

  List<HistoryRecord> get all => List.unmodifiable(_cache);

  HistoryRecord? get(String sourceKey, String vodId) {
    final id = HistoryRecord.buildId(sourceKey, vodId);
    for (final r in _cache) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// 新增或更新一条历史
  Future<void> upsert(HistoryRecord record) async {
    final id = record.id;
    _cache.removeWhere((r) => r.id == id);
    _cache.insert(0, record);
    // 限制最多 500 条
    if (_cache.length > 500) {
      _cache = _cache.sublist(0, 500);
    }
    await _writeAll();
  }

  /// 更新播放进度（若记录不存在则忽略）
  Future<void> updateProgress(String sourceKey, String vodId,
      {int? positionMs, int? durationMs}) async {
    final id = HistoryRecord.buildId(sourceKey, vodId);
    final idx = _cache.indexWhere((r) => r.id == id);
    if (idx < 0) return;
    final cur = _cache[idx];
    _cache[idx] = cur.copyWith(
      positionMs: positionMs ?? cur.positionMs,
      durationMs: durationMs ?? cur.durationMs,
      updateTime: DateTime.now().millisecondsSinceEpoch,
    );
    await _writeAll();
  }

  Future<void> remove(String sourceKey, String vodId) async {
    final id = HistoryRecord.buildId(sourceKey, vodId);
    _cache.removeWhere((r) => r.id == id);
    await _writeAll();
  }

  Future<void> removeById(String id) async {
    _cache.removeWhere((r) => r.id == id);
    await _writeAll();
  }

  Future<void> clear() async {
    _cache.clear();
    await _writeAll();
  }

  List<HistoryRecord> _readAll() {
    final raw = HawkStore.get<List>(HistoryKeys.historyRecords);
    if (raw == null) return <HistoryRecord>[];
    try {
      return raw
          .map((e) => HistoryRecord.fromMap(
              (e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})))
          .where((r) => r.id.isNotEmpty)
          .toList()
        ..sort((a, b) => b.updateTime.compareTo(a.updateTime));
    } catch (_) {
      return <HistoryRecord>[];
    }
  }

  Future<void> _writeAll() async {
    await HawkStore.put(
        HistoryKeys.historyRecords, _cache.map((r) => r.toMap()).toList());
  }
}

/// 内部使用的 key 常量（避免与原 HawkConfig 冲突，统一收纳）
class HistoryKeys {
  HistoryKeys._();
  static const String historyRecords = 'history_records';
  static const String collectRecords = 'collect_records';
}
