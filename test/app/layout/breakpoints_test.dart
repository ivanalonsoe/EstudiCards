import 'package:estudicards/app/layout/breakpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('widths below 600 are mobile', () {
    expect(FormFactor.fromWidth(390), FormFactor.mobile);
    expect(FormFactor.fromWidth(599), FormFactor.mobile);
  });

  test('widths from 600 to 839 are tablet', () {
    expect(FormFactor.fromWidth(600), FormFactor.tablet);
    expect(FormFactor.fromWidth(839), FormFactor.tablet);
  });

  test('widths from 840 are desktop', () {
    expect(FormFactor.fromWidth(840), FormFactor.desktop);
    expect(FormFactor.fromWidth(1440), FormFactor.desktop);
  });
}
