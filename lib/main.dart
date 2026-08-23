import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'gtk_scaffold.dart';
import 'gtk_native_header_bar.dart';
import 'macos_native_button.dart';
import 'macos_native_switch.dart';
import 'macos_input_field.dart';
import 'route_observer.dart';
import 'home_sections_page.dart';
import 'search_widget.dart';
import 'audio_controller.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );
  JustAudioMediaKit.ensureInitialized();
  await ytmusic.initialize(
    cookies:
        "LOGIN_INFO=AFmmF2swRQIgUpMB6cxB70QIoSIeFRF6leR_scBRaT37ptRhLYzT9WgCIQDZwaYDbRwuViztQrjC3fqWXokEk2XPMpK4JE-o6KurOw:QUQ3MjNmd29KelBKU25wbTVCU0pIWHJpUE80ZkdqTDM4Ny1Jcmp4UGFDd2NHTUx5Z1RSSXlWaGwtNnVkZ2VOdWpOa1djWVpyczM5MlBoeGJTNy1QOTJHMDBPVzNfazRPOVllRHAwZGI3bUFJV2xaaW10d1BtLTFaRVZYdW1kUzNfeUdpOUhCal9JOGtKQ2RIeXJaYzB5WEtzUmp6Mk5jQlZ3",
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GTK Native Scaffold Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: Colors.deepPurple,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MyHomePage(title: 'GTK Native Scaffold'),
      navigatorObservers: [routeObserver],
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _currentTabIndex = 0;
  int _counter = 0;
  bool _isSwitchOn = true;
  String _lastSubmitted = '';

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  void _onSwitchChanged(bool value) {
    setState(() {
      _isSwitchOn = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String currentTitle = _currentTabIndex == 0
        ? 'Home Page'
        : _currentTabIndex == 1
        ? 'Native Controls'
        : 'Settings';

    final String currentSubtitle = _currentTabIndex == 0
        ? 'GTK HeaderBar Demo'
        : _currentTabIndex == 1
        ? 'GTK Button, Switch & Entry'
        : 'Configuration Options';

    return Scaffold(
      extendBodyBehindAppBar: true,

      bottomNavigationBar: GtkBottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        items: const [
          GtkBottomNavigationItem(
            id: "0",
            label: 'Home',
            iconName: 'go-home-symbolic',
          ),
          GtkBottomNavigationItem(
            id: "1",
            label: 'Controls',
            iconName: 'edit-symbolic',
          ),
          GtkBottomNavigationItem(
            id: "2",
            label: 'Music',
            iconName: 'edit-symbolic',
          ),
        ],
      ),
      backgroundColor: const Color.fromARGB(175, 45, 27, 78),
      body: switch (_currentTabIndex) {
        0 => Center(
          child: Scaffold(
            // extendBodyBehindAppBar: true,
            extendBody: true,
            appBar: GtkNativeHeaderBar(
              title: currentTitle,
              subtitle: currentSubtitle,
              backgroundColor: const Color.fromARGB(46, 45, 27, 78),
              leading: _currentTabIndex > 0
                  ? GtkHeaderAction(
                      id: 'back',
                      iconName: 'go-previous-symbolic',
                      label: 'Back',
                      position: 'start',
                      onPressed: () {
                        setState(() {
                          _currentTabIndex = 0;
                        });
                      },
                    )
                  : null,
              actions: [
                GtkHeaderAction(
                  id: 'refresh',
                  iconName: 'view-refresh-symbolic',
                  label: 'Refresh',
                  position: 'end',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Native GTK Refresh Action Clicked!'),
                      ),
                    );
                  },
                ),
                GtkHeaderAction(
                  id: 'info',
                  iconName: 'dialog-information-symbolic',
                  label: 'Info',
                  position: 'end',
                  onPressed: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'GTK Native Scaffold',
                      applicationVersion: '1.0.0',
                    );
                  },
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.desktop_windows,
                    size: 64,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome to GTK Native Scaffold',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The top bar (GtkHeaderBar) is a native GTK widget!',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Counter value: $_counter',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _incrementCounter,
                    icon: const Icon(Icons.add),
                    label: const Text('Increment Counter'),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Tab 1: Native Controls,
        1 => Scaffold(
          // extendBodyBehindAppBar: true,
          extendBody: true,
          appBar: GtkNativeHeaderBar(
            title: currentTitle,
            subtitle: currentSubtitle,
            backgroundColor: const Color.fromARGB(46, 45, 27, 78),
            leading: _currentTabIndex > 0
                ? GtkHeaderAction(
                    id: 'back',
                    iconName: 'go-previous-symbolic',
                    label: 'Back',
                    position: 'start',
                    onPressed: () {
                      setState(() {
                        _currentTabIndex = 0;
                      });
                    },
                  )
                : null,
            actions: [
              GtkHeaderAction(
                id: 'refresh',
                iconName: 'view-refresh-symbolic',
                label: 'Refresh',
                position: 'end',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Native GTK Refresh Action Clicked!'),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Native GTK Button:'),
                const SizedBox(height: 8),
                MacosNativeButton(
                  title: "Native GTK Button",
                  onPressed: () {
                    _incrementCounter();
                  },
                ),
                const SizedBox(height: 24),
                const Text('Native GTK Switch:'),
                const SizedBox(height: 8),
                MacosNativeSwitch(
                  value: _isSwitchOn,
                  onChanged: _onSwitchChanged,
                ),
                const SizedBox(height: 8),
                Text('Switch is ${_isSwitchOn ? 'ON' : 'OFF'}'),
                const SizedBox(height: 24),
                const Text('Native GTK Input Field (Entry):'),
                const SizedBox(height: 8),
                MacosInputField(
                  width: 300,
                  height: 74,
                  placeholder: 'Type text and press Enter',
                  onInput: (value) {
                    debugPrint('Live input: $value');
                  },
                  onSubmit: (value) {
                    setState(() {
                      _lastSubmitted = value;
                    });
                  },
                ),

                MacosInputField(
                  width: 300,
                  height: 34,
                  placeholder: 'Type text and press Enter',
                  onInput: (value) {
                    debugPrint('Live input: $value');
                  },
                  onSubmit: (value) {
                    setState(() {
                      applyCustomCss(value);
                    });
                  },
                ),
                if (_lastSubmitted.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Submitted text: $_lastSubmitted'),
                ],
              ],
            ),
          ),
        ),
        // Tab 2: Settings,
        2 => Scaffold(
          body: Center(
            // Center is a layout widget. It takes a single child and positions it
            // in the middle of the parent.
            child: Column(
              // Column is also a layout widget. It takes a list of children and
              // arranges them vertically. By default, it sizes itself to fit its
              // children horizontally, and tries to be as tall as its parent.
              //
              // Column has various properties to control how it sizes itself and
              // how it positions its children. Here we use mainAxisAlignment to
              // center the children vertically; the main axis here is the vertical
              // axis because Columns are vertical (the cross axis would be
              // horizontal).
              //
              // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
              // action in the IDE, or press "p" in the console), to see the
              // wireframe for each widget.
              mainAxisAlignment: .start,
              children: [
                const Text('You have pushed the button this many times:'),
                Text(
                  '$_counter',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const HomeSectionsPage(),
                      ),
                    );
                  },
                  child: const Text('Ver secciones de la página principal'),
                ),
                const SizedBox(height: 16),
                const Expanded(child: SongSearchWidget()),
              ],
            ),
          ),

          floatingActionButton: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                onPressed: _incrementCounter,
                tooltip: 'Increment',
                child: const Icon(Icons.add),
              ),
              const SizedBox(width: 12),
              ListenableBuilder(
                listenable: audioController,
                builder: (context, _) {
                  return FloatingActionButton(
                    onPressed: () {
                      audioController.togglePlayPause();
                    },
                    tooltip: 'Play/Pause',
                    child: Icon(
                      audioController.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Tab 3: Settings,
        3 => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.desktop_windows,
                  size: 64,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome to GTK Native Scaffold',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'The top bar (GtkHeaderBar) is a native GTK widget!',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  'Counter value: $_counter',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _incrementCounter,
                  icon: const Icon(Icons.add),
                  label: const Text('Increment Counter'),
                ),
              ],
            ),
          ),
        ),
        // Tab 4: Settings,
        _ => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.desktop_windows,
                  size: 64,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome to GTK Native Scaffold',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'The top bar (GtkHeaderBar) is a native GTK widget!',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  'Counter value: $_counter',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _incrementCounter,
                  icon: const Icon(Icons.add),
                  label: const Text('Increment Counter'),
                ),
              ],
            ),
          ),
        ),
      },
    );
  }
}
