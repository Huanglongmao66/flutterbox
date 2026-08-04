// TV 焦点管理，对应原项目焦点树 + 遥控器按键处理
// 提供 TvFocusable 通用组件：焦点高亮 + 方向键导航 + 确认键回调 + 自动滚动可见
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

/// TV 焦点通用包装组件
/// 任意子组件包装后即支持：方向键导航、焦点高亮、确认键回调、自动滚动可见
class TvFocusable extends StatefulWidget {
  const TvFocusable({
    super.key,
    required this.child,
    this.onTap,
    this.focusNode,
    this.autofocus = false,
    this.borderRadius = 6.0,
    this.scale = 1.05,
    this.enableHighlight = true,
    this.padding,
  });

  final Widget child;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool autofocus;
  final double borderRadius;
  final double scale;
  final bool enableHighlight;
  final EdgeInsets? padding;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  late final FocusNode _node;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node = widget.focusNode ?? FocusNode();
    _node.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChange);
    if (widget.focusNode == null) _node.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final f = _node.hasFocus;
    if (f != _focused) {
      setState(() => _focused = f);
      // 焦点获得时滚动可见
      if (f) _ensureVisible();
    }
  }

  void _ensureVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _node.context;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            alignment: 0.5,
            duration: const Duration(milliseconds: 200));
      }
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    // 确认键 / 中央 OK 键 / 回车 → 触发 onTap
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA) {
      widget.onTap?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onKeyEvent: _onKey,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          transform: _focused && widget.scale != 1.0
              ? Matrix4.diagonal3Values(widget.scale, widget.scale, 1.0)
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          padding: widget.padding,
          decoration: widget.enableHighlight
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(
                    color: _focused
                        ? AppColors.focusBorder
                        : Colors.transparent,
                    width: _focused ? 2 : 0,
                  ),
                )
              : null,
          child: widget.child,
        ),
      ),
    );
  }
}

/// TV 顶栏/导航按钮（图标 + 文字），带焦点高亮
class TvIconButton extends StatelessWidget {
  const TvIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.focusNode,
    this.autofocus = false,
    this.size = 20,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final bool autofocus;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      borderRadius: 4,
      scale: 1.0,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: size),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

/// TV 胶囊导航项（分类标签）
class TvNavChip extends StatelessWidget {
  const TvNavChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.focusNode,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      borderRadius: 16,
      scale: 1.0,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.accent : const Color(0x33FFFFFF),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.background : AppColors.textPrimary,
            fontSize: 14,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// 应用级 TV 焦点配置：包裹根 Widget，启用方向键遍历
/// Flutter 内置焦点系统已自动处理方向键（D-pad）的空间导航，
/// 此处仅提供分组与默认策略，确保遥控器上下左右可在可聚焦组件间移动
class TvFocusScope extends StatelessWidget {
  const TvFocusScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: child,
    );
  }
}

/// 是否为 TV / 遥控器环境（Android TV 识别）
bool get isTvDevice {
  // 简化判断：Android 平台视为 TV 环境
  // 实际可通过 platform channel 查询 UI_MODE_TELEVISION
  return isAndroid;
}
