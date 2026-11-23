import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/app_database.dart';
import 'data/finance_store.dart';
import 'screens/shell_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  final store = FinanceStore(database: AppDatabase());
  await store.initialize();
  runApp(ReZyLifeApp(store: store));
}

class ReZyLifeApp extends StatelessWidget {
  const ReZyLifeApp({super.key, required this.store});

  final FinanceStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final theme = buildReZyTheme(store.themePreset);
        final isDark = theme.brightness == Brightness.dark;
        final overlayStyle = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: ReZyTokens.tatsumi.surface,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ).copyWith(
          systemNavigationBarColor:
              (theme.extension<ReZyTokens>() ?? ReZyTokens.tatsumi).surface,
        );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: MaterialApp(
            title: 'ReZyLife',
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: ShellScreen(store: store),
          ),
        );
      },
    );
  }
}
