// 应用入口，对应原项目 com.github.tvbox.osc.base.App
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/focus/tv_focus.dart';
import 'core/network/http_client.dart';
import 'core/storage/hawk_store.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/log.dart';
import 'data/api/api_config.dart';
import 'data/repositories/collect_repository.dart';
import 'data/repositories/history_repository.dart';
import 'features/push/push_service.dart';
import 'routes/app_router.dart';
import 'services/remote_server.dart';

import 'package:media_kit/media_kit.dart';

class TvBoxApp extends StatelessWidget {
  const TvBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 全局 Provider 在此注册
      ],
      child: TvFocusScope(
        child: MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          routerConfig: appRouter,
        ),
      ),
    );
  }
}

/// 应用初始化
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await HawkStore.init();
    final debugOpen = HawkStore.get<bool>('debug_open', defaultValue: false) ?? false;
    LOG.debugOpen = debugOpen;
    HttpClient.init();
    MediaKit.ensureInitialized();
    await HistoryRepository.instance.init();
    await CollectRepository.instance.init();
    await ApiConfig.instance.loadDefaultConfig();
    // 远程控制服务 + 推送监听
    PushService.instance.start();
    await RemoteServer.instance.start();
    LOG.i('App', 'bootstrap 完成');
  } catch (e) {
    LOG.e('App', 'bootstrap 失败', e);
  }
}
