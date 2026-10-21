// The performance test (T6.5) on its own, to measure it in profile mode:
// the app compiled as it is installed, without the checks of debug mode.
//
//   flutter run --profile -d windows -t integration_test/performance_profile.dart
//
// The times are printed in the console, after "[performance]". The name
// does not end in `_test.dart`, so `flutter test integration_test` does not
// run it a second time (it already runs from `app_test.dart`, in debug).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'flows/performance_flow.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('performance', performanceFlowTests);
}
