import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/meditation_session.dart';
import '../utils/sitting_quality.dart';

/// Exports sessions as a real .xlsx workbook.
///
/// The workbook is assembled by hand from the raw OOXML parts (a zip of small
/// XML files) instead of pulling in a spreadsheet-writer package, so the app
/// only pays for the `archive` dependency it already needs. If Excel's format
/// ever changes, `buildWorkbookBytes` and the `_...Xml` templates below are
/// the only places that need updating.
class ExcelDataService {
  ExcelDataService._();

  static const _headers = <String>[
    'Date',
    'Start Time',
    'End Time',
    'Duration',
    'Duration Seconds',
    'Status',
    'Timer Mode',
    'Quality',
    'Notes',
  ];

  static Future<String> exportSessionsToExcel(
    List<MeditationSession> sessions, {
    String filename = 'meditation_timer_sessions.xlsx',
  }) async {
    final bytes = buildWorkbookBytes(sessions);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        subject: 'Meditation Timer Excel Report',
        text: 'Meditation session report from Meditation Timer',
      ),
    );

    return file.path;
  }

  /// Builds a standards-based .xlsx workbook without changing the raw data.
  /// Inline strings keep notes safe from accidental spreadsheet formulas.
  static List<int> buildWorkbookBytes(List<MeditationSession> sessions) {
    final rows = <List<Object>>[_headers];
    for (final session in sessions) {
      final endTime =
          session.endTime ??
          session.startTime.add(Duration(seconds: session.durationSeconds));
      rows.add([
        _formatDate(session.startTime),
        _formatTime(session.startTime),
        _formatTime(endTime),
        _formatDuration(session.durationSeconds),
        session.durationSeconds,
        session.completed ? 'Completed' : 'Stopped',
        session.timerMode,
        SittingQuality.normalize(session.quality) ?? '',
        session.notes ?? '',
      ]);
    }

    final archive = Archive()
      ..addFile(_textFile('[Content_Types].xml', _contentTypesXml))
      ..addFile(_textFile('_rels/.rels', _packageRelationshipsXml))
      ..addFile(_textFile('xl/workbook.xml', _workbookXml))
      ..addFile(
        _textFile('xl/_rels/workbook.xml.rels', _workbookRelationshipsXml),
      )
      ..addFile(_textFile('xl/styles.xml', _stylesXml))
      ..addFile(_textFile('xl/worksheets/sheet1.xml', _worksheetXml(rows)));

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw StateError('Could not create Excel workbook.');
    }
    return encoded;
  }

  static ArchiveFile _textFile(String path, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(path, bytes.length, bytes);
  }

  static String _worksheetXml(List<List<Object>> rows) {
    final rowXml = <String>[];
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final cells = <String>[];
      for (
        var columnIndex = 0;
        columnIndex < rows[rowIndex].length;
        columnIndex++
      ) {
        final reference = '${_columnName(columnIndex + 1)}${rowIndex + 1}';
        cells.add(
          _cellXml(
            reference,
            rows[rowIndex][columnIndex],
            isHeader: rowIndex == 0,
          ),
        );
      }
      rowXml.add('<row r="${rowIndex + 1}">${cells.join()}</row>');
    }

    final lastRow = rows.length;
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <dimension ref="A1:I$lastRow"/>
  <sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>
  <sheetFormatPr defaultRowHeight="15"/>
  <cols>
    <col min="1" max="1" width="13" customWidth="1"/>
    <col min="2" max="4" width="13" customWidth="1"/>
    <col min="5" max="5" width="18" customWidth="1"/>
    <col min="6" max="8" width="15" customWidth="1"/>
    <col min="9" max="9" width="40" customWidth="1"/>
  </cols>
  <sheetData>${rowXml.join()}</sheetData>
  <autoFilter ref="A1:I$lastRow"/>
</worksheet>''';
  }

  static String _cellXml(
    String reference,
    Object value, {
    required bool isHeader,
  }) {
    final style = isHeader ? ' s="1"' : '';
    if (value is num && !isHeader) {
      return '<c r="$reference"$style><v>$value</v></c>';
    }
    return '<c r="$reference" t="inlineStr"$style><is><t xml:space="preserve">${_escapeXml(_sanitizeCellText(value.toString()))}</t></is></c>';
  }

  static String _sanitizeCellText(String value) {
    const maxCellLength = 32767;
    final result = StringBuffer();
    var length = 0;
    for (final rune in value.runes) {
      final isAllowed =
          rune == 0x09 ||
          rune == 0x0A ||
          rune == 0x0D ||
          (rune >= 0x20 && rune <= 0xD7FF) ||
          (rune >= 0xE000 && rune <= 0xFFFD) ||
          (rune >= 0x10000 && rune <= 0x10FFFF);
      if (!isAllowed) continue;
      final character = String.fromCharCode(rune);
      if (length + character.length > maxCellLength) break;
      result.write(character);
      length += character.length;
    }
    return result.toString();
  }

  static String _columnName(int column) {
    var value = column;
    final result = StringBuffer();
    while (value > 0) {
      value--;
      result.writeCharCode(65 + value % 26);
      value ~/= 26;
    }
    return result.toString().split('').reversed.join();
  }

  static String _escapeXml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');

  static String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${_twoDigits(value.month)}-${_twoDigits(value.day)}';

  static String _formatTime(DateTime value) =>
      '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}:${_twoDigits(value.second)}';

  static String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${_twoDigits(minutes)}:${_twoDigits(seconds)}';
  }

  static const _contentTypesXml =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>''';

  static const _packageRelationshipsXml =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';

  static const _workbookXml =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets><sheet name="Sessions" sheetId="1" r:id="rId1"/></sheets>
</workbook>''';

  static const _workbookRelationshipsXml =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

  static const _stylesXml =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="2">
    <font><sz val="11"/><name val="Calibri"/></font>
    <font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>
  </fonts>
  <fills count="3">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FF176B6B"/><bgColor indexed="64"/></patternFill></fill>
  </fills>
  <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
  <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
  <cellXfs count="2">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>
  </cellXfs>
  <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>''';
}
