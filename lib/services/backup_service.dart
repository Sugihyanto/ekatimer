import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../models/data_import_mode.dart';
import '../models/meditation_session.dart';
import '../models/user_profile.dart';
import '../utils/constants.dart';
import '../utils/sitting_quality.dart';
import 'database_service.dart';

/// A full snapshot of one device's data: every profile plus every session,
/// as produced by [BackupService.buildBackupJson] and consumed by
/// [BackupService.parseBackupJson].
class AppBackup {
  final List<UserProfile> profiles;
  final String activeProfileId;
  final List<MeditationSession> sessions;

  const AppBackup({
    required this.profiles,
    required this.activeProfileId,
    required this.sessions,
  });
}

class SessionMergeResult {
  final List<MeditationSession> sessions;
  final int addedCount;
  final int duplicateCount;
  final int renamedConflictCount;

  const SessionMergeResult({
    required this.sessions,
    required this.addedCount,
    required this.duplicateCount,
    required this.renamedConflictCount,
  });
}

/// Reads and writes the JSON backup file used to move data between devices
/// or restore after a reinstall.
///
/// Restoring supports two strategies (see [DataImportMode]): a plain
/// overwrite, or [mergeBackup], which reconciles the incoming data with what
/// is already on the device — renaming any profile or session that collides
/// by id or name instead of silently dropping or clobbering it.
class BackupService {
  BackupService._();

  /// Bumped whenever the JSON shape changes in a way older app versions
  /// can't read; [parseBackupJson] rejects any other value.
  static const int formatVersion = 1;

