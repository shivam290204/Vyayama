import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/core/router/app_router.dart';
import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/core/theme/theme_provider.dart';

/// Root widget: wires the theme, the theme mode and the router.
class VyayamaApp extends ConsumerWidget {
  const VyayamaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
