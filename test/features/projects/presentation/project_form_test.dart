import 'package:estudicards/app/router.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/features/projects/data/projects_dao.dart';
import 'package:estudicards/features/projects/data/projects_repository.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/test_app.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late ProjectsRepository projects;

  setUp(() {
    db = createTestDatabase();
    clock = FakeClock(DateTime.utc(2026, 10, 6, 12));
    projects = ProjectsRepository(ProjectsDao(db), clock);
  });

  final form = find.byKey(const Key('projectForm'));
  final nameField = find.byKey(const Key('projectForm.name'));
  final saveButton = find.byKey(const Key('projectForm.save'));
  final sourceLang = find.byKey(const Key('projectForm.sourceLang'));
  final targetLang = find.byKey(const Key('projectForm.targetLang'));
  final general = find.byKey(const Key('projectForm.type.general'));
  final language = find.byKey(const Key('projectForm.type.language'));

  bool saveEnabled(WidgetTester tester) =>
      tester.widget<ButtonStyleButton>(saveButton).onPressed != null;

  Future<GoRouter> openNewProjectForm(
    WidgetTester tester, {
    Size size = mobile,
  }) async {
    final router = await pumpTestApp(tester, size: size, db: db, clock: clock);
    await tester.tap(find.byKey(const Key('dashboard.newProject')));
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Opens a dropdown and picks the language called [name].
  Future<void> chooseLanguage(
    WidgetTester tester,
    Finder field,
    String name,
  ) async {
    await tapVisible(tester, field);
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  /// The stored projects, read with a plain query: a watched query
  /// (`watchProjects`) would wait for the test's fake clock to move.
  Future<List<Project>> storedProjects() async => [
    for (final row in await db.select(db.projects).get())
      (await projects.getById(row.id))!,
  ];

  Future<Project> createLanguageProject() => projects.create(
    const ProjectInput(
      name: 'Inglés B2',
      color: 'blue',
      icon: 'globe',
      type: ProjectType.language,
      sourceLang: 'en-GB',
      targetLang: 'es-ES',
    ),
  );

  Future<void> openEditForm(WidgetTester tester, Project project) async {
    await pumpTestApp(tester, size: mobile, db: db, clock: clock);
    await tester.tap(find.byKey(Key('projectCard.${project.id}.menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
  }

  group('create', () {
    testWidgets('the Save button is disabled without a name', (tester) async {
      await openNewProjectForm(tester);

      expect(find.text('Nuevo proyecto'), findsWidgets);
      expect(saveEnabled(tester), isFalse);

      await tester.enterText(nameField, '   ');
      await tester.pump();
      expect(saveEnabled(tester), isFalse);

      await tester.enterText(nameField, 'Historia');
      await tester.pump();
      expect(saveEnabled(tester), isTrue);
    });

    testWidgets('choosing "Idioma" shows the language selectors', (
      tester,
    ) async {
      await openNewProjectForm(tester);
      expect(sourceLang, findsNothing);
      expect(targetLang, findsNothing);

      await tapVisible(tester, language);

      expect(sourceLang, findsOneWidget);
      expect(targetLang, findsOneWidget);
    });

    testWidgets('a language project needs both languages to be saved', (
      tester,
    ) async {
      await openNewProjectForm(tester);
      await tester.enterText(nameField, 'Inglés B2');
      await tapVisible(tester, language);
      await tester.pump();
      expect(saveEnabled(tester), isFalse);

      await chooseLanguage(tester, sourceLang, 'Inglés (R. U.)');
      expect(saveEnabled(tester), isFalse);
      await chooseLanguage(tester, targetLang, 'Español');
      expect(saveEnabled(tester), isTrue);

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      final stored = (await storedProjects()).single;
      expect(stored.type, ProjectType.language);
      expect(stored.sourceLang, 'en-GB');
      expect(stored.targetLang, 'es-ES');
    });

    testWidgets(
      'saving stores the project and opens it (US-01 AC3), on a bottom sheet '
      'on mobile',
      (tester) async {
        final router = await openNewProjectForm(tester);
        expect(find.byType(BottomSheet), findsOneWidget);

        await tester.enterText(nameField, 'Biología 2º Bach.');
        await tester.enterText(
          find.byKey(const Key('projectForm.description')),
          'Temas 1 a 5',
        );
        await tapVisible(
          tester,
          find.byKey(const Key('projectForm.color.green')),
        );
        await tapVisible(
          tester,
          find.byKey(const Key('projectForm.icon.flask')),
        );
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(form, findsNothing);
        final stored = (await storedProjects()).single;
        expect(stored.name, 'Biología 2º Bach.');
        expect(stored.description, 'Temas 1 a 5');
        expect(stored.color, 'green');
        expect(stored.icon, 'flask');
        expect(stored.type, ProjectType.general);
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          AppRoutes.project(stored.id),
        );
        expect(stored.lastUsedAt, clock.now());
      },
    );

    testWidgets('cancelling closes the form without saving', (tester) async {
      await openNewProjectForm(tester);
      await tester.enterText(nameField, 'Historia');

      await tester.tap(find.byKey(const Key('projectForm.cancel')));
      await tester.pumpAndSettle();

      expect(form, findsNothing);
      expect(await storedProjects(), isEmpty);
    });

    testWidgets('while creating, going back to "General" does not ask', (
      tester,
    ) async {
      await openNewProjectForm(tester);
      await tapVisible(tester, language);

      await tapVisible(tester, general);

      expect(find.byType(AlertDialog), findsNothing);
      expect(sourceLang, findsNothing);
    });

    testWidgets('on desktop the form is a dialog', (tester) async {
      await openNewProjectForm(tester, size: desktop);

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(form, findsOneWidget);
    });

    testWidgets('the sidebar "+" button opens the form', (tester) async {
      await projects.create(
        const ProjectInput(name: 'Historia', color: 'blue', icon: 'book'),
      );
      await pumpTestApp(tester, size: desktop, db: db, clock: clock);

      await tester.tap(find.byKey(const Key('sidebar.newProject')));
      await tester.pumpAndSettle();

      expect(form, findsOneWidget);
    });
  });

  group('edit', () {
    testWidgets('the menu opens the form filled in, and saving updates it', (
      tester,
    ) async {
      final project = await createLanguageProject();
      await openEditForm(tester, project);

      expect(find.text('Editar proyecto'), findsOneWidget);
      expect(find.text('Inglés B2'), findsWidgets);
      expect(sourceLang, findsOneWidget);

      await tester.enterText(nameField, 'Inglés C1');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(form, findsNothing);
      final stored = await projects.getById(project.id);
      expect(stored!.name, 'Inglés C1');
      expect(stored.sourceLang, 'en-GB');
    });

    testWidgets('switching from "Idioma" to "General" asks for confirmation', (
      tester,
    ) async {
      final project = await createLanguageProject();
      await openEditForm(tester, project);

      await tapVisible(tester, general);

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining('No se borrará ningún dato'),
        ),
        findsOneWidget,
      );

      // Cancelling keeps the language type.
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('Cancelar')),
      );
      await tester.pumpAndSettle();
      expect(sourceLang, findsOneWidget);

      // Confirming switches to General, and the languages are kept.
      await tapVisible(tester, general);
      await tester.tap(find.byKey(const Key('projectForm.confirmTypeChange')));
      await tester.pumpAndSettle();
      expect(sourceLang, findsNothing);

      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      final stored = await projects.getById(project.id);
      expect(stored!.type, ProjectType.general);
      expect(stored.sourceLang, 'en-GB');
      expect(stored.targetLang, 'es-ES');
    });
  });
}
