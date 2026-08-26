import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'pages/route_observer.dart';
import 'pages/search_widget.dart';

// void _ensureNumericLocaleC() {
//   if (Platform.isLinux || Platform.isAndroid || Platform.isMacOS) {
//     try {
//       final DynamicLibrary libc = Platform.isLinux
//           ? DynamicLibrary.open('libc.so.6')
//           : DynamicLibrary.process();
//       final setlocale = libc.lookupFunction<
//           Pointer<Char> Function(Int32 category, Pointer<Utf8> locale),
//           Pointer<Char> Function(int category, Pointer<Utf8> locale)>('setlocale');
//       final cLocale = 'C'.toNativeUtf8();
//       // LC_NUMERIC = 1 in POSIX standard header locale.h
//       setlocale(1, cLocale);
//       calloc.free(cLocale);
//     } catch (_) {}
//   }
// }

import 'pages/main_music_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  JustAudioMediaKit.ensureInitialized();
  await ytmusic.initialize(cookies: '');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Midnight Music Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFFA855F7),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0B1A),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFFA855F7),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0B1A),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: const MainMusicLayout(),
      navigatorObservers: [routeObserver],
    );
  }
}
