import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fitbuddy/core/constants/env.dart';
import 'package:fitbuddy/features/health_profile/data/condition_rule.dart';
import 'package:fitbuddy/features/health_profile/data/health_repository.dart';
import 'package:fitbuddy/features/health_profile/data/meal_reminder_settings.dart';
import 'package:fitbuddy/features/health_profile/data/medicine.dart';

/// Offline-first [HealthRepository] backed by Supabase `user_conditions`
/// and `medicines` tables, with local [SharedPreferences] cache fallback.
class SupabaseHealthRepository implements HealthRepository {
  SupabaseHealthRepository({
    required SharedPreferences prefs,
    SupabaseClient? client,
    AssetBundle? bundle,
  })  : _prefs = prefs,
        _client = client ??
            (Env.isSupabaseConfigured ? Supabase.instance.client : null),
        _bundle = bundle ?? rootBundle;

  static const String _kConditionsKey = 'vyayama_health_selected_conditions';
  static const String _kMedicinesKey = 'vyayama_health_medicines_list';
  static const String _kMealRemindersKey = 'vyayama_health_meal_reminders';

  final SharedPreferences _prefs;
  final SupabaseClient? _client;
  final AssetBundle _bundle;

  List<ConditionRule>? _cachedRules;

  String? get _currentUserId => _client?.auth.currentUser?.id;

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static String _generateUuid() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // RFC 4122 v4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 10
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  Future<List<ConditionRule>> loadConditionRules() async {
    final cached = _cachedRules;
    if (cached != null) return cached;
    final raw = await _bundle.loadString('assets/data/conditions.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final rules = (decoded['conditions'] as List<dynamic>)
        .map((e) => ConditionRule.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    _cachedRules = rules;
    return rules;
  }

  @override
  Future<List<String>> getSelectedConditionKeys() async {
    final client = _client;
    final uid = _currentUserId;

    if (client != null && uid != null) {
      try {
        final res = await client
            .from('user_conditions')
            .select('condition_key')
            .eq('user_id', uid);

        final keys = (res as List<dynamic>)
            .map((row) => (row as Map<String, dynamic>)['condition_key'] as String)
            .toList();

        // Update local cache
        await _prefs.setStringList(_kConditionsKey, keys);
        return List<String>.unmodifiable(keys);
      } catch (e) {
        debugPrint('[SupabaseHealthRepository] Remote condition fetch error: $e');
      }
    }

    // Local fallback
    final list = _prefs.getStringList(_kConditionsKey);
    return list != null ? List<String>.unmodifiable(list) : const <String>[];
  }

  @override
  Future<void> saveSelectedConditionKeys(List<String> keys) async {
    // 1. Save locally immediately
    await _prefs.setStringList(_kConditionsKey, keys);

    // 2. Sync to Supabase if connected
    final client = _client;
    final uid = _currentUserId;

    if (client != null && uid != null) {
      try {
        // Delete previous conditions for user
        await client.from('user_conditions').delete().eq('user_id', uid);

        // Insert new condition rows
        if (keys.isNotEmpty) {
          final rows = keys
              .map((k) => <String, dynamic>{
                    'user_id': uid,
                    'condition_key': k,
                  })
              .toList();
          await client.from('user_conditions').insert(rows);
        }
      } catch (e) {
        debugPrint('[SupabaseHealthRepository] Remote condition save error: $e');
      }
    }
  }

  @override
  Future<List<Medicine>> listMedicines() async {
    final client = _client;
    final uid = _currentUserId;

    if (client != null && uid != null) {
      try {
        final res = await client
            .from('medicines')
            .select()
            .eq('user_id', uid);

        final medicines = (res as List<dynamic>)
            .map((row) => Medicine.fromJson(Map<String, dynamic>.from(row as Map)))
            .toList();

        // Update local cache
        final rawList = medicines.map((m) => jsonEncode(m.toJson())).toList();
        await _prefs.setStringList(_kMedicinesKey, rawList);
        return List<Medicine>.unmodifiable(medicines);
      } catch (e) {
        debugPrint('[SupabaseHealthRepository] Remote medicines fetch error: $e');
      }
    }

    // Local fallback
    final rawList = _prefs.getStringList(_kMedicinesKey);
    if (rawList == null || rawList.isEmpty) return const <Medicine>[];
    final result = <Medicine>[];
    for (final raw in rawList) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        result.add(Medicine.fromJson(map));
      } catch (_) {}
    }
    return List<Medicine>.unmodifiable(result);
  }

  @override
  Future<Medicine> saveMedicine(Medicine medicine) async {
    final uid = _currentUserId ?? medicine.userId;
    final id = (medicine.id.isNotEmpty && _uuidRegex.hasMatch(medicine.id))
        ? medicine.id
        : _generateUuid();

    final toSave = medicine.copyWith(
      id: id,
      userId: uid,
    );

    // 1. Save locally
    final current = (await listMedicines()).toList();
    final index = current.indexWhere((m) => m.id == toSave.id);
    if (index >= 0) {
      current[index] = toSave;
    } else {
      current.add(toSave);
    }
    final rawList = current.map((m) => jsonEncode(m.toJson())).toList();
    await _prefs.setStringList(_kMedicinesKey, rawList);

    // 2. Sync to Supabase if connected
    final client = _client;
    if (client != null && uid.isNotEmpty) {
      try {
        await client.from('medicines').upsert(toSave.toJson());
      } catch (e) {
        debugPrint('[SupabaseHealthRepository] Remote medicine save error: $e');
      }
    }

    return toSave;
  }

  @override
  Future<void> deleteMedicine(String id) async {
    // 1. Delete locally
    final current = (await listMedicines()).toList();
    current.removeWhere((m) => m.id == id);
    final rawList = current.map((m) => jsonEncode(m.toJson())).toList();
    await _prefs.setStringList(_kMedicinesKey, rawList);

    // 2. Sync to Supabase
    final client = _client;
    final uid = _currentUserId;
    if (client != null && uid != null) {
      try {
        await client.from('medicines').delete().eq('id', id);
      } catch (e) {
        debugPrint('[SupabaseHealthRepository] Remote medicine delete error: $e');
      }
    }
  }

  @override
  Future<MealReminderSettings> getMealReminders() async {
    final raw = _prefs.getString(_kMealRemindersKey);
    if (raw == null) return MealReminderSettings.defaults();
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return MealReminderSettings.fromJson(decoded);
    } catch (_) {
      return MealReminderSettings.defaults();
    }
  }

  @override
  Future<void> saveMealReminders(MealReminderSettings settings) async {
    await _prefs.setString(_kMealRemindersKey, jsonEncode(settings.toJson()));
  }
}
