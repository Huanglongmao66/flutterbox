// 字幕解析，对应原项目 SubtitleLoader
// 支持 SRT 与简单 ASS/SSA 解析
import 'dart:convert';

class SubtitleCue {
  SubtitleCue({required this.start, required this.end, required this.text});

  /// 毫秒
  final int start;
  final int end;
  final String text;

  bool contains(int ms) => ms >= start && ms <= end;
}

class SubtitleParser {
  SubtitleParser._();

  /// 自动识别 SRT / ASS / VTT
  static List<SubtitleCue> parse(String body) {
    final t = body.trim();
    if (t.isEmpty) return <SubtitleCue>[];
    if (t.startsWith('[Script Info]') || t.contains('[Events]')) {
      return parseAss(body);
    }
    if (t.startsWith('WEBVTT')) {
      return parseVtt(body);
    }
    return parseSrt(body);
  }

  /// 解析 SRT
  static List<SubtitleCue> parseSrt(String body) {
    final cues = <SubtitleCue>[];
    final blocks = body
        .replaceAll('\r\n', '\n')
        .split(RegExp(r'\n\s*\n'));
    for (final block in blocks) {
      final lines = block.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length < 2) continue;
      // 第一行可能是序号，跳过
      int timeLineIdx = 0;
      if (int.tryParse(lines[0].trim()) != null) {
        timeLineIdx = 1;
      }
      if (timeLineIdx >= lines.length) continue;
      final timeParts = lines[timeLineIdx].split(' --> ');
      if (timeParts.length < 2) continue;
      final start = _parseTime(timeParts[0].trim());
      final endStr = timeParts[1].trim().split(' ').first;
      final end = _parseTime(endStr);
      final text = lines.sublist(timeLineIdx + 1).join('\n');
      if (text.isEmpty) continue;
      cues.add(SubtitleCue(start: start, end: end, text: text));
    }
    cues.sort((a, b) => a.start.compareTo(b.start));
    return cues;
  }

  /// 解析 VTT（WebVTT）
  static List<SubtitleCue> parseVtt(String body) {
    // VTT 与 SRT 类似，时间格式 00:00:01.000
    final cleaned = body.replaceFirst('WEBVTT', '').trim();
    return parseSrt(cleaned);
  }

  /// 解析 ASS/SSA（Dialogue 行）
  static List<SubtitleCue> parseAss(String body) {
    final cues = <SubtitleCue>[];
    final lines = body.split('\n');
    int startIdx = 9; // Default: Start
    int endIdx = 8; // Default: End
    int textIdx = 9; // Default: Text
    for (final line in lines) {
      final t = line.trim();
      if (t.startsWith('Format:') && t.contains('Dialogue')) {
        final fmt = t.substring(8).split(',');
        for (int i = 0; i < fmt.length; i++) {
          final f = fmt[i].trim().toLowerCase();
          if (f == 'start') startIdx = i;
          if (f == 'end') endIdx = i;
          if (f == 'text') textIdx = i;
        }
        continue;
      }
      if (t.startsWith('Dialogue:')) {
        final parts = t.substring(9).split(',');
        if (parts.length <= textIdx) continue;
        final start = _parseAssTime(parts[startIdx].trim());
        final end = _parseAssTime(parts[endIdx].trim());
        final text = parts
            .sublist(textIdx)
            .join(',')
            .replaceAll(RegExp(r'\{[^}]*\}'), '') // 去 ASS 样式标记
            .replaceAll('\\N', '\n')
            .trim();
        if (text.isEmpty) continue;
        cues.add(SubtitleCue(start: start, end: end, text: text));
      }
    }
    cues.sort((a, b) => a.start.compareTo(b.start));
    return cues;
  }

  /// SRT/VTT 时间：00:00:01,000 或 00:00:01.000
  static int _parseTime(String s) {
    final cleaned = s.replaceAll(',', '.');
    final parts = cleaned.split(':');
    if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final secParts = parts[2].split('.');
      final sec = int.tryParse(secParts[0]) ?? 0;
      final ms = secParts.length > 1
          ? (int.tryParse(secParts[1].padRight(3, '0').substring(0, 3)) ?? 0)
          : 0;
      return h * 3600000 + m * 60000 + sec * 1000 + ms;
    }
    return 0;
  }

  /// ASS 时间：0:00:01.00
  static int _parseAssTime(String s) {
    final parts = s.split(':');
    if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final secParts = parts[2].split('.');
      final sec = int.tryParse(secParts[0]) ?? 0;
      final ms = secParts.length > 1
          ? (int.tryParse(secParts[1].padRight(3, '0').substring(0, 3)) ?? 0)
          : 0;
      return h * 3600000 + m * 60000 + sec * 1000 + ms;
    }
    return 0;
  }
}

/// 读取本地字幕文件（按扩展名识别）
List<SubtitleCue> parseSubtitleFile(String content) {
  return SubtitleParser.parse(content);
}

List<SubtitleCue> parseSubtitleBytes(List<int> bytes) {
  return SubtitleParser.parse(utf8.decode(bytes, allowMalformed: true));
}
