import 'dart:ui';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/app_logger.dart';
import 'state/app_state.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/login_screen.dart';
import 'ui/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.instance.recordCrash(
      details.exception,
      details.stack,
      'FLUTTER_ERROR',
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.instance.recordCrash(error, stack, 'UNCAUGHT_ERROR');
    return false;
  };
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const InhaApp(),
    ),
  );
}

class InhaApp extends StatelessWidget {
  const InhaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final useDynamic = app.settings.dynamicColor;
        final lightScheme = (useDynamic && lightDynamic != null)
            ? lightDynamic.harmonized()
            : AppTheme.lightColorScheme;
        final darkScheme = (useDynamic && darkDynamic != null)
            ? darkDynamic.harmonized()
            : AppTheme.darkColorScheme;

        return MaterialApp(
          navigatorKey: AppState.navigatorKey,
          title: 'Inha App',
          debugShowCheckedModeBanner: false,
          themeMode: app.themeMode,
          theme: AppTheme.buildTheme(lightScheme),
          darkTheme: AppTheme.buildTheme(darkScheme),
          home: app.isInitializing
              ? const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                )
              : (app.isLoggedIn ? const HomeShell() : const LoginScreen()),
        );
      },
    );
  }
}
