// 投屏页，对应原项目 DLNACastManager 的设备选择 UI
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/log.dart';
import 'cast_manager.dart';

class CastPage extends StatefulWidget {
  const CastPage({super.key, this.castUrl, this.castTitle});

  /// 待投屏的播放地址（从播放器进入时传入）
  final String? castUrl;
  final String? castTitle;

  @override
  State<CastPage> createState() => _CastPageState();
}

class _CastPageState extends State<CastPage> {
  final CastManager _manager = CastManager.instance;
  StreamSubscription<List<DlnaDevice>>? _sub;
  DlnaDevice? _selected;
  bool _casting = false;

  @override
  void initState() {
    super.initState();
    _sub = _manager.deviceStream.listen((list) {
      if (mounted) setState(() {});
    });
    _manager.startSearch();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _manager.stopSearch();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _selected = null);
    await _manager.startSearch();
  }

  Future<void> _onCast(DlnaDevice device) async {
    if (widget.castUrl == null || widget.castUrl!.isEmpty) {
      // 无投屏内容，仅选中设备
      setState(() => _selected = device);
      return;
    }
    setState(() {
      _selected = device;
      _casting = true;
    });
    try {
      final ok = await _manager.cast(
        device,
        widget.castUrl!,
        title: widget.castTitle,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? '已投屏至 ${device.name}' : '投屏失败'),
          duration: const Duration(seconds: 2),
        ));
        if (ok) Navigator.of(context).pop();
      }
    } catch (e) {
      LOG.e('CastPage', '投屏失败', e);
    } finally {
      if (mounted) setState(() => _casting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices = _manager.devices;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('投屏'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: '重新搜索',
          ),
        ],
      ),
      body: Column(
        children: [
          // 状态条
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.card,
            child: Row(
              children: [
                if (_manager.isSearching)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.cast_connected, color: AppColors.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _manager.isSearching
                        ? '正在搜索 DLNA 设备...'
                        : '共发现 ${devices.length} 个设备',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
                if (widget.castUrl != null)
                  const Icon(Icons.airplay, color: AppColors.accent, size: 18),
              ],
            ),
          ),
          // 设备列表
          Expanded(
            child: devices.isEmpty && !_manager.isSearching
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cast, size: 56, color: AppColors.textHint),
                        SizedBox(height: 12),
                        Text('未发现设备，请确认设备已开启 DLNA',
                            style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: devices.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, i) {
                      final d = devices[i];
                      final selected = _selected == d;
                      return ListTile(
                        leading: Icon(
                          Icons.tv,
                          color: selected ? AppColors.accent : AppColors.textHint,
                        ),
                        title: Text(d.name,
                            style: TextStyle(
                              color: selected ? AppColors.accent : AppColors.text,
                            )),
                        subtitle: Text(d.avTransportUrl,
                            style: const TextStyle(
                                color: AppColors.textHint, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        trailing: _casting && selected
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(Icons.chevron_right, color: AppColors.textHint),
                        onTap: () => _onCast(d),
                      );
                    },
                  ),
          ),
          // 选中设备的控制条
          if (_selected != null && widget.castUrl != null)
            _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.card,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            tooltip: '播放',
            icon: const Icon(Icons.play_arrow, color: AppColors.accent),
            onPressed: () => _manager.play(_selected!),
          ),
          IconButton(
            tooltip: '暂停',
            icon: const Icon(Icons.pause, color: AppColors.text),
            onPressed: () => _manager.pause(_selected!),
          ),
          IconButton(
            tooltip: '停止',
            icon: const Icon(Icons.stop, color: AppColors.pink),
            onPressed: () => _manager.stop(_selected!),
          ),
        ],
      ),
    );
  }
}
