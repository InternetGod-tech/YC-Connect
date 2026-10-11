import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/controller.dart';
import 'core/theme.dart';
import 'data/app_db.dart';
import 'domain/engine.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final prefs = await SharedPreferences.getInstance();
    final support = await getApplicationSupportDirectory();
    await support.create(recursive: true);
    final docs = await getApplicationDocumentsDirectory();
    final seed = await rootBundle.loadString('assets/data/directory.json');
    final store = AppDb.open(p.join(support.path, 'youthcare.db'));
    final engine = Engine(store, seed);
    if (store.isEmpty) engine.seed();
    runApp(YouthCareApp(AppController(engine, prefs, p.join(docs.path, 'YouthCareConnect-backups'))));
  } catch (e) {
    runApp(StartupError(message: e.toString()));
  }
}

class YouthCareApp extends StatelessWidget {
  const YouthCareApp(this.controller, {super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) => AppScope(controller: controller, child: const _Themed());
}

class _Themed extends StatelessWidget {
  const _Themed();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final sysReduce = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    final reduce = app.reduceMotion || sysReduce;
    return MaterialApp(
      title: 'YouthCare Connect',
      debugShowCheckedModeBanner: false,
      themeMode: app.themeMode,
      theme: buildTheme(Brightness.light, reduceMotion: reduce),
      darkTheme: buildTheme(Brightness.dark, reduceMotion: reduce),
      builder: (ctx, child) {
        final mq = MediaQuery.of(ctx);
        return MediaQuery(data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * app.textScale)), child: child!);
      },
      home: const Shell(),
    );
  }
}

class StartupError extends StatelessWidget {
  const StartupError({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'YouthCare Connect',
        theme: buildTheme(Brightness.light, reduceMotion: false),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                const Text('YouthCare Connect could not start', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('The local data file could not be opened. Close the app and open it again. If this keeps happening, restore a backup or reinstall.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                SelectableText(message, style: const TextStyle(fontSize: 12)),
              ]),
            ),
          ),
        ),
      );
}
