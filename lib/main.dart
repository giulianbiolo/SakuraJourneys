import 'package:japan_travel/models/models.dart';
import 'package:japan_travel/screens/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';

@pragma(
    'vm:entry-point') // Mandatory if the App is obfuscated or using Flutter 3.1+
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await updateCards(ListModel());
    } catch (e) {
      return Future.error(e);
    }
    return Future.value(true);
  });
}

// ? statusBarIconBrightness is the Android key, statusBarBrightness the iOS one,
// ? and they read inverted: both of these mean "light glyphs on a dark bar".
const SystemUiOverlayStyle systemUiOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp],
  );

  SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky,
      overlays: [SystemUiOverlay.bottom]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  Workmanager().initialize(callbackDispatcher);
  Workmanager().registerPeriodicTask(
    "update-home-widget-geo-distance",
    "updateHomeWidgetGeoDistance",
    frequency: const Duration(minutes: 15),
  );
  runApp(ChangeNotifierProvider(
      create: (context) => ListModel(), child: const SakuraJourneys()));
}

class SakuraJourneys extends StatelessWidget {
  const SakuraJourneys({super.key});

  @override
  Widget build(BuildContext context) {
    // ? MaterialApp re-issues an overlay style from theme.brightness on every
    // ? build, and this theme is light, so the one-shot call in main() gets
    // ? overwritten with dark status bar glyphs. RenderView re-reads this
    // ? annotation after every build, which is what makes it stick.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Sakura Journeys',
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          scaffoldBackgroundColor: const Color.fromARGB(255, 17, 17, 25),
          fontFamily: 'Roboto',
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
