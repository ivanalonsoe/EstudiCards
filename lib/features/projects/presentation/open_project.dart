import 'dart:async';

import 'package:estudicards/app/router.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Opens the project screen and records the use, so the project moves up
/// the dashboard (R 7.7).
void openProject(BuildContext context, WidgetRef ref, String projectId) {
  // The screen does not wait for the database write.
  unawaited(ref.read(projectsRepositoryProvider).markUsed(projectId));
  context.go(AppRoutes.project(projectId));
}
