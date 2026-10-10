import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';

/// Builds a database exactly as an old schema version created it, for
/// Drift's `SchemaVerifier`.
///
/// Every time the schema changes, the new version is saved as a JSON file in
/// `drift_schemas/` with:
///
///   dart run drift_dev schema dump lib/core/db/app_database.dart drift_schemas/drift_schema_vN.json
///
/// (N = the new `schemaVersion`). Each file keeps the exact CREATE statements
/// of its version under `fixed_sql`, and this helper runs them.
///
/// Drift can also generate this helper as Dart code (`make-migrations`), but
/// that code names a getter after the `text` column of `card_options`, which
/// clashes with Drift's own `Table.text()` and does not compile.
class SchemaFiles extends SchemaInstantiationHelper {
  @override
  GeneratedDatabase databaseForVersion(QueryExecutor db, int version) {
    final file = File('drift_schemas/drift_schema_v$version.json');
    if (!file.existsSync()) {
      throw MissingSchemaException(version, _knownVersions());
    }
    final schema = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    final statements = [
      for (final element in schema['fixed_sql']! as List<Object?>)
        for (final dialect in (element! as Map)['sql'] as List<Object?>)
          if (dialect case {'dialect': 'sqlite', 'sql': final String sql}) sql,
    ];
    return _DatabaseFromSql(db, version, statements);
  }

  static Set<int> _knownVersions() => {
    for (final file in Directory('drift_schemas').listSync())
      if (RegExp(r'drift_schema_v(\d+)\.json$').firstMatch(file.path)
          case final match?)
        int.parse(match.group(1)!),
  };
}

/// A database with no Dart tables whose creation runs [_statements].
class _DatabaseFromSql extends GeneratedDatabase {
  new(super.executor, this.schemaVersion, this._statements);

  @override
  final int schemaVersion;
  final List<String> _statements;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  Iterable<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      for (final statement in _statements) {
        await customStatement(statement);
      }
    },
  );
}