  static String buildBackupJson({
    required Iterable<UserProfile> profiles,
    required String activeProfileId,
    required Iterable<MeditationSession> sessions,
  }) {
    final profileList = profiles.toList();
    final sessionList = sessions.toList();
    _validate(profileList, activeProfileId, sessionList);
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'meditation-timer-backup',
      'formatVersion': formatVersion,
      'appVersion': AppConstants.appVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'activeProfileId': activeProfileId,
      'profiles': profileList.map((profile) => profile.toJson()).toList(),
      'sessions': sessionList.map((session) => session.toMap()).toList(),
    });
  }

  static AppBackup parseBackupJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'meditation-timer-backup' ||
        decoded['formatVersion'] != formatVersion) {
      throw const FormatException('Unsupported Meditation Timer backup.');
    }

    final rawProfiles = decoded['profiles'];
    final rawSessions = decoded['sessions'];
    final activeProfileId = decoded['activeProfileId']?.toString() ?? '';
    if (rawProfiles is! List || rawSessions is! List) {
      throw const FormatException('Backup profiles or sessions are missing.');
    }

    final profiles = rawProfiles
        .map(
          (item) =>
              UserProfile.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final sessions = rawSessions
        .map(
          (item) =>
              MeditationSession.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    _validate(profiles, activeProfileId, sessions);
    return AppBackup(
      profiles: List.unmodifiable(profiles),
      activeProfileId: activeProfileId,
      sessions: List.unmodifiable(sessions),
    );
  }

  static Future<String?> saveBackup({
    required Iterable<UserProfile> profiles,
    required String activeProfileId,
  }) async {
    final sessions = await DatabaseService.getAllSessions();
    final json = buildBackupJson(
      profiles: profiles,
      activeProfileId: activeProfileId,
      sessions: sessions,
    );
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return FilePicker.platform.saveFile(
      dialogTitle: 'Save Meditation Timer backup',
      fileName: 'ekatimer_backup_$date.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: Uint8List.fromList(utf8.encode(json)),
    );
  }

  static Future<AppBackup?> pickBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes =
        file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) {
      throw const FileSystemException('Could not read the backup file.');
    }
    return parseBackupJson(utf8.decode(bytes));
  }

  static Future<void> restoreBackup(AppBackup backup) =>
      DatabaseService.replaceAllSessions(backup.sessions);

  static AppBackup createRestorePlan({
    required DataImportMode mode,
    required AppBackup incoming,
    required Iterable<UserProfile> existingProfiles,
    required String existingActiveProfileId,
    required Iterable<MeditationSession> existingSessions,
  }) {
    if (mode == DataImportMode.overwrite) return incoming;
    return mergeBackup(
      existingProfiles: existingProfiles,
      existingActiveProfileId: existingActiveProfileId,
      existingSessions: existingSessions,
      incoming: incoming,
    );
  }

  static AppBackup mergeBackup({
    required Iterable<UserProfile> existingProfiles,
    required String existingActiveProfileId,
    required Iterable<MeditationSession> existingSessions,
    required AppBackup incoming,
  }) {
    final localProfiles = existingProfiles.toList();
    final localSessions = existingSessions.toList();
    _validate(localProfiles, existingActiveProfileId, localSessions);

    final mergedProfiles = <UserProfile>[...localProfiles];
    final usedProfileIds = mergedProfiles.map((profile) => profile.id).toSet();
    final usedProfileNames = mergedProfiles
        .map((profile) => profile.name.trim().toLowerCase())
        .toSet();
    final profileIdMap = <String, String>{};

    for (final importedProfile in incoming.profiles) {
      final sameId = mergedProfiles
          .where((profile) => profile.id == importedProfile.id)
          .firstOrNull;
      if (sameId != null &&
          sameId.name.trim().toLowerCase() ==
              importedProfile.name.trim().toLowerCase()) {
        profileIdMap[importedProfile.id] = sameId.id;
        continue;
      }

      final mergedId = sameId == null
          ? importedProfile.id
          : _nextImportedId(importedProfile.id, usedProfileIds);
      final normalizedName = importedProfile.name.trim();
      final mergedName = usedProfileNames.contains(normalizedName.toLowerCase())
          ? _nextImportedName(normalizedName, usedProfileNames)
          : normalizedName;
      final mergedProfile = UserProfile(id: mergedId, name: mergedName);
      mergedProfiles.add(mergedProfile);
      usedProfileIds.add(mergedId);
      usedProfileNames.add(mergedName.toLowerCase());
      profileIdMap[importedProfile.id] = mergedId;
    }

    final remappedSessions = incoming.sessions.map((session) {
      final mappedProfileId = profileIdMap[session.profileId];
      if (mappedProfileId == null) {
        throw const FormatException(
          'An imported session references an unknown profile.',
        );
      }
      return session.copyWith(profileId: mappedProfileId);
    });
    final sessionMerge = mergeSessionLists(
      existing: localSessions,
      imported: remappedSessions,
    );

    return AppBackup(
      profiles: List.unmodifiable(mergedProfiles),
      activeProfileId: existingActiveProfileId,
      sessions: sessionMerge.sessions,
    );
  }

  static SessionMergeResult mergeSessionLists({
    required Iterable<MeditationSession> existing,
    required Iterable<MeditationSession> imported,
  }) {
    final merged = <MeditationSession>[...existing];
    final byId = <String, MeditationSession>{
      for (final session in merged) session.id: session,
    };
    final usedIds = byId.keys.toSet();
    var addedCount = 0;
    var duplicateCount = 0;
    var renamedConflictCount = 0;

    for (final importedSession in imported) {
      final existingSession = byId[importedSession.id];
      if (existingSession == null) {
        merged.add(importedSession);
        byId[importedSession.id] = importedSession;
        usedIds.add(importedSession.id);
        addedCount++;
        continue;
      }
      if (_sessionsEquivalent(existingSession, importedSession)) {
        duplicateCount++;
        continue;
      }

      final renamed = importedSession.copyWith(
        id: _nextImportedId(importedSession.id, usedIds),
      );
      merged.add(renamed);
      byId[renamed.id] = renamed;
      usedIds.add(renamed.id);
      addedCount++;
      renamedConflictCount++;
    }

    return SessionMergeResult(
      sessions: List.unmodifiable(merged),
      addedCount: addedCount,
      duplicateCount: duplicateCount,
      renamedConflictCount: renamedConflictCount,
    );
  }

  static void _validate(
    List<UserProfile> profiles,
    String activeProfileId,
    List<MeditationSession> sessions,
  ) {
    if (profiles.isEmpty) {
      throw const FormatException('Backup must contain at least one profile.');
    }
    final profileIds = profiles.map((profile) => profile.id.trim()).toList();
    final profileNames = profiles
        .map((profile) => profile.name.trim().toLowerCase())
        .toList();
    if (profileIds.any((id) => id.isEmpty) ||
        profileNames.any((name) => name.isEmpty) ||
        profileIds.toSet().length != profiles.length ||
        profileNames.toSet().length != profiles.length ||
        !profileIds.contains(activeProfileId)) {
      throw const FormatException('Backup profile identifiers are invalid.');
    }
    if (sessions.any((session) => !profileIds.contains(session.profileId))) {
      throw const FormatException('A session references an unknown profile.');
    }
    final sessionIds = sessions.map((session) => session.id.trim()).toList();
    if (sessionIds.any((id) => id.isEmpty) ||
        sessionIds.toSet().length != sessionIds.length) {
      throw const FormatException('Backup session identifiers are invalid.');
    }
  }

  static String _nextImportedId(String sourceId, Set<String> usedIds) {
    var sequence = 1;
    while (true) {
      final suffix = sequence == 1 ? '-imported' : '-imported-$sequence';
      final candidate = '$sourceId$suffix';
      if (!usedIds.contains(candidate)) return candidate;
      sequence++;
    }
  }

  static String _nextImportedName(String sourceName, Set<String> usedNames) {
    var sequence = 1;
    while (true) {
      final suffix = sequence == 1 ? ' (Imported)' : ' (Imported $sequence)';
      final maximumBaseLength = 50 - suffix.length;
      final base = sourceName.length <= maximumBaseLength
          ? sourceName
          : sourceName.substring(0, maximumBaseLength);
      final candidate = '$base$suffix';
      if (!usedNames.contains(candidate.toLowerCase())) return candidate;
      sequence++;
    }
  }

  static bool _sessionsEquivalent(
    MeditationSession first,
    MeditationSession second,
  ) =>
      first.profileId == second.profileId &&
      first.startTime.millisecondsSinceEpoch ==
          second.startTime.millisecondsSinceEpoch &&
      first.endTime?.millisecondsSinceEpoch ==
          second.endTime?.millisecondsSinceEpoch &&
      first.durationSeconds == second.durationSeconds &&
      first.targetDurationSeconds == second.targetDurationSeconds &&
      first.timerMode == second.timerMode &&
      first.completed == second.completed &&
      SittingQuality.normalize(first.quality) ==
          SittingQuality.normalize(second.quality) &&
      first.notes == second.notes;
}
