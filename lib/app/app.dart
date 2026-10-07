import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import 'router.dart';

class WatchGuyApp extends ConsumerWidget {
  const WatchGuyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'WatchGuy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
