import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../services/appearance_service.dart';
import '../services/vault_service.dart';
import '../services/vault_transfer_service.dart';
import '../theme/app_theme.dart';
import 'widgets/primitives.dart';
import 'widgets/theme_gallery.dart';

enum _Section { general, appearance, editor, vault, shortcuts }

/// A real, multi-section settings screen: general behaviour, appearance,
/// editor preferences, vault management, and a keyboard-shortcut reference -
/// not just a handful of controls dropped on one page.
class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key, required this.vault, required this.preferences});

  final VaultService vault;
  final AppPreferences preferences;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  _Section _section = _Section.general;
  late final _pathController = TextEditingController(text: widget.vault.path);

  String _skinId = Palette.skin.id;
  int _motionLevel = Motion.level;
  String _density = 'comfortable';
  double _textScale = Layout.textScale;
  late AppPreferences _prefs = widget.preferences;

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  void _reapplyAppearance() {
    applyAppearance(
      skinId: _skinId,
      accentOverride: 0,
      motionLevel: _motionLevel,
      densityScale: switch (_density) { 'compact' => 0.82, 'spacious' => 1.18, _ => 1.0 },
      textScale: _textScale,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 168,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final section in _Section.values)
                _NavItem(
                  icon: _iconFor(section),
                  label: _labelFor(section),
                  selected: section == _section,
                  onTap: () => setState(() => _section = section),
                ),
            ],
          ),
        ),
        const SizedBox(width: 22),
        Expanded(
          child: AnimatedSwitcher(
            duration: Motion.base,
            switchInCurve: Motion.swift,
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: QuietScroll(
              key: ValueKey(_section),
              child: switch (_section) {
                _Section.general => _GeneralSection(
                    prefs: _prefs,
                    onChanged: (p) {
                      setState(() => _prefs = p);
                      AppearanceStore.setShowInboxBadge(p.showInboxBadge);
                      AppearanceStore.setConfirmDelete(p.confirmDelete);
                      AppearanceStore.setDefaultNoteType(p.defaultNoteType);
                    },
                  ),
                _Section.appearance => _AppearanceSection(
                    skinId: _skinId,
                    density: _density,
                    motionLevel: _motionLevel,
                    textScale: _textScale,
                    onSkin: (id) {
                      _skinId = id;
                      AppearanceStore.setSkin(id);
                      _reapplyAppearance();
                    },
                    onDensity: (d) {
                      _density = d;
                      AppearanceStore.setDensity(d);
                      _reapplyAppearance();
                    },
                    onMotion: (m) {
                      _motionLevel = m;
                      AppearanceStore.setMotionLevel(m);
                      _reapplyAppearance();
                    },
                    onTextScale: (s) {
                      _textScale = s;
                      AppearanceStore.setTextScale(s);
                      _reapplyAppearance();
                    },
                  ),
                _Section.editor => _EditorSection(
                    prefs: _prefs,
                    onChanged: (p) {
                      setState(() => _prefs = p);
                      AppearanceStore.setEditorFontSize(p.editorFontSize);
                      AppearanceStore.setEditorLineHeight(p.editorLineHeight);
                    },
                  ),
                _Section.vault => _VaultSection(
                    vault: widget.vault,
                    pathController: _pathController,
                  ),
                _Section.shortcuts => const _ShortcutsSection(),
              },
            ),
          ),
        ),
      ],
    );
  }

  static IconData _iconFor(_Section s) => switch (s) {
        _Section.general => Icons.tune_rounded,
        _Section.appearance => Icons.palette_outlined,
        _Section.editor => Icons.edit_note_rounded,
        _Section.vault => Icons.folder_outlined,
        _Section.shortcuts => Icons.keyboard_outlined,
      };

  static String _labelFor(_Section s) => switch (s) {
        _Section.general => 'General',
        _Section.appearance => 'Appearance',
        _Section.editor => 'Editor',
        _Section.vault => 'Vault',
        _Section.shortcuts => 'Shortcuts',
      };
}

