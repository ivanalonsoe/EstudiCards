// Card selection and shuffling receive a `Random` instead of creating one, so
// tests can pass a seeded one: the same seed always gives the same "random"
// order, which makes the results reproducible (SPEC §10.3).
import 'dart:math';

/// Creates the `Random` used for selection and shuffling. The app calls it
/// without a seed; tests pass one (e.g. `createRandom(seed: 42)`).
Random createRandom({int? seed}) => Random(seed);
