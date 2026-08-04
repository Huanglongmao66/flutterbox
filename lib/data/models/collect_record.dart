// 收藏记录模型，对应原项目 com.github.tvbox.osc.bean.MovieCollection
import 'dart:convert';

class CollectRecord {
  CollectRecord({
    required this.id,
    required this.sourceKey,
    required this.vodId,
    required this.name,
    this.pic = '',
    this.note = '',
    this.type = '',
    this.year = 0,
    this.area = '',
    this.actor = '',
    this.director = '',
    required this.updateTime,
  });

  final String id;
  final String sourceKey;
  final String vodId;
  final String name;
  final String pic;
  final String note;
  final String type;
  final int year;
  final String area;
  final String actor;
  final String director;
  final int updateTime;

  factory CollectRecord.fromMap(Map<String, dynamic> m) => CollectRecord(
        id: (m['id'] ?? '').toString(),
        sourceKey: (m['sourceKey'] ?? '').toString(),
        vodId: (m['vodId'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        pic: (m['pic'] ?? '').toString(),
        note: (m['note'] ?? '').toString(),
        type: (m['type'] ?? '').toString(),
        year: (m['year'] is int ? m['year'] as int : int.tryParse('${m['year']}') ?? 0),
        area: (m['area'] ?? '').toString(),
        actor: (m['actor'] ?? '').toString(),
        director: (m['director'] ?? '').toString(),
        updateTime: (m['updateTime'] is int ? m['updateTime'] as int : int.tryParse('${m['updateTime']}') ?? 0),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'sourceKey': sourceKey,
        'vodId': vodId,
        'name': name,
        'pic': pic,
        'note': note,
        'type': type,
        'year': year,
        'area': area,
        'actor': actor,
        'director': director,
        'updateTime': updateTime,
      };

  String encode() => json.encode(toMap());

  static CollectRecord decode(String s) =>
      CollectRecord.fromMap(json.decode(s) as Map<String, dynamic>);

  static String buildId(String sourceKey, String vodId) => '$sourceKey@$vodId';
}