class _NavItem extends StatefulWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: active ? Palette.amber.withValues(alpha: 0.1) : (_hover ? Palette.surfaceRaised : Colors.transparent),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: active ? Palette.amber : Palette.textSecondary),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: AppType.body.copyWith(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? Palette.amber : Palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- General ------------------------------------------------------------

class _GeneralSection extends StatelessWidget {
  const _GeneralSection({required this.prefs, required this.onChanged});
  final AppPreferences prefs;
  final ValueChanged<AppPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('BEHAVIOUR'),
        SizedBox(height: Layout.rowGap),
        SettingSwitch(
          label: 'Confirm before deleting',
          description: 'Ask before permanently removing a note.',
          value: prefs.confirmDelete,
          onChanged: (v) => onChanged(prefs.copyWith(confirmDelete: v)),
        ),
        SettingSwitch(
          label: 'Show inbox count badge',
          description: 'Displays how many notes are waiting to be processed.',
          value: prefs.showInboxBadge,
          onChanged: (v) => onChanged(prefs.copyWith(showInboxBadge: v)),
        ),
        SizedBox(height: Layout.gap),
        const SectionLabel('NEW NOTES'),
        SizedBox(height: Layout.rowGap),
        Text(
          'What a freshly created note is tagged as by default.',
          style: AppType.small,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          children: [
            for (final type in ['fleeting', 'literature', 'permanent'])
              MiniChip(
                label: type[0].toUpperCase() + type.substring(1),
                selected: prefs.defaultNoteType == type,
                onTap: () => onChanged(prefs.copyWith(defaultNoteType: type)),
              ),
          ],
        ),
      ],
    );
  }
}

// --- Appearance -----------------------------------------------------------

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({
    required this.skinId,
    required this.density,
    required this.motionLevel,
    required this.textScale,
    required this.onSkin,
    required this.onDensity,
    required this.onMotion,
    required this.onTextScale,
  });

  final String skinId;
  final String density;
  final int motionLevel;
  final double textScale;
  final ValueChanged<String> onSkin;
  final ValueChanged<String> onDensity;
  final ValueChanged<int> onMotion;
  final ValueChanged<double> onTextScale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('THEME'),
        SizedBox(height: Layout.tight),
        ThemeGallery(selected: skinId, onSelect: onSkin),
        SizedBox(height: Layout.gap),
        const SectionLabel('LAYOUT'),
        SizedBox(height: Layout.tight),
        _ChoiceRow(
          label: 'Density',
          options: const ['Compact', 'Comfortable', 'Spacious'],
          index: const ['compact', 'comfortable', 'spacious'].indexOf(density),
          onChanged: (i) => onDensity(const ['compact', 'comfortable', 'spacious'][i]),
        ),
        SizedBox(height: Layout.tight),
        _ChoiceRow(
          label: 'Motion',
          options: const ['Reduced', 'Normal', 'Expressive'],
          index: motionLevel,
          onChanged: onMotion,
        ),
        SizedBox(height: Layout.tight),
        _ChoiceRow(
          label: 'Text size',
          options: const ['Small', 'Default', 'Large', 'Larger'],
          index: switch (textScale) { < 0.95 => 0, < 1.05 => 1, < 1.2 => 2, _ => 3 },
          onChanged: (i) => onTextScale(const [0.9, 1.0, 1.12, 1.25][i]),
        ),
      ],
    );
  }
}

// --- Editor ---------------------------------------------------------------

