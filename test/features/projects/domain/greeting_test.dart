import 'package:estudicards/features/projects/domain/greeting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime at(int hour, [int minute = 0]) =>
      DateTime(2026, 10, 6, hour, minute);

  test('says good morning from 6:00 to 13:59', () {
    expect(Greeting.at(at(6)), Greeting.morning);
    expect(Greeting.at(at(13, 59)), Greeting.morning);
  });

  test('says good afternoon from 14:00 to 20:59', () {
    expect(Greeting.at(at(14)), Greeting.afternoon);
    expect(Greeting.at(at(20, 59)), Greeting.afternoon);
  });

  test('says good evening from 21:00 to 5:59', () {
    expect(Greeting.at(at(21)), Greeting.evening);
    expect(Greeting.at(at(0)), Greeting.evening);
    expect(Greeting.at(at(5, 59)), Greeting.evening);
  });
}
