import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'bootstrap.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final overrides = await AppBootstrap.start(AppConfig.fromEnvironment());
  runApp(ProviderScope(overrides: overrides, child: const WatchGuyApp()));
}
