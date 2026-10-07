import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:estudicards/app/app.dart';
import 'package:estudicards/app/router.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const mobile = Size(390, 844);
const tablet = Size(700, 1000);
const desktop = Size(1440, 900);

/// A fresh in-memory database, closed when the test ends.
///
/// `closeStreamsSynchronously` makes Drift stop a watched query as soon as
/// nobody listens to it. By default it waits a moment with a timer, and
/// widget tests fail if a timer is still pending when the test ends.
AppDatabase createTestDatabase() {
  final db = AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  addTearDown(db.close);
  return db;
}

/// Starts the whole app on a screen of [size], at [location], with an
/// in-memory database and a fake clock instead of the real ones.
Future<GoRouter> pumpTestApp(
  WidgetTester tester, {
  required Size size,
  AppDatabase? db,
  Clock? clock,
  String location = AppRoutes.home,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = createRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db ?? createTestDatabase()),
        clockProvider.overrideWithValue(
          clock ?? FakeClock(DateTime.utc(2026, 10, 6, 12)),
        ),
      ],
      child: EstudiCardsApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  // Remove the app before the database closes, so no query is left running.
  addTearDown(() => tester.pumpWidget(const SizedBox()));
  return router;
}