class _EditorSection extends StatelessWidget {
  const _EditorSection({required this.prefs, required this.onChanged});
  final AppPreferences prefs;
  final ValueChanged<AppPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('EDITOR TEXT'),
        SizedBox(height: Layout.rowGap),
        _ChoiceRow(
          label: 'Font size',
          options: const ['12', '13', '14', '16'],
          index: const [12.0, 13.0, 14.0, 16.0].indexWhere((v) => (v - prefs.editorFontSize).abs() < 0.5)
              .clamp(0, 3),
          onChanged: (i) => onChanged(prefs.copyWith(editorFontSize: const [12.0, 13.0, 14.0, 16.0][i])),
        ),
        SizedBox(height: Layout.tight),
        _ChoiceRow(
          label: 'Line height',
          options: const ['Tight', 'Normal', 'Relaxed'],
          index: switch (prefs.editorLineHeight) { < 1.5 => 0, < 1.85 => 1, _ => 2 },
          onChanged: (i) => onChanged(prefs.copyWith(editorLineHeight: const [1.35, 1.7, 2.0][i])),
        ),
        SizedBox(height: Layout.gap),
        Container(
          padding: EdgeInsets.all(Layout.cardPad),
          decoration: BoxDecoration(
            color: Palette.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Palette.hairline),
          ),
          child: Text(
            '# A preview heading\n\nBody text at the size and spacing above, '
            'with a [[wikilink]] and a #tag for reference.',
            style: AppType.mono.copyWith(
              color: Palette.textPrimary,
              fontSize: prefs.editorFontSize,
              height: prefs.editorLineHeight,
            ),
          ),
        ),
      ],
    );
  }
}

// --- Vault ------------------------------------------------------------

class _VaultSection extends StatefulWidget {
  const _VaultSection({required this.vault, required this.pathController});
  final VaultService vault;
  final TextEditingController pathController;

  @override
  State<_VaultSection> createState() => _VaultSectionState();
}

class _VaultSectionState extends State<_VaultSection> {
  String _status = '';
  bool _busy = false;
  late final _importController = TextEditingController();

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final vault = widget.vault;
      await vault.flushPendingWrites();

      final downloads = await _downloadsDir();
      final stamp = DateTime.now();
      final name = 'Pilebox-vault-'
          '${stamp.year}${stamp.month.toString().padLeft(2, '0')}${stamp.day.toString().padLeft(2, '0')}'
          '-${stamp.hour.toString().padLeft(2, '0')}${stamp.minute.toString().padLeft(2, '0')}.zip';
      final zipPath = '${downloads.path}\\$name';

