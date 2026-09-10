import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/app_theme.dart';

/// Persists appearance (skin/accent/motion/density/text scale) and general
/// editor/behaviour preferences in one settings.json - the same file
/// [bootstrapSkin] reads before the first frame.
class AppearanceStore {
  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}\\settings.json');
  }

  static Future<Map<String, dynamic>> _read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return {};
      final json = jsonDecode(await file.readAsString());
      return json is Map<String, dynamic> ? json : {};
    } catch (_) {
      return {};
    }
  }

  static Future<void> _write(Map<String, dynamic> json) async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(json));
    } catch (_) {
      // Non-fatal.
    }
  }

  static Future<void> setSkin(String skinId) async {
    final json = await _read();
    json['skinId'] = skinId;
    await _write(json);
  }

  static Future<void> setAccent(int argb) async {
    final json = await _read();
    json['accentOverride'] = argb;
    await _write(json);
  }

  static Future<void> setMotionLevel(int level) async {
    final json = await _read();
    json['motionLevel'] = switch (level) { 0 => 'reduced', 2 => 'expressive', _ => 'normal' };
    await _write(json);
  }

  static Future<void> setDensity(String density) async {
    final json = await _read();
    json['density'] = density;
    await _write(json);
  }

  static Future<void> setTextScale(double scale) async {
    final json = await _read();
    json['textScale'] = scale;
    await _write(json);
  }

  // --- General preferences, read once at startup -------------------------

  static Future<AppPreferences> loadPreferences() async {
    final json = await _read();
    return AppPreferences.fromJson(json);
  }

  static Future<void> setEditorFontSize(double size) async {
    final json = await _read();
    json['editorFontSize'] = size;
    await _write(json);
  }

  static Future<void> setEditorLineHeight(double height) async {
    final json = await _read();
    json['editorLineHeight'] = height;
    await _write(json);
  }

  static Future<void> setDefaultNoteType(String type) async {
    final json = await _read();
    json['defaultNoteType'] = type;
    await _write(json);
  }

  static Future<void> setShowInboxBadge(bool value) async {
    final json = await _read();
    json['showInboxBadge'] = value;
    await _write(json);
  }

  static Future<void> setConfirmDelete(bool value) async {
    final json = await _read();
    json['confirmDelete'] = value;
    await _write(json);
  }
}

/// General, non-appearance preferences. Read once into memory at startup
/// and consulted directly by the widgets that need them, rather than
/// re-reading disk on every build.
@immutable
class AppPreferences {
  const AppPreferences({
    this.editorFontSize = 13,
    this.editorLineHeight = 1.7,
    this.defaultNoteType = 'fleeting',
    this.showInboxBadge = true,
    this.confirmDelete = true,
  });

  final double editorFontSize;
  final double editorLineHeight;
  final String defaultNoteType;
  final bool showInboxBadge;
  final bool confirmDelete;

  factory AppPreferences.fromJson(Map<String, dynamic> json) {
    double asDouble(Object? v, double fallback) => v is num ? v.toDouble() : fallback;
    return AppPreferences(
      editorFontSize: asDouble(json['editorFontSize'], 13),
      editorLineHeight: asDouble(json['editorLineHeight'], 1.7),
      defaultNoteType: json['defaultNoteType'] as String? ?? 'fleeting',
      showInboxBadge: json['showInboxBadge'] as bool? ?? true,
      confirmDelete: json['confirmDelete'] as bool? ?? true,
    );
  }

  AppPreferences copyWith({
    double? editorFontSize,
    double? editorLineHeight,
    String? defaultNoteType,
    bool? showInboxBadge,
    bool? confirmDelete,
  }) {
    return AppPreferences(
      editorFontSize: editorFontSize ?? this.editorFontSize,
      editorLineHeight: editorLineHeight ?? this.editorLineHeight,
      defaultNoteType: defaultNoteType ?? this.defaultNoteType,
      showInboxBadge: showInboxBadge ?? this.showInboxBadge,
      confirmDelete: confirmDelete ?? this.confirmDelete,
    );
  }
}

/// Applies the current appearance state to [Palette] and friends. Called
/// after any settings change so the UI updates immediately.
void applyAppearance({
  required String skinId,
  required int accentOverride,
  required int motionLevel,
  required double densityScale,
  required double textScale,
}) {
  Palette.apply(
    Skins.byId(skinId),
    accentOverride: accentOverride == 0 ? null : Color(accentOverride),
  );
  Motion.level = motionLevel;
  Layout.apply(densityScale, textScale);
}
