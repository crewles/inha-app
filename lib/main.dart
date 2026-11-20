import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/login_screen.dart';

const Color _inhaBlueSeed = Color(0xFF005BAC);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
            : ColorScheme.fromSeed(
                seedColor: _inhaBlueSeed,
                brightness: Brightness.light,
              );
        final darkScheme = (useDynamic && darkDynamic != null)
            ? darkDynamic.harmonized()
            : ColorScheme.fromSeed(
                seedColor: _inhaBlueSeed,
                brightness: Brightness.dark,
              );

        return MaterialApp(
          title: 'Inha App',
          debugShowCheckedModeBanner: false,
          themeMode: app.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightScheme,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkScheme,
          ),
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
