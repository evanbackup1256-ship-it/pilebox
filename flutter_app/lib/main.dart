import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app_config.dart';
import 'presentation/home_screen.dart';
import 'presentation/splash_screen.dart';
import 'services/appearance_service.dart';
import 'services/update_service.dart';
import 'services/vault_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Load the saved skin before anything paints, so the first frame is already
  // in the user's theme rather than flashing the default one.
  await bootstrapSkin();

  final options = WindowOptions(
    size: const Size(1120, 700),
    minimumSize: const Size(960, 620),
    center: true,
    backgroundColor: Palette.void_,
    titleBarStyle: TitleBarStyle.hidden,
    title: AppConfig.displayName,
  );

  // runApp must come first: waitUntilReadyToShow reveals the window, and a
  // window shown before there is a widget tree renders at the native runner's
  // own default size instead of the size requested here.
  runApp(const PileboxApp());

  await windowManager.waitUntilReadyToShow(options, () async {
    // WindowOptions.titleBarStyle is not reliably applied on Windows, so the
    // style is set explicitly here. Without this the native titlebar stays
    // and the custom chrome renders underneath it.
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await windowManager.setSize(const Size(1120, 700));
    await windowManager.setMinimumSize(const Size(960, 620));
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
  });
}

class PileboxApp extends StatefulWidget {
  const PileboxApp({super.key});

  @override
  State<PileboxApp> createState() => _PileboxAppState();
}

class _PileboxAppState extends State<PileboxApp> {
  final _vault = VaultService();
  final _updater = UpdateService();

  bool _ready = false;
  AppPreferences _preferences = const AppPreferences();

  Future<void> _quit() async {
    await windowManager.destroy();
  }

  void _onSplashReady(AppPreferences preferences) {
    setState(() {
      _preferences = preferences;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _vault.dispose();
    _updater.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Palette colours are static getters, which Flutter cannot observe, so a
    // revision counter drives the rebuild.
    //
    // Deliberately NO key here: keying MaterialApp on the revision destroys
    // and recreates the entire tree on every appearance change, which remounts
    // HomeScreen, resets the selected page, and re-runs load(). Rebuilding
    // without a key repaints the colours while keeping all widget state.
    return ValueListenableBuilder<int>(
      valueListenable: Palette.revision,
      builder: (context, revision, _) {
        return MaterialApp(
          title: AppConfig.displayName,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: AnimatedSwitcher(
            duration: Motion.slow,
            switchInCurve: Motion.glide,
            switchOutCurve: Motion.swift,
            // The splash fades out while the home screen scales gently up
            // from just-behind-full-size and fades in - reads as the app
            // "arriving" rather than a plain crossfade, for the one
            // transition every single launch actually shows the user.
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween(begin: 1.015, end: 1.0).animate(anim),
                child: child,
              ),
            ),
            child: _ready
                ? HomeScreen(
                    key: const ValueKey('home'),
                    vault: _vault,
                    updater: _updater,
                    preferences: _preferences,
                    onQuit: _quit,
                  )
                : SplashScreen(
                    key: const ValueKey('splash'),
                    vault: _vault,
                    updater: _updater,
                    onReady: _onSplashReady,
                  ),
          ),
        );
      },
    );
  }
}
