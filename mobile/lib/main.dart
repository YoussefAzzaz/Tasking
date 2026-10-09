import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/router.dart';
import 'package:axis/data/powersync_db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // System UI — transparent bars to let the canvas bleed edge-to-edge
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Initialize local SQLite + Supabase connector
  await openDatabase();

  runApp(const AxisApp());
}

class AxisApp extends StatelessWidget {
  const AxisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Axis',
      debugShowCheckedModeBanner: false,
      theme: AxisTheme.dark,
      darkTheme: AxisTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