      final count = await VaultTransferService.export(vault.path, zipPath);
      if (!mounted) return;
      setState(() => _status = 'Exported $count notes to $zipPath');
    } catch (e) {
      if (mounted) setState(() => _status = 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final zipPath = _importController.text.trim();
    if (zipPath.isEmpty) {
      setState(() => _status = 'Paste the path to a .zip file first.');
      return;
    }

    setState(() => _busy = true);
    try {
      await VaultTransferService.import(zipPath, widget.vault.path);
      await widget.vault.setPath(widget.vault.path); // rescans from disk
      if (!mounted) return;
      setState(() => _status = 'Import complete. ${widget.vault.notes.length} notes in vault.');
    } catch (e) {
      if (mounted) setState(() => _status = 'Import failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static Future<Directory> _downloadsDir() async {
    try {
      final dir = await getDownloadsDirectory();
      if (dir != null) return dir;
    } catch (_) {
      // Fall through.
    }
    final docs = await getApplicationDocumentsDirectory();
    return docs;
  }

  @override
  Widget build(BuildContext context) {
    final vault = widget.vault;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('LOCATION'),
        const SizedBox(height: 4),
        Text(
          'Where your notes live on disk - plain .md files, no lock-in. '
          'Point this anywhere, including a synced folder.',
          style: AppType.small,
        ),
        SizedBox(height: Layout.rowGap),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Palette.surfaceRaised,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: Palette.hairline),
                ),
                child: TextField(
                  controller: widget.pathController,
                  style: AppType.mono.copyWith(fontSize: 12, color: Palette.textPrimary),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            ActionButton(
              label: 'Use folder',
              compact: true,
              primary: true,
              onPressed: () {
                vault.setPath(widget.pathController.text.trim());
                setState(() => _status = 'Vault switched.');
              },
            ),
          ],
        ),
        SizedBox(height: Layout.gap),
        const SectionLabel('STATISTICS'),
        SizedBox(height: Layout.rowGap),
        ListenableBuilder(
          listenable: vault,
          builder: (context, _) => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatTile(label: 'Total notes', value: '${vault.notes.length}'),
              _StatTile(label: 'Inbox', value: '${vault.inbox.length}'),
              _StatTile(label: 'Orphans', value: '${vault.orphans.length}'),
              _StatTile(label: 'Pinned', value: '${vault.pinned.length}'),
              _StatTile(label: 'Tags', value: '${vault.tagCounts.length}'),
            ],
          ),
        ),
        SizedBox(height: Layout.gap),
        const SectionLabel('BACKUP'),
        SizedBox(height: Layout.rowGap),
        Text(
          'Every note is already a plain file, so any file backup or sync '
          'tool works without special support. Opening the folder directly '
          'is the fastest way to copy the whole vault.',
          style: AppType.small.copyWith(height: 1.6),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            ActionButton(
              label: 'Open vault folder',
              icon: Icons.folder_open_rounded,
              compact: true,
              onPressed: () => Process.start('explorer.exe', [vault.path]),
            ),
            const SizedBox(width: 9),
            ActionButton(
              label: 'Flush unsaved edits',
              icon: Icons.save_outlined,
              compact: true,
              onPressed: () async {
                await vault.flushPendingWrites();
                setState(() => _status = 'All edits saved to disk.');
              },
            ),
          ],
        ),
        SizedBox(height: Layout.gap),
        const SectionLabel('EXPORT & IMPORT'),
        SizedBox(height: Layout.rowGap),
        Text(
          'Export bundles every note into one .zip - a single file to hand '
          'to someone else or carry to a new machine, saved to your '
          'Downloads folder.',
          style: AppType.small.copyWith(height: 1.6),
        ),
        const SizedBox(height: 10),
        ActionButton(
          label: _busy ? 'Working...' : 'Export vault as .zip',
          icon: Icons.upload_file_outlined,
          compact: true,
          enabled: !_busy,
          onPressed: _export,
        ),
        SizedBox(height: Layout.gap),
        Text(
          'Import merges a previously exported .zip into the current vault. '
          'Notes with the same file name are overwritten; nothing else is '
          'touched.',
          style: AppType.small.copyWith(height: 1.6),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Palette.surfaceRaised,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: Palette.hairline),
                ),
                child: TextField(
                  controller: _importController,
                  style: AppType.mono.copyWith(fontSize: 12, color: Palette.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    hintText: 'Path to a .zip file',
                    hintStyle: AppType.mono.copyWith(fontSize: 12, color: Palette.textTertiary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            ActionButton(
              label: 'Import',
              compact: true,
              enabled: !_busy,
              onPressed: _import,
            ),
          ],
        ),
        if (_status.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(_status, style: AppType.small.copyWith(color: Palette.live)),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppType.heading.copyWith(fontSize: 20)),
          const SizedBox(height: 2),
          Text(label, style: AppType.label),
        ],
      ),
    );
  }
}

// --- Shortcuts --------------------------------------------------------

class _ShortcutsSection extends StatelessWidget {
  const _ShortcutsSection();

  static const _shortcuts = [
    ('Ctrl + K', 'Open the command palette'),
    ('Ctrl + N', 'Create a new note'),
    ('Ctrl + F', 'Focus the note search field'),
    ('Ctrl + P', 'Toggle pin on the open note'),
    ('Ctrl + E', 'Toggle edit / preview'),
    ('Esc', 'Close a dialog or the command palette'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('KEYBOARD SHORTCUTS'),
        SizedBox(height: Layout.gap),
        for (final s in _shortcuts)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 96,
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: Palette.surfaceRaised,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Palette.hairline),
                  ),
                  alignment: Alignment.center,
                  child: Text(s.$1, style: AppType.timecode.copyWith(fontSize: 11)),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(s.$2, style: AppType.body.copyWith(fontSize: 12.5))),
              ],
            ),
          ),
      ],
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.label, required this.options, required this.index, required this.onChanged});

  final String label;
  final List<String> options;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: AppType.body.copyWith(color: Palette.textPrimary, fontWeight: FontWeight.w600)),
        ),
        Wrap(
          spacing: 6,
          children: [
            for (var i = 0; i < options.length; i++)
              MiniChip(label: options[i], selected: i == index, onTap: () => onChanged(i)),
          ],
        ),
      ],
    );
  }
}
