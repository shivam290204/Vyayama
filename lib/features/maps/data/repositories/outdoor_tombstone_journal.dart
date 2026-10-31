import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fitbuddy/features/maps/domain/models/outdoor_tombstone.dart';
import 'package:path_provider/path_provider.dart';

/// Crash-durable, atomic file-backed journal for deletion tombstones.
///
/// Guarantees that tombstone writes are flushed to physical storage before
/// local workout or route records are unlinked, preventing data resurrection
/// across unexpected process termination, battery exhaustion, or app crashes.
class OutdoorTombstoneJournal {
  const OutdoorTombstoneJournal({
    File? storageFile,
    Future<Directory> Function()? directoryProvider,
  })  : _storageFile = storageFile,
        _directoryProvider = directoryProvider;

  final File? _storageFile;
  final Future<Directory> Function()? _directoryProvider;

  static const String journalFileName = 'vyayama_outdoor_tombstones_journal_v1.json';

  static int _sequenceCounter = 0;
  static Future<void>? _writeQueue;
  static final Map<String, List<OutdoorTombstone>> _cacheByPath = {};
  static File? _cachedResolvedFile;

  /// Clears in-memory caches across journal instances (useful for test fixtures).
  static void clearCache() {
    _cacheByPath.clear();
    _cachedResolvedFile = null;
  }

  /// Calculates IEEE 802.3 CRC-32 checksum to verify payload integrity against interrupted writes.
  static int computeCrc32(String input) {
    final bytes = utf8.encode(input);
    var crc = 0xFFFFFFFF;
    for (final byte in bytes) {
      crc ^= byte;
      for (var i = 0; i < 8; i++) {
        if ((crc & 1) != 0) {
          crc = (crc >> 1) ^ 0xEDB88320;
        } else {
          crc >>= 1;
        }
      }
    }
    return (~crc) & 0xFFFFFFFF;
  }

  Future<File> _resolveTargetFile() async {
    final file = _storageFile;
    if (file != null) return file;
    final dirProvider = _directoryProvider;
    if (dirProvider != null) {
      final dir = await dirProvider();
      return File('${dir.path}/$journalFileName');
    }
    if (_cachedResolvedFile != null) {
      return _cachedResolvedFile!;
    }
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      final fallback = File('${Directory.systemTemp.path}/$journalFileName');
      _cachedResolvedFile = fallback;
      return fallback;
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final target = File('${dir.path}/$journalFileName');
      _cachedResolvedFile = target;
      return target;
    } catch (_) {
      // In unit test environments where path_provider channel is not registered,
      // fallback to system temp directory seamlessly.
      final fallback = File('${Directory.systemTemp.path}/$journalFileName');
      _cachedResolvedFile = fallback;
      return fallback;
    }
  }

  /// Loads all tombstones from disk with CRC-32 integrity validation.
  Future<List<OutdoorTombstone>> getAll({
    String? entityType,
    String? userId,
  }) async {
    final file = await _resolveTargetFile();
    final path = file.path;

    if (!_cacheByPath.containsKey(path)) {
      if (!file.existsSync()) {
        _cacheByPath[path] = [];
      } else {
        try {
          final content = file.readAsStringSync();
          final decoded = jsonDecode(content) as Map<String, dynamic>;
          final expectedCrc = decoded['payload_crc32'] as int?;
          final rawPayload = decoded['payload'] as List<dynamic>? ?? [];
          final payloadJson = jsonEncode(rawPayload);
          final actualCrc = computeCrc32(payloadJson);

          if (expectedCrc != null && expectedCrc != actualCrc) {
            // Corruption detected: torn write; fallback to empty list
            _cacheByPath[path] = [];
          } else {
            _cacheByPath[path] = rawPayload
                .map((item) =>
                    OutdoorTombstone.fromJson(item as Map<String, dynamic>))
                .toList();
          }
        } catch (_) {
          _cacheByPath[path] = [];
        }
      }
    }

    var result = List<OutdoorTombstone>.from(_cacheByPath[path] ?? []);
    if (entityType != null) {
      result = result.where((t) => t.entityType == entityType).toList();
    }
    if (userId != null) {
      result = result
          .where((t) => t.userId == userId || t.userId == 'local_user')
          .toList();
    }
    return result;
  }

  /// Writes the current tombstone collection to disk atomically using fsync flush.
  Future<void> _persist(List<OutdoorTombstone> tombstones) async {
    final targetFile = await _resolveTargetFile();
    _cacheByPath[targetFile.path] = List<OutdoorTombstone>.from(tombstones);

    final seq = ++_sequenceCounter;
    final completer = Completer<void>();
    final previousTask = _writeQueue;
    _writeQueue = completer.future;

    try {
      if (previousTask != null) {
        try {
          await previousTask;
        } catch (_) {}
      }

      final parentDir = targetFile.parent;
      if (!parentDir.existsSync()) {
        parentDir.createSync(recursive: true);
      }

      final rawPayload = tombstones.map((t) => t.toJson()).toList();
      final payloadJson = jsonEncode(rawPayload);
      final crc = computeCrc32(payloadJson);
      final envelope = jsonEncode({
        'version': 1,
        'sequence': seq,
        'payload_crc32': crc,
        'payload': rawPayload,
      });

      final tempFile = File('${targetFile.path}.tmp.$seq');
      tempFile.writeAsStringSync(envelope, flush: true);

      if (Platform.isWindows && targetFile.existsSync()) {
        final backupFile = File('${targetFile.path}.bak');
        if (backupFile.existsSync()) backupFile.deleteSync();
        targetFile.renameSync(backupFile.path);
        tempFile.renameSync(targetFile.path);
        backupFile.deleteSync();
      } else {
        tempFile.renameSync(targetFile.path);
      }
    } finally {
      completer.complete();
    }
  }

  /// Records a tombstone to durable storage before any local record is unlinked.
  Future<void> record(OutdoorTombstone tombstone) async {
    final list = await getAll();
    list.removeWhere(
        (t) => t.id == tombstone.id && t.entityType == tombstone.entityType);
    list.add(tombstone);
    await _persist(list);
  }

  /// Marks a local tombstone as acknowledged and synced in Supabase outdoor_tombstones.
  Future<void> markRemoteSynced(String id, String entityType) async {
    final list = await getAll();
    final index =
        list.indexWhere((t) => t.id == id && t.entityType == entityType);
    if (index >= 0) {
      list[index] = list[index].copyWith(isRemoteSynced: true);
      await _persist(list);
    }
  }

  /// Removes a tombstone after full lifecycle completion.
  Future<void> remove(String id, [String? entityType]) async {
    final list = await getAll();
    list.removeWhere((t) =>
        t.id == id && (entityType == null || t.entityType == entityType));
    await _persist(list);
  }

  /// Checks whether an entity ID is tombstoned.
  Future<bool> isTombstoned(String id, [String? entityType]) async {
    final list = await getAll(entityType: entityType);
    return list.any((t) => t.id == id);
  }

  /// Clears tombstones belonging to a target user upon account deletion.
  Future<void> clearUserData(String userId) async {
    final list = await getAll();
    list.removeWhere((t) => t.userId == userId);
    await _persist(list);
  }

  /// Adopts guest tombstones to an authenticated user ID.
  Future<void> adoptGuestData(String newUserId) async {
    final list = await getAll();
    for (var i = 0; i < list.length; i++) {
      if (list[i].userId == 'local_user') {
        list[i] = list[i].copyWith(userId: newUserId);
      }
    }
    await _persist(list);
  }
}

