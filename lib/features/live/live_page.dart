// 直播页，对应原项目 com.github.tvbox.osc.ui.activity.LivePlayActivity
// 左侧播放器 + 右侧频道列表（分组/搜索/线路切换）
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/log.dart';
import '../../data/models/live_channel.dart';
import '../../widgets/state_widgets.dart';
import 'live_view_model.dart';

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  late LiveViewModel _vm;
  late final Player _player;
  late final VideoController _controller;
  final TextEditingController _searchCtrl = TextEditingController();
  bool _controlsVisible = true;
  Timer? _hideTimer;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _vm = LiveViewModel();
    _player = Player();
    _controller = VideoController(_player);
    _vm.load();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _searchCtrl.dispose();
    _player.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _playChannel(LiveChannelUrl url) async {
    setState(() => _loading = true);
    try {
      await _player.open(Media(url.url));
    } catch (e) {
      LOG.e('Live', '播放失败：${url.url}', e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _player.state.playing) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _vm,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer<LiveViewModel>(
          builder: (context, vm, _) {
            if (vm.state == LiveLoadState.loading) {
              return const LoadingState(tip: '加载直播源...');
            }
            if (vm.state == LiveLoadState.empty ||
                vm.state == LiveLoadState.error) {
              return ErrorState(
                msg: vm.errorMsg.isEmpty ? '未配置直播源' : vm.errorMsg,
                onRetry: () => vm.load(),
              );
            }
            return Row(
              children: [
                Expanded(child: _buildPlayer(vm)),
                _buildSidePanel(vm),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlayer(LiveViewModel vm) {
    final ch = vm.currentChannel;
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: _showControls,
          child: Video(
            controller: _controller,
            fit: BoxFit.contain,
            controls: NoVideoControls,
          ),
        ),
        if (_loading)
          const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
        if (_controlsVisible) _buildTopBar(vm, ch),
        if (_controlsVisible) _buildBottomBar(vm, ch),
      ],
    );
  }

  Widget _buildTopBar(LiveViewModel vm, LiveChannel? ch) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 12, 16, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black54, Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ch != null
                    ? '${ch.name}${ch.urls.length > 1 ? ' (${vm.currentUrlIndex + 1}/${ch.urls.length})' : ''}'
                    : '直播',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (ch != null && ch.urls.length > 1)
              IconButton(
                icon: const Icon(Icons.swap_horiz, color: Colors.white),
                tooltip: '切换线路',
                onPressed: () {
                  final url = vm.switchLine(1);
                  if (url != null) _playChannel(url);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(LiveViewModel vm, LiveChannel? ch) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black54, Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous, color: Colors.white),
              tooltip: '上一个频道',
              onPressed: () {
                final url = vm.switchChannel(-1);
                if (url != null) _playChannel(url);
              },
            ),
            const SizedBox(width: 24),
            StreamBuilder<bool>(
              stream: _player.stream.playing,
              initialData: _player.state.playing,
              builder: (context, snapshot) {
                final playing = snapshot.data ?? false;
                return IconButton(
                  iconSize: 40,
                  icon: Icon(
                    playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    if (playing) {
                      _player.pause();
                    } else {
                      _player.play();
                    }
                  },
                );
              },
            ),
            const SizedBox(width: 24),
            IconButton(
              icon: const Icon(Icons.skip_next, color: Colors.white),
              tooltip: '下一个频道',
              onPressed: () {
                final url = vm.switchChannel(1);
                if (url != null) _playChannel(url);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidePanel(LiveViewModel vm) {
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: Color(0x33FFFFFF))),
      ),
      child: Column(
        children: [
          // 顶栏：返回 + 搜索
          Container(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Row(
              children: [
                const Text('直播',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '搜索频道',
                      hintStyle: TextStyle(color: AppColors.textHint, fontSize: 13),
                      prefixIcon: Icon(Icons.search, color: AppColors.textHint, size: 18),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0x33FFFFFF)),
                          borderRadius: BorderRadius.all(Radius.circular(20))),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.focusBorder),
                          borderRadius: BorderRadius.all(Radius.circular(20))),
                    ),
                    onChanged: (v) => vm.setKeyword(v),
                  ),
                ),
              ],
            ),
          ),
          // 分组列表
          if (vm.keyword.isEmpty)
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: vm.groupNames.length,
                itemBuilder: (context, index) {
                  final name = vm.groupNames[index];
                  final selected = index == vm.currentGroupIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => vm.selectGroup(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? AppColors.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected ? AppColors.accent : const Color(0x33FFFFFF),
                          ),
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            color: selected ? AppColors.background : AppColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const Divider(height: 1, color: Color(0x22FFFFFF)),
          // 频道列表
          Expanded(
            child: vm.channels.isEmpty
                ? const EmptyState(tip: '无频道', icon: Icons.live_tv)
                : ListView.builder(
                    itemCount: vm.channels.length,
                    itemBuilder: (context, index) {
                      final ch = vm.channels[index];
                      final selected = index == vm.currentChannelIndex;
                      return ListTile(
                        dense: true,
                        selected: selected,
                        selectedTileColor: AppColors.accent.withValues(alpha: 0.18),
                        title: Text(
                          ch.name,
                          style: TextStyle(
                            color: selected ? AppColors.accent : AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: ch.urls.length > 1
                            ? Text('${ch.urls.length}',
                                style: const TextStyle(
                                    color: AppColors.textHint, fontSize: 11))
                            : null,
                        onTap: () {
                          final url = vm.selectChannel(index);
                          if (url != null) _playChannel(url);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
