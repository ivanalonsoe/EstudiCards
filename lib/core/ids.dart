// Every row in the database is identified by a UUID v4: a random 128-bit
// value written as text (e.g. `3f2b8c1e-9d4a-4b7e-a1c2-5e6f7a8b9c0d`). Unlike
// auto-increment numbers (1, 2, 3…), two devices never generate the same one,
// so exported data can be imported elsewhere without ID clashes.
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Returns a new, unique UUID v4.
String newId() => _uuid.v4();
