import 'dart:math';

import 'package:estudicards/core/random.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> sequence(Random random) => [
  for (var i = 0; i < 20; i++) random.nextInt(1000),
];

void main() {
  test('two Random instances with the same seed give the same sequence', () {
    expect(sequence(createRandom(seed: 42)), sequence(createRandom(seed: 42)));
  });

  test('different seeds give different sequences', () {
    expect(
      sequence(createRandom(seed: 1)),
      isNot(sequence(createRandom(seed: 2))),
    );
  });

  test('without a seed it still creates a usable Random', () {
    final value = createRandom().nextInt(10);

    expect(value, inInclusiveRange(0, 9));
  });
}
