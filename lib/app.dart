import 'package:fitbuddy/core/router/app_router.dart';
import 'package:fitbuddy/core/services/deep_link_service.dart';
import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/core/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root widget: wires the theme, the theme mode, the router, and deep links.
class VyayamaApp extends ConsumerStatefulWidget {
  const VyayamaApp({super.key});

  @override
  ConsumerState<VyayamaApp> createState() => _VyayamaAppState();
}

class _VyayamaAppState extends ConsumerState<VyayamaApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final router = ref.read(goRouterProvider);
      DeepLinkService.instance.init(router);
    });
  }

  @override
  void dispose() {
    DeepLinkService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Vyayama',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
