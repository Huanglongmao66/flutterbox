// 设置页，对应原项目 com.github.tvbox.osc.ui.activity.SettingActivity
// 阶段 1 实现：API 地址配置 + 调试开关 + 配置重载
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/hawk_config.dart';
import '../../core/storage/hawk_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/log.dart';
import '../../data/api/api_config.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _apiCtrl;
  late TextEditingController _liveApiCtrl;
  bool _debugOpen = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _apiCtrl = TextEditingController(
        text: HawkStore.get<String>(HawkConfig.apiUrl, defaultValue: '') ?? '');
    _liveApiCtrl = TextEditingController(
        text: HawkStore.get<String>(HawkConfig.liveApiUrl, defaultValue: '') ?? '');
    _debugOpen = HawkStore.get<bool>(HawkConfig.debugOpen, defaultValue: false) ?? false;
  }

  @override
  void dispose() {
    _apiCtrl.dispose();
    _liveApiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('站点配置'),
          _textField(
            label: '站点 API 地址',
            controller: _apiCtrl,
            hint: '输入 CMS 配置 JSON 地址',
          ),
          const SizedBox(height: 8),
          _textField(
            label: '直播 API 地址（可选）',
            controller: _liveApiCtrl,
            hint: '留空则跟随站点 API',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton(
                onPressed: _loading ? null : _saveAndReload,
                child: const Text('保存并加载'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => _pasteFromClipboard(),
                child: const Text('粘贴'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _apiCtrl.clear(),
                child: const Text('清空'),
              ),
            ],
          ),
          const Divider(height: 32),
          _section('调试'),
          SwitchListTile(
            value: _debugOpen,
            onChanged: (v) {
              setState(() => _debugOpen = v);
              HawkStore.put(HawkConfig.debugOpen, v);
              LOG.debugOpen = v;
            },
            title: const Text('开启日志'),
            activeColor: AppColors.accent,
          ),
          const Divider(height: 32),
          _section('关于'),
          ListTile(
            leading: const Icon(Icons.info_outline, color: AppColors.textSecondary),
            title: const Text('TVBox Flutter'),
            subtitle: const Text('Flutter 重写版本 · 阶段 1 基础架构'),
          ),
          ListTile(
            leading: const Icon(Icons.layers_outlined, color: AppColors.textSecondary),
            title: const Text('当前站点数'),
            trailing: Text('${ApiConfig.instance.sources.length}',
                style: const TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(title,
          style: const TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textHint),
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textHint),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0x33FFFFFF)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.focusBorder),
        ),
      ),
      maxLines: 1,
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      _apiCtrl.text = data!.text!.trim();
    }
  }

  Future<void> _saveAndReload() async {
    final url = _apiCtrl.text.trim();
    if (url.isEmpty) {
      _toast('请输入 API 地址');
      return;
    }
    setState(() => _loading = true);
    await HawkStore.put(HawkConfig.apiUrl, url);
    if (_liveApiCtrl.text.trim().isNotEmpty) {
      await HawkStore.put(HawkConfig.liveApiUrl, _liveApiCtrl.text.trim());
    }
    await ApiConfig.instance.loadConfig(useCache: false, callback: ({required bool success, String? error}) async {
      if (!mounted) return;
      setState(() => _loading = false);
      if (success) {
        _toast('配置加载成功：${ApiConfig.instance.sources.length} 个站点');
        Navigator.of(context).pop(true);
      } else {
        _toast('加载失败：$error');
      }
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 2),
    ));
  }
}
