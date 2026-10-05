// lib/services/csv_data_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/data_import_mode.dart';
import '../models/meditation_session.dart';
import '../utils/sitting_quality.dart';
import 'database_service.dart';
import 'backup_service.dart';
import 'persistence_service.dart';

class CsvDataService {
  static const _headers = [
    'id',
    'startTime',
    'endTime',
    'durationSeconds',
    'targetDurationSeconds',
    'timerMode',
    'completed',
    'quality',
    'notes',
  ];

  /// Exports all sessions to a CSV file and opens the share sheet.
  static Future<String> exportToCsv() async {
    final profileId = await PersistenceService.loadActiveProfileId();
    final sessions = await DatabaseService.getAllSessions(profileId: profileId);
    return exportSessionsToCsv(sessions);
  }

  /// Exports the given sessions list to a CSV file and opens the share sheet.
  /// [filename] defaults to 'ekatimer_sessions.csv'.
  static Future<String> exportSessionsToCsv(
    List<MeditationSession> sessions, {
    String filename = 'ekatimer_sessions.csv',
  }) async {
    final rows = <List<dynamic>>[_headers];
    for (final session in sessions) {
      rows.add([
        session.id,
        session.startTime.toIso8601String(),
        session.endTime?.toIso8601String() ?? '',
        session.durationSeconds.toString(),
        session.targetDurationSeconds.toString(),
        session.timerMode,
        session.completed ? '1' : '0',
        SittingQuality.normalize(session.quality) ?? '',
        session.notes ?? '',
      ]);
    }

    final csvString = Csv().encode(rows);

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(csvString);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Meditation Timer Session Data',
        text: 'Meditation session data from Meditation Timer',
      ),
    );

    return file.path;
  }

  /// Picks and parses a CSV file, returning the list of parsed sessions
  /// without importing them yet. Returns null if user cancels file picker.
  static Future<List<MeditationSession>?> pickAndParseCsv() async {
    // Use FileType.any + withData:true for iOS sandbox compatibility
    // (path can be null on iOS; bytes are always populated with withData:true)
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final pickedFile = result.files.single;

    // Validate it's a CSV file
    final name = pickedFile.name.toLowerCase();
    if (!name.endsWith('.csv') && !name.endsWith('.txt')) {
      throw FormatException('Please select a CSV file.');
    }

    // Read file content from bytes for iOS sandbox support. CSV is UTF-8;
    // String.fromCharCodes would corrupt every non-ASCII note or profile name.
    if (pickedFile.bytes != null) {
      return parseCsvBytes(pickedFile.bytes!);
    }
    if (pickedFile.path != null) {
      return parseCsvString(await File(pickedFile.path!).readAsString());
    }
    throw Exception('Could not read file.');
  }

  /// Decodes the UTF-8 bytes used by Android/iOS file pickers, then parses CSV.
  static Future<List<MeditationSession>> parseCsvBytes(
    List<int> bytes, {
    String? profileId,
  }) {
    return parseCsvString(utf8.decode(bytes), profileId: profileId);
  }

  /// Parses CSV text without invoking the platform file picker.
  ///
  /// [profileId] is injectable so unit tests and callers with an already-known
  /// destination profile do not depend on SharedPreferences.
  static Future<List<MeditationSession>> parseCsvString(
    String csvString, {
    String? profileId,
  }) async {
    // Excel and several Windows tools prefix UTF-8 CSV files with a BOM. It is
    // metadata, not part of the first header name.
    if (csvString.startsWith('\uFEFF')) {
      csvString = csvString.substring(1);
    }

    if (csvString.trim().isEmpty) return [];

    final rows = Csv().decode(csvString);
    if (rows.length < 2) return []; // header only or empty

    // Find column indices from header row
    final headerRow = rows[0]
        .map((e) => e.toString().trim().toLowerCase())
        .toList();
    final startTimeIdx = headerRow.indexOf('starttime');
    final durationIdx = headerRow.indexOf('durationseconds');

    if (startTimeIdx == -1 || durationIdx == -1) {
      throw FormatException(
        'CSV file must have "startTime" and "durationSeconds" columns. '
        'Found columns: ${headerRow.join(", ")}',
      );
    }

    final idIdx = headerRow.indexOf('id');
    final endTimeIdx = headerRow.indexOf('endtime');
    final targetDurationIdx = headerRow.indexOf('targetdurationseconds');
    final timerModeIdx = headerRow.indexOf('timermode');
    final completedIdx = headerRow.indexOf('completed');
    final qualityIdx = headerRow.indexOf('quality');
    final notesIdx = headerRow.indexOf('notes');

    final sessions = <MeditationSession>[];
    final uuid = const Uuid();
    final activeProfileId =
        profileId ?? await PersistenceService.loadActiveProfileId();

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= startTimeIdx || row.length <= durationIdx) continue;

      try {
        final startTime = DateTime.parse(row[startTimeIdx].toString().trim());

        final durationSeconds =
            int.tryParse(row[durationIdx].toString().trim()) ?? 0;

        if (durationSeconds <= 0) continue;

        final id =
            idIdx != -1 &&
                row.length > idIdx &&
                row[idIdx].toString().trim().isNotEmpty
            ? row[idIdx].toString().trim()
            : uuid.v4();

        final endTimeStr = endTimeIdx != -1 && row.length > endTimeIdx
            ? row[endTimeIdx].toString().trim()
            : '';
        final endTime = endTimeStr.isNotEmpty
            ? DateTime.tryParse(endTimeStr)
            : null;

        final targetDuration =
            targetDurationIdx != -1 && row.length > targetDurationIdx
            ? int.tryParse(row[targetDurationIdx].toString().trim()) ?? 0
            : 0;

        final timerMode = timerModeIdx != -1 && row.length > timerModeIdx
            ? row[timerModeIdx].toString().trim()
            : 'timed';

        final completed = completedIdx != -1 && row.length > completedIdx
            ? row[completedIdx].toString().trim() == '1'
            : true;

        final quality = qualityIdx != -1 && row.length > qualityIdx
            ? row[qualityIdx].toString().trim()
            : null;

        final notes = notesIdx != -1 && row.length > notesIdx
            ? row[notesIdx].toString().trim()
            : null;

        sessions.add(
          MeditationSession(
            id: id,
            profileId: activeProfileId,
            startTime: startTime,
            endTime: endTime,
            durationSeconds: durationSeconds,
            targetDurationSeconds: targetDuration,
            timerMode: timerMode,
            completed: completed,
            quality: SittingQuality.normalize(quality),
            notes: notes?.isNotEmpty == true ? notes : null,
          ),
        );
      } catch (_) {
        continue;
      }
    }

    return sessions;
  }

  /// Imports the given sessions into the database.
  /// Imports [sessions] (all assumed to be one profile's — enforced
  /// below) into that profile.
  ///
  /// Both modes route through [BackupService.mergeSessionLists], even
  /// `overwrite`, because the CSV itself can contain id collisions (e.g.
  /// a re-exported file) that still need deduping before the atomic
  /// replace; `overwrite` just merges against an empty existing list.
  static Future<int> importSessions(
    List<MeditationSession> sessions, {
    DataImportMode mode = DataImportMode.merge,
  }) async {
    if (sessions.isEmpty) return 0;
    final profileId = sessions.first.profileId;
    if (sessions.any((session) => session.profileId != profileId)) {
      throw const FormatException(
        'CSV sessions must belong to one active profile.',
      );
    }

    if (mode == DataImportMode.overwrite) {
      final normalized = BackupService.mergeSessionLists(
        existing: const [],
        imported: sessions,
      );
      await DatabaseService.replaceSessionsForProfile(
        profileId,
        normalized.sessions,
      );
      return normalized.sessions.length;
    }

    final existing = await DatabaseService.getAllSessions(profileId: profileId);
    final merged = BackupService.mergeSessionLists(
      existing: existing,
      imported: sessions,
    );
    await DatabaseService.replaceSessionsForProfile(profileId, merged.sessions);
    return merged.addedCount;
  }
}
