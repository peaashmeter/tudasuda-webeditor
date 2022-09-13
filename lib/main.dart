// ignore: avoid_web_libraries_in_flutter
import 'dart:html';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:webeditor/menu/menu.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  document.body!
      .addEventListener('contextmenu', (event) => event.preventDefault());

  runApp(
    EasyLocalization(
        supportedLocales: const [Locale('ru'), Locale('en')],
        path: 'assets/translations',
        startLocale: const Locale('ru'),
        fallbackLocale: const Locale('ru'),
        child: const App()),
  );
}

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      title: 'Tuda-Suda Web Editor',
      theme: ThemeData(primarySwatch: Colors.blueGrey, fontFamily: 'Nunito'),
      home: const Menu(),
    );
  }
}
