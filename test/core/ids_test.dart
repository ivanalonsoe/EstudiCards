import 'package:estudicards/core/ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // xxxxxxxx-xxxx-4xxx-[89ab]xxx-xxxxxxxxxxxx: the "4" marks version 4 and the
  // [89ab] marks the standard (RFC 4122) variant.
  final uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('generates IDs in UUID v4 format', () {
    expect(newId(), matches(uuidV4));
  });

  test('two generated IDs are different', () {
    expect(newId(), isNot(newId()));
  });

  test('a thousand generated IDs are all different', () {
    final ids = {for (var i = 0; i < 1000; i++) newId()};

    expect(ids, hasLength(1000));
  });
}
