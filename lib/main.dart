import 'dart:io';

import 'package:estudicards/app/app.dart';
import 'package:estudicards/app/windows_startup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  // Needed before asking the system for folders, which happens before the
  // app starts on Windows.
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  if (Platform.isWindows) {
    // The data lives in a folder the user chooses (T5.11).
    runApp(await windowsStartup());
    return;
  }
  // ProviderScope stores the state of every Riverpod provider; it must wrap
  // the whole app.
  runApp(const ProviderScope(child: EstudiCardsApp()));
}
