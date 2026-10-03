import 'dart:convert';

import 'package:fitbuddy/features/mascot/data/mascot_message_templates.dart';
import 'package:fitbuddy/features/mascot/mascot_constants.dart';
import 'package:flutter/services.dart';

/// Source of mascot message templates.
abstract class MascotMessagesRepository {
  /// Loads all templates.
  Future<MascotMessageTemplates> load();
}

/// Loads templates from the bundled JSON asset.
///
/// Falls back to built-in messages if the asset is missing or invalid.
class AssetMascotMessagesRepository implements MascotMessagesRepository {
  /// Creates the repository, optionally with a custom [bundle] for tests.
  AssetMascotMessagesRepository({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  @override
  Future<MascotMessageTemplates> load() async {
    try {
      final raw = await _bundle.loadString(MascotAssets.messagesPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final templates = MascotMessageTemplates.fromJson(decoded);
      return templates.byKey.isEmpty
          ? MascotMessageTemplates.fallback
          : templates;
    } catch (_) {
      return MascotMessageTemplates.fallback;
    }
  }
}

/// In-memory repository for tests and previews.
class MockMascotMessagesRepository implements MascotMessagesRepository {
  /// Creates a mock holding [templates].
  const MockMascotMessagesRepository([
    this.templates = MascotMessageTemplates.fallback,
  ]);

  /// Templates returned by [load].
  final MascotMessageTemplates templates;

  @override
  Future<MascotMessageTemplates> load() async => templates;
}
