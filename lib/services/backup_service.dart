import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/underground_template.dart';

class BackupServiceException implements Exception {
  BackupServiceException(this.message, {required this.code});

  final String message;
  final BackupServiceErrorCode code;

  @override
  String toString() => 'BackupServiceException($code): $message';
}

enum BackupServiceErrorCode { io, archive, json }

@immutable
class InspectionBackupData {
  const InspectionBackupData({
    required this.inspectionJson,
    required this.documentNumber,
    required this.customer,
    required this.workOrderNumber,
    this.photoFiles = const <File>[],
    this.generatedPdfFile,
  });

  final Map<String, dynamic> inspectionJson;
  final String documentNumber;
  final String customer;
  final String workOrderNumber;
  final List<File> photoFiles;
  final File? generatedPdfFile;
}

@immutable
class BackupExportResult {
  const BackupExportResult({
    required this.archiveFile,
    required this.warnings,
    required this.exportedFileCount,
  });

  final File archiveFile;
  final List<String> warnings;
  final int exportedFileCount;
}

@immutable
class BackupImportResult {
  const BackupImportResult({
    required this.inspectionJson,
    required this.restoredPhotoFiles,
    required this.restoredPdfFile,
    required this.documentNumber,
    required this.documentNumberChanged,
    required this.warnings,
  });

  final Map<String, dynamic> inspectionJson;
  final List<File> restoredPhotoFiles;
  final File? restoredPdfFile;
  final String documentNumber;
  final bool documentNumberChanged;
  final List<String> warnings;
}

typedef BackupDirectoryProvider = Future<Directory> Function();
typedef DocumentNumberConflictResolver =
    String Function(String originalDocumentNumber);

