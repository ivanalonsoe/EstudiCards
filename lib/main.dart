import 'package:estudicards/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  registerFontLicenses();
  // ProviderScope stores the state of every Riverpod provider; it must wrap
  // the whole app.
  runApp(const ProviderScope(child: EstudiCardsApp()));
}
