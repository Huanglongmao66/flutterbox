// 日志工具，对应原项目 com.github.tvbox.osc.util.LOG
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

class LOG {
  static bool debugOpen = true;

  static void d(String tag, String msg) {
    if (!debugOpen) return;
    final line = '[$tag] $msg';
    if (kReleaseMode) {
      dev.log(line);
    } else {
      // ignore: avoid_print
      print('DEBUG $line');
    }
  }

  static void e(String tag, String msg, [Object? error]) {
    final line = '[$tag] $msg${error == null ? '' : ' :: $error'}';
    if (kReleaseMode) {
      dev.log(line, level: 1000);
    } else {
      // ignore: avoid_print
      print('ERROR $line');
    }
  }

  static void i(String tag, String msg) => d(tag, msg);
  static void w(String tag, String msg) => d(tag, 'WARN $msg');
}