class BackupService {
  BackupService({
    BackupDirectoryProvider? documentsDirectoryProvider,
    String exportFolderName = 'exports',
    String importFolderName = 'imports',
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _exportFolderName = exportFolderName,
       _importFolderName = importFolderName;

  final BackupDirectoryProvider _documentsDirectoryProvider;
  final String _exportFolderName;
  final String _importFolderName;
  final Uuid _uuid = const Uuid();

  Future<BackupExportResult> exportInspection({
    required InspectionBackupData data,
    String? archiveFileName,
  }) async {
    final rootDirectory = await _buildExportDirectory();
    final fileName =
        archiveFileName ??
        '${UndergroundTemplate.exportFilePrefix}_${_safeFileStem(data.documentNumber)}_${UndergroundTemplate.exportFileSuffix}.zip';
    final archiveFile = File(p.join(rootDirectory.path, fileName));
    final archive = Archive();
    final warnings = <String>[];
    var exportedFileCount = 0;

    final inspectionJson = _withTemplateMetadata(data.inspectionJson);
    _addJsonEntry(archive, 'inspection.json', inspectionJson);
    exportedFileCount++;

    for (final photo in data.photoFiles) {
      if (!await photo.exists()) {
        warnings.add('Missing photo file skipped during export: ${photo.path}');
        continue;
      }
      final bytes = await photo.readAsBytes();
      archive.addFile(
        ArchiveFile(
          p.posix.join('photos', p.basename(photo.path)),
          bytes.length,
          bytes,
        ),
      );
      exportedFileCount++;
    }

    if (data.generatedPdfFile case final File pdfFile) {
      if (await pdfFile.exists()) {
        final bytes = await pdfFile.readAsBytes();
        archive.addFile(
          ArchiveFile(
            p.posix.join('generated_pdf', p.basename(pdfFile.path)),
            bytes.length,
            bytes,
          ),
        );
        exportedFileCount++;
      } else {
        warnings.add(
          'Generated PDF file skipped because it does not exist: ${pdfFile.path}',
        );
      }
    }

    final manifest = <String, dynamic>{
      'id': _uuid.v4(),
      'documentNumber': data.documentNumber,
      'customer': data.customer,
      'workOrderNumber': data.workOrderNumber,
      'appName': UndergroundTemplate.appName,
      'templateKey': UndergroundTemplate.templateKey,
      'templateVersion': UndergroundTemplate.templateVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'warnings': warnings,
    };
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );
    exportedFileCount++;

    final encoded = ZipEncoder().encode(archive);
    await archiveFile.writeAsBytes(encoded, flush: true);
    return BackupExportResult(
      archiveFile: archiveFile,
      warnings: warnings,
      exportedFileCount: exportedFileCount,
    );
  }

  Future<BackupImportResult> importInspection({
    required File archiveFile,
    Set<String> existingDocumentNumbers = const <String>{},
    DocumentNumberConflictResolver? conflictResolver,
  }) async {
    if (!await archiveFile.exists()) {
      throw BackupServiceException(
        'Archive file does not exist: ${archiveFile.path}',
        code: BackupServiceErrorCode.io,
      );
    }

    final archiveBytes = await archiveFile.readAsBytes();
    _validateZipCentralDirectory(archiveBytes);
    final decoded = ZipDecoder().decodeBytes(archiveBytes, verify: true);
    final importRoot = await _buildImportDirectory();
    final restoreFolder = Directory(
      p.join(
        importRoot.path,
        _safeFileStem(
          'import_${DateTime.now().toUtc().millisecondsSinceEpoch}_${_uuid.v4()}',
        ),
      ),
    );
    await restoreFolder.create(recursive: true);

    final archiveFiles = decoded.where((file) => file.isFile).toList();
    final validatedEntryNames = <ArchiveFile, String>{};
    var inspectionJsonCount = 0;
    for (final file in archiveFiles) {
      final entryName = _validatedArchiveEntryName(file.name);
      if (entryName == 'inspection.json') {
        inspectionJsonCount++;
      }
      validatedEntryNames[file] = entryName;
    }
    if (inspectionJsonCount != 1) {
      throw BackupServiceException(
        inspectionJsonCount == 0
            ? 'Archive did not contain inspection.json.'
            : 'Archive contained more than one inspection.json.',
        code: inspectionJsonCount == 0
            ? BackupServiceErrorCode.json
            : BackupServiceErrorCode.archive,
      );
    }

    Map<String, dynamic>? inspectionJson;
    final restoredPhotos = <File>[];
    File? restoredPdf;
    final warnings = <String>[];

    for (final file in archiveFiles) {
      final entryName = validatedEntryNames[file]!;
      final outputFile = _restoreFileForEntry(restoreFolder, entryName);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(file.content as List<int>, flush: true);

      if (entryName == 'inspection.json') {
        inspectionJson = _decodeInspectionJsonBytes(file.content as List<int>);
      } else if (entryName.startsWith('photos/')) {
        restoredPhotos.add(outputFile);
      } else if (entryName.startsWith('generated_pdf/')) {
        restoredPdf = outputFile;
      }
    }

    final importedInspectionJson = inspectionJson;
    if (importedInspectionJson == null) {
      throw BackupServiceException(
        'Archive did not contain inspection.json.',
        code: BackupServiceErrorCode.json,
      );
    }

    final originalDocumentNumber =
        importedInspectionJson['documentNumber']?.toString().trim() ?? '';
    if (originalDocumentNumber.isEmpty) {
      throw BackupServiceException(
        'Imported inspection is missing a document number.',
        code: BackupServiceErrorCode.json,
      );
    }

    importedInspectionJson
      ..putIfAbsent('templateKey', () => UndergroundTemplate.templateKey)
      ..putIfAbsent(
        'templateVersion',
        () => UndergroundTemplate.templateVersion,
      )
      ..putIfAbsent('appName', () => UndergroundTemplate.appName)
      ..['restoredFromExportPath'] = archiveFile.path;

    var documentNumber = originalDocumentNumber;
    var documentNumberChanged = false;
    if (existingDocumentNumbers.contains(originalDocumentNumber)) {
      documentNumber =
          conflictResolver?.call(originalDocumentNumber) ??
          _generateImportedDocumentNumber(originalDocumentNumber);
      importedInspectionJson['documentNumber'] = documentNumber;
      importedInspectionJson['originalDocumentNumber'] = originalDocumentNumber;
      documentNumberChanged = true;
      warnings.add(
        'Document number conflict resolved by importing as $documentNumber.',
      );
    }

    return BackupImportResult(
      inspectionJson: importedInspectionJson,
      restoredPhotoFiles: restoredPhotos,
      restoredPdfFile: restoredPdf,
      documentNumber: documentNumber,
      documentNumberChanged: documentNumberChanged,
      warnings: warnings,
    );
  }

  Future<Directory> _buildExportDirectory() async {
    final documents = await _documentsDirectoryProvider();
    final directory = Directory(p.join(documents.path, _exportFolderName));
    await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> _buildImportDirectory() async {
    final documents = await _documentsDirectoryProvider();
    final directory = Directory(p.join(documents.path, _importFolderName));
    await directory.create(recursive: true);
    return directory;
  }

  void _addJsonEntry(Archive archive, String name, Map<String, dynamic> json) {
    final bytes = utf8.encode(jsonEncode(json));
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  Map<String, dynamic> _withTemplateMetadata(Map<String, dynamic> json) {
    return <String, dynamic>{
      ...json,
      'templateKey': json['templateKey'] ?? UndergroundTemplate.templateKey,
      'templateVersion':
          json['templateVersion'] ?? UndergroundTemplate.templateVersion,
      'appName': json['appName'] ?? UndergroundTemplate.appName,
    };
  }

  String _validatedArchiveEntryName(String rawName) {
    final normalizedSeparators = rawName.replaceAll('\\', '/');
    final segments = normalizedSeparators.split('/');
    final isWindowsAbsolute = RegExp(
      r'^[A-Za-z]:/',
    ).hasMatch(normalizedSeparators);

    if (normalizedSeparators.trim().isEmpty ||
        p.posix.isAbsolute(normalizedSeparators) ||
        isWindowsAbsolute ||
        segments.any(
          (segment) => segment.isEmpty || segment == '.' || segment == '..',
        )) {
      throw BackupServiceException(
        'Archive contains an unsafe entry path: $rawName',
        code: BackupServiceErrorCode.archive,
      );
    }

    final normalized = p.posix.normalize(normalizedSeparators);
    final isAllowed =
        normalized == 'inspection.json' ||
        normalized == 'manifest.json' ||
        (normalized.startsWith('photos/') &&
            normalized.length > 'photos/'.length) ||
        (normalized.startsWith('generated_pdf/') &&
            normalized.length > 'generated_pdf/'.length);
    if (!isAllowed) {
      throw BackupServiceException(
        'Archive contains an unsupported entry: $rawName',
        code: BackupServiceErrorCode.archive,
      );
    }

    return normalized;
  }

  File _restoreFileForEntry(Directory restoreFolder, String entryName) {
    final outputPath = p.joinAll(<String>[
      restoreFolder.path,
      ...entryName.split('/'),
    ]);
    final rootPath = p.canonicalize(restoreFolder.path);
    final candidatePath = p.canonicalize(outputPath);
    if (!p.equals(rootPath, candidatePath) &&
        !p.isWithin(rootPath, candidatePath)) {
      throw BackupServiceException(
        'Archive entry would restore outside the import folder: $entryName',
        code: BackupServiceErrorCode.archive,
      );
    }
    return File(outputPath);
  }

  void _validateZipCentralDirectory(List<int> archiveBytes) {
    final endOfCentralDirectory = _findEndOfCentralDirectory(archiveBytes);
    if (endOfCentralDirectory == -1) {
      throw BackupServiceException(
        'Archive did not contain a valid ZIP directory.',
        code: BackupServiceErrorCode.archive,
      );
    }

    final entryCount = _readUint16(archiveBytes, endOfCentralDirectory + 10);
    final centralDirectoryOffset = _readUint32(
      archiveBytes,
      endOfCentralDirectory + 16,
    );
    var cursor = centralDirectoryOffset;
    final seenEntryNames = <String>{};

    for (var index = 0; index < entryCount; index++) {
      if (cursor + 46 > archiveBytes.length ||
          _readUint32(archiveBytes, cursor) != 0x02014b50) {
        throw BackupServiceException(
          'Archive central directory was malformed.',
          code: BackupServiceErrorCode.archive,
        );
      }

      final nameLength = _readUint16(archiveBytes, cursor + 28);
      final extraLength = _readUint16(archiveBytes, cursor + 30);
      final commentLength = _readUint16(archiveBytes, cursor + 32);
      final nameStart = cursor + 46;
      final nameEnd = nameStart + nameLength;
      if (nameEnd > archiveBytes.length) {
        throw BackupServiceException(
          'Archive central directory entry was truncated.',
          code: BackupServiceErrorCode.archive,
        );
      }

      final rawName = utf8.decode(archiveBytes.sublist(nameStart, nameEnd));
      if (!rawName.endsWith('/')) {
        final entryName = _validatedArchiveEntryName(rawName);
        if (!seenEntryNames.add(entryName)) {
          throw BackupServiceException(
            'Archive contains duplicate entry: $rawName',
            code: BackupServiceErrorCode.archive,
          );
        }
      }

      cursor = nameEnd + extraLength + commentLength;
    }
  }

  int _findEndOfCentralDirectory(List<int> bytes) {
    final minimumOffset = bytes.length > 66000 ? bytes.length - 66000 : 0;
    for (var index = bytes.length - 22; index >= minimumOffset; index--) {
      if (_readUint32(bytes, index) == 0x06054b50) {
        return index;
      }
    }
    return -1;
  }

  int _readUint16(List<int> bytes, int offset) {
    if (offset < 0 || offset + 2 > bytes.length) {
      throw BackupServiceException(
        'Archive ended unexpectedly.',
        code: BackupServiceErrorCode.archive,
      );
    }
    return bytes[offset] | (bytes[offset + 1] << 8);
  }

  int _readUint32(List<int> bytes, int offset) {
    if (offset < 0 || offset + 4 > bytes.length) {
      throw BackupServiceException(
        'Archive ended unexpectedly.',
        code: BackupServiceErrorCode.archive,
      );
    }
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  Map<String, dynamic> _decodeInspectionJsonBytes(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      // Fall through to error below.
    }
    throw BackupServiceException(
      'inspection.json was not valid JSON.',
      code: BackupServiceErrorCode.json,
    );
  }

  String _generateImportedDocumentNumber(String originalDocumentNumber) {
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    return '${_safeFileStem(originalDocumentNumber)}_imported_$stamp';
  }

  String _safeFileStem(String input) {
    final cleaned = input
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? 'inspection' : cleaned;
  }
}
