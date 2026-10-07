import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/app/theme/project_palette.dart';
import 'package:estudicards/features/projects/domain/languages.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:estudicards/features/projects/presentation/form_parts.dart';
import 'package:estudicards/features/projects/presentation/open_project.dart';
import 'package:estudicards/features/projects/presentation/project_icon.dart';
import 'package:estudicards/features/projects/presentation/project_labels.dart';
import 'package:estudicards/features/projects/presentation/project_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens P02 to create a project, or to edit [project] when given: a bottom
/// sheet on mobile and a dialog on tablet and desktop
/// (DESIGN_BRIEF.md §6.2). A new project is opened after saving (US-01 AC3).
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

/// The fields of P02. Closes itself with the saved project.
class ProjectForm extends ConsumerStatefulWidget {
  const new({this.project, super.key});

  /// The project being edited; null when creating one.
  final Project? project;

  @override
  ConsumerState<ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends ConsumerState<ProjectForm> {
  // The form starts with the project's values when editing, or with the
  // defaults for a new project: orange, book icon, general.
  late final _name = TextEditingController(text: widget.project?.name);
  late final _description = TextEditingController(
    text: widget.project?.description,
  );
  late String _color = widget.project?.color ?? ProjectColor.orange.key;
  late String _icon = widget.project?.icon ?? ProjectIcon.book.key;
  late ProjectType _type = widget.project?.type ?? ProjectType.general;
  late String? _sourceLang = widget.project?.sourceLang;
  late String? _targetLang = widget.project?.targetLang;
  bool _saving = false;

  bool get _isEditing => widget.project != null;

  ProjectInput get _input => ProjectInput(
    name: _name.text,
    description: _description.text,
    color: _color,
    icon: _icon,
    type: _type,
    sourceLang: _sourceLang,
    targetLang: _targetLang,
  );

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  /// Changing a stored language project to general asks first (US-02 AC2).
  /// While creating, or for a project that was general, it just changes.
  Future<void> _changeType(ProjectType type) async {
    final asks =
        type == ProjectType.general &&
        widget.project?.type == ProjectType.language;
    if (asks && !await _confirmSwitchToGeneral()) return;
    setState(() => _type = type);
  }

  Future<bool> _confirmSwitchToGeneral() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.switchToGeneralTitle),
        content: Text(l10n.switchToGeneralBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('projectForm.confirmTypeChange'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.switchToGeneralConfirm),
          ),
        ],
      ),
    );
    return confirmed ?? false;
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
    final text = Theme.of(context).textTheme;
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
        const SizedBox(height: AppSpacing.xl),
        FormLabel(l10n.typeLabel),
        SegmentedButton<ProjectType>(
          segments: [
            ButtonSegment(
              value: ProjectType.general,
              label: Text(
                l10n.typeGeneral,
                key: const Key('projectForm.type.general'),
              ),
            ),
            ButtonSegment(
              value: ProjectType.language,
              label: Text(
                l10n.typeLanguage,
                key: const Key('projectForm.type.language'),
              ),
            ),
          ],
          selected: {_type},
          showSelectedIcon: false,
          // A grey track with the chosen option in white, as in
          // the design.
          style: SegmentedButton.styleFrom(
            backgroundColor: AppColors.of(context).surfaceVariant,
            foregroundColor: AppColors.of(context).textMuted,
            selectedBackgroundColor: AppColors.of(context).surface,
            selectedForegroundColor: AppColors.of(context).text,
            side: BorderSide(color: AppColors.of(context).border),
            textStyle: text.labelLarge,
          ),
          onSelectionChanged: (selection) => _changeType(selection.single),
        ),
        if (_type == ProjectType.language) ...[
          const SizedBox(height: AppSpacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _LanguageField(
                  key: const Key('projectForm.sourceLang'),
                  label: l10n.sourceLanguageLabel,
                  value: _sourceLang,
                  onChanged: (code) => setState(() => _sourceLang = code),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _LanguageField(
                  key: const Key('projectForm.targetLang'),
                  label: l10n.targetLanguageLabel,
                  value: _targetLang,
                  onChanged: (code) => setState(() => _targetLang = code),
                ),
              ),
            ],
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

/// A language selector with its label above.
class _LanguageField extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bodyStyle = Theme.of(context).textTheme.bodyLarge;
    // A stored code outside the list (e.g. from an import) is still offered,
    // so the selector can show it.
    final codes = [
      ...supportedLanguages,
      if (value != null && !supportedLanguages.contains(value)) value!,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormLabel(label),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          style: bodyStyle,
          hint: Text(
            l10n.chooseLanguage,
            overflow: TextOverflow.ellipsis,
            style: bodyStyle?.copyWith(color: AppColors.of(context).textMuted),
          ),
          items: [
            for (final code in codes)
              DropdownMenuItem(
                value: code,
                child: Text(
                  languageName(l10n, code),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
