import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/app/router.dart';
import 'package:flutter_full_stack_flutter/theme/app_theme.dart';
import 'package:flutter_full_stack_flutter/theme/theme_mode_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Flutter Full Stack',
      // Four slots, not two. The device can ask for a brightness *and* for
      // increased contrast, and Flutter picks the matching pair on its own.
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      highContrastTheme: AppTheme.highContrastLight(),
      highContrastDarkTheme: AppTheme.highContrastDark(),
      // Defaults to ThemeMode.system, so leaving this alone already follows
      // the device. The provider is here to let a user override it.
      themeMode: ref.watch(themeModeControllerProvider),
      routerConfig: router,
    );
  }
}
