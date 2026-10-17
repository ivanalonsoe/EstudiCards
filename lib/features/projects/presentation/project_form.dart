import 'dart:async';

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/app/theme/project_palette.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:estudicards/features/projects/presentation/form_parts.dart';
import 'package:estudicards/features/projects/presentation/open_project.dart';
import 'package:estudicards/features/projects/presentation/project_icon.dart';
import 'package:estudicards/features/projects/presentation/project_labels.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:estudicards/features/stats/presentation/reset_statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens P02 to create a project, or to edit [project] when given: a bottom
/// sheet on mobile and a dialog on tablet and desktop
/// (DESIGN_BRIEF.md §6.2). A new project is opened after saving (US-01 AC2).
Future<void> showProjectForm(
  BuildContext context,
  WidgetRef ref, {
  Project? project,
}) async {
  final saved = await showFormSheet<Project>(
    context,
    ProjectForm(project: project),
  );
  if (saved != null && project == null && context.mounted) {
    openProject(context, ref, saved.id);
  }
}

/// The fields of P02: name, description, colour and icon. The type and the
/// languages are chosen for each deck (P04). Closes itself with the saved
/// project.
class ProjectForm extends ConsumerStatefulWidget {
  const new({this.project, super.key});

  /// The project being edited; null when creating one.
  final Project? project;

  @override
  ConsumerState<ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends ConsumerState<ProjectForm> {
  // The form starts with the project's values when editing, or with the
  // defaults for a new project: orange and the book icon.
  late final _name = TextEditingController(text: widget.project?.name);
  late final _description = TextEditingController(
    text: widget.project?.description,
  );
  late String _color = widget.project?.color ?? ProjectColor.orange.key;
  late String _icon = widget.project?.icon ?? ProjectIcon.book.key;
  bool _saving = false;

  bool get _isEditing => widget.project != null;

  ProjectInput get _input => ProjectInput(
    name: _name.text,
    description: _description.text,
    color: _color,
    icon: _icon,
  );

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repository = ref.read(projectsRepositoryProvider);
    final project = widget.project;
    final saved = project == null
        ? await repository.create(_input)
        : await repository.update(project.id, _input);
    if (mounted) Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSave = !_saving && _input.validate().isEmpty;

    return FormFrame(
      keyPrefix: 'projectForm',
      title: _isEditing ? l10n.editProject : l10n.newProject,
      saveLabel: _isEditing ? l10n.save : l10n.createProject,
      onSave: canSave ? _save : null,
      fields: [
        FormLabel(l10n.nameLabel),
        TextField(
          key: const Key('projectForm.name'),
          controller: _name,
          autofocus: !_isEditing,
          textCapitalization: TextCapitalization.sentences,
          // Typing stops at the maximum length instead of showing
          // an error (US-01 AC1).
          inputFormatters: [
            LengthLimitingTextInputFormatter(ProjectInput.maxNameLength),
          ],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.xl),
        FormLabel(l10n.descriptionOptionalLabel),
        TextField(
          key: const Key('projectForm.description'),
          controller: _description,
          textCapitalization: TextCapitalization.sentences,
          maxLines: null,
          inputFormatters: [
            LengthLimitingTextInputFormatter(ProjectInput.maxDescriptionLength),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        FormLabel(l10n.colorLabel),
        ColorPicker(
          keyPrefix: 'projectForm',
          selected: _color,
          // A project always has its own colour, so it is never
          // null here.
          onChanged: (color) => setState(() => _color = color!),
        ),
        const SizedBox(height: AppSpacing.xl),
        FormLabel(l10n.iconLabel),
        _IconPicker(
          selected: _icon,
          color: _color,
          onChanged: (icon) => setState(() => _icon = icon),
        ),
        // Only when editing (P02). The form stays open with its changes.
        if (widget.project case final project?) ...[
          const SizedBox(height: AppSpacing.xl),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('projectForm.resetStats'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.of(context).error,
              ),
              onPressed: () => unawaited(
                confirmResetStatistics(
                  context,
                  ref,
                  body: l10n.resetProjectStatisticsBody(project.name),
                  reset: (stats) => stats.resetProject(project.id),
                ),
              ),
              icon: const Icon(Icons.restart_alt_rounded),
              label: Text(l10n.resetStatistics),
            ),
          ),
        ],
      ],
    );
  }
}

/// The project icons; the chosen one is tinted with the chosen colour.
class _IconPicker extends StatelessWidget {
  const new({
    required this.selected,
    required this.color,
    required this.onChanged,
  });

  final String selected;
  final String color;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final accent = ProjectColor.fromKey(color)
        .resolve(Theme.of(context).brightness);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final icon in ProjectIcon.values)
          Semantics(
            label: iconName(l10n, icon),
            selected: icon.key == selected,
            button: true,
            child: InkWell(
              key: Key('projectForm.icon.${icon.key}'),
              onTap: () => onChanged(icon.key),
              borderRadius: BorderRadius.circular(AppRadii.control),
              child: Container(
                width: minTouchTarget,
                height: minTouchTarget,
                decoration: BoxDecoration(
                  color: icon.key == selected
                      ? accent.withValues(alpha: 0.12)
                      : null,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                  border: Border.all(
                    color: icon.key == selected ? accent : colors.border,
                    width: icon.key == selected ? 2 : 1,
                  ),
                ),
                child: Icon(
                  icon.icon,
                  color: icon.key == selected ? accent : colors.text,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
