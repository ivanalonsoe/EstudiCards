import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/layout/breakpoints.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/app/theme/project_palette.dart';
import 'package:estudicards/features/projects/domain/languages.dart';
import 'package:estudicards/features/projects/domain/project.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
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
  final form = ProjectForm(project: project);
  final isMobile =
      FormFactor.fromWidth(MediaQuery.sizeOf(context).width) ==
      FormFactor.mobile;

  // Both return the saved project, or null if the user cancelled.
  final saved = isMobile
      ? await showModalBottomSheet<Project>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (context) => form,
        )
      : await showDialog<Project>(
          context: context,
          builder: (context) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: form,
            ),
          ),
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

    return Padding(
      key: const Key('projectForm'),
      // Keeps the buttons above the on-screen keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.md,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing ? l10n.editProject : l10n.newProject,
                    style: text.headlineSmall,
                  ),
                ),
                IconButton(
                  key: const Key('projectForm.close'),
                  tooltip: l10n.close,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Label(l10n.nameLabel),
                  TextField(
                    key: const Key('projectForm.name'),
                    controller: _name,
                    autofocus: !_isEditing,
                    textCapitalization: TextCapitalization.sentences,
                    // Typing stops at the maximum length instead of showing
                    // an error (US-01 AC1).
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        ProjectInput.maxNameLength,
                      ),
                    ],
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _Label(l10n.descriptionOptionalLabel),
                  TextField(
                    key: const Key('projectForm.description'),
                    controller: _description,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        ProjectInput.maxDescriptionLength,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _Label(l10n.colorLabel),
                  _ColorPicker(
                    selected: _color,
                    onChanged: (color) => setState(() => _color = color),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _Label(l10n.iconLabel),
                  _IconPicker(
                    selected: _icon,
                    color: _color,
                    onChanged: (icon) => setState(() => _icon = icon),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _Label(l10n.typeLabel),
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
                    onSelectionChanged: (selection) =>
                        _changeType(selection.single),
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
                            onChanged: (code) =>
                                setState(() => _sourceLang = code),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: _LanguageField(
                            key: const Key('projectForm.targetLang'),
                            label: l10n.targetLanguageLabel,
                            value: _targetLang,
                            onChanged: (code) =>
                                setState(() => _targetLang = code),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.of(context).border),
              ),
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('projectForm.cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('projectForm.save'),
                    onPressed: canSave ? _save : null,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      _isEditing ? l10n.save : l10n.createProject,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The bold label above each field, as in the design.
class _Label extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

/// The 12 colours of the project palette as circles; the chosen one has a
/// ✓ and a ring.
class _ColorPicker extends StatelessWidget {
  const new({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    // At most 6 circles per row: two rows, as in the design.
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: minTouchTarget * 6 + AppSpacing.sm * 5,
        ),
        child: _colorWrap(l10n, brightness),
      ),
    );
  }

  Widget _colorWrap(AppLocalizations l10n, Brightness brightness) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final color in ProjectColor.values)
          Semantics(
            label: colorName(l10n, color),
            selected: color.key == selected,
            button: true,
            child: InkResponse(
              key: Key('projectForm.color.${color.key}'),
              onTap: () => onChanged(color.key),
              child: Container(
                width: minTouchTarget,
                height: minTouchTarget,
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: color.key == selected
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.resolve(brightness),
                          width: 2,
                        ),
                      )
                    : null,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.resolve(brightness),
                    shape: BoxShape.circle,
                  ),
                  child: color.key == selected
                      ? Icon(
                          Icons.check_rounded,
                          // White in both themes, as in the design.
                          color: AppColors.light.surface,
                          size: 20,
                        )
                      : null,
                ),
              ),
            ),
          ),
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
        _Label(label),
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
