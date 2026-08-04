// 历史记录模型，对应原项目 com.github.tvbox.osc.bean.MovieHistory
// 存储：影片标识 + 播放位置 + 剧集信息，用于"继续观看"
import 'dart:convert';

class HistoryRecord {
  HistoryRecord({
    required this.id,
    required this.sourceKey,
    required this.vodId,
    required this.name,
    this.pic = '',
    this.flag = '',
    this.episodeIndex = 0,
    this.episodeName = '',
    this.episodeUrl = '',
    this.positionMs = 0,
    this.durationMs = 0,
    this.note = '',
    required this.updateTime,
  });

  /// 唯一主键：sourceKey + vodId
  final String id;
  final String sourceKey;
  final String vodId;
  final String name;
  final String pic;
  final String flag;
  final int episodeIndex;
  final String episodeName;
  final String episodeUrl;
  final int positionMs;
  final int durationMs;
  final String note;
  final int updateTime;

  factory HistoryRecord.fromMap(Map<String, dynamic> m) => HistoryRecord(
        id: (m['id'] ?? '').toString(),
        sourceKey: (m['sourceKey'] ?? '').toString(),
        vodId: (m['vodId'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        pic: (m['pic'] ?? '').toString(),
        flag: (m['flag'] ?? '').toString(),
        episodeIndex: (m['episodeIndex'] is int ? m['episodeIndex'] as int : int.tryParse('${m['episodeIndex']}') ?? 0),
        episodeName: (m['episodeName'] ?? '').toString(),
        episodeUrl: (m['episodeUrl'] ?? '').toString(),
        positionMs: (m['positionMs'] is int ? m['positionMs'] as int : int.tryParse('${m['positionMs']}') ?? 0),
        durationMs: (m['durationMs'] is int ? m['durationMs'] as int : int.tryParse('${m['durationMs']}') ?? 0),
        note: (m['note'] ?? '').toString(),
        updateTime: (m['updateTime'] is int ? m['updateTime'] as int : int.tryParse('${m['updateTime']}') ?? 0),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'sourceKey': sourceKey,
        'vodId': vodId,
        'name': name,
        'pic': pic,
        'flag': flag,
        'episodeIndex': episodeIndex,
        'episodeName': episodeName,
        'episodeUrl': episodeUrl,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'note': note,
        'updateTime': updateTime,
      };

  String encode() => json.encode(toMap());

  static HistoryRecord decode(String s) =>
      HistoryRecord.fromMap(json.decode(s) as Map<String, dynamic>);

  HistoryRecord copyWith({
    String? flag,
    int? episodeIndex,
    String? episodeName,
    String? episodeUrl,
    int? positionMs,
    int? durationMs,
    String? note,
    int? updateTime,
    String? pic,
  }) =>
      HistoryRecord(
        id: id,
        sourceKey: sourceKey,
        vodId: vodId,
        name: name,
        pic: pic ?? this.pic,
        flag: flag ?? this.flag,
        episodeIndex: episodeIndex ?? this.episodeIndex,
        episodeName: episodeName ?? this.episodeName,
        episodeUrl: episodeUrl ?? this.episodeUrl,
        positionMs: positionMs ?? this.positionMs,
        durationMs: durationMs ?? this.durationMs,
        note: note ?? this.note,
        updateTime: updateTime ?? this.updateTime,
      );

  /// 主键构造
  static String buildId(String sourceKey, String vodId) => '$sourceKey@$vodId';
}
