// 解析接口，对应原项目 com.github.tvbox.osc.bean.ParseBean
import 'dart:convert';

import '../../core/constants/app_constants.dart';

class ParseBean {
  ParseBean({
    this.name = '',
    this.url = '',
    this.ext = '',
    this.type = AppConstants.parseTypeSniff,
    this.isDefault = false,
  });

  String name;
  String url;
  String ext;
  int type; // 0 普通嗅探 1 json 2 Json扩展 3 聚合
  bool isDefault;

  factory ParseBean.fromJson(Map<String, dynamic> json) {
    return ParseBean(
      name: (json['name'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      ext: (json['ext'] ?? '').toString(),
      type: json['type'] is int
          ? json['type'] as int
          : int.tryParse('${json['type']}') ?? AppConstants.parseTypeSniff,
      isDefault: json['default'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'ext': ext,
        'type': type,
        'default': isDefault,
      };

  /// 组合 ext 到 url（cat_ext 参数），对应原 mixUrl
  String mixUrl() {
    if (ext.isNotEmpty) {
      final idx = url.indexOf('?');
      if (idx > 0) {
        final extB64 = base64Url.encode(utf8.encode(ext)).replaceAll('=', '');
        return '${url.substring(0, idx + 1)}cat_ext=$extB64&${url.substring(idx + 1)}';
      }
    }
    return url;
  }
}
