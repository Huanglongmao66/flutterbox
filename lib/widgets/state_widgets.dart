// 通用状态占位：加载中 / 空 / 错误
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.tip = '加载中...'});
  final String tip;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
          const SizedBox(height: 12),
          Text(tip, style: const TextStyle(color: AppColors.textHint, fontSize: 13)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, this.tip = '暂无数据', this.icon = Icons.inbox_outlined});
  final String tip;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(tip, style: const TextStyle(color: AppColors.textHint, fontSize: 13)),
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.msg, this.onRetry});
  final String msg;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.pink),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textHint, fontSize: 13),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ],
      ),
    );
  }
}
