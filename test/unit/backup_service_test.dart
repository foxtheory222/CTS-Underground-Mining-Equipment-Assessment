import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cts_underground_mining_assessment/core/underground_template.dart';
import 'package:cts_underground_mining_assessment/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Backup service exports and imports inspection archives', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'backup_service_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final photoFile = await _writePhoto(tempDir, 'photo.jpg');
    final pdfFile = await _writePdf(tempDir, 'report.pdf');
    final service = BackupService(
      documentsDirectoryProvider: () async => tempDir,
    );
    final exportResult = await service.exportInspection(
      data: InspectionBackupData(
        inspectionJson: <String, dynamic>{
          'documentNumber': '20260420-0001',
          'customer': 'CTS',
          'workOrderNumber': 'WO-1001',
        },
        documentNumber: '20260420-0001',
        customer: 'CTS',
        workOrderNumber: 'WO-1001',
        photoFiles: <File>[photoFile],
        generatedPdfFile: pdfFile,
      ),
    );

    expect(await exportResult.archiveFile.exists(), isTrue);
    expect(await exportResult.archiveFile.length(), greaterThan(0));
    expect(
      p.basename(exportResult.archiveFile.path),
      'CTS_InspectionBundle_20260420-0001_UMEA.zip',
    );
    final manifest = await _readArchiveJson(
      exportResult.archiveFile,
      'manifest.json',
    );
    expect(manifest['templateKey'], UndergroundTemplate.templateKey);
    expect(manifest['templateVersion'], UndergroundTemplate.templateVersion);
    expect(manifest['appName'], UndergroundTemplate.appName);

    final importResult = await service.importInspection(
      archiveFile: exportResult.archiveFile,
      existingDocumentNumbers: const <String>{'20260420-0001'},
    );

    expect(importResult.documentNumberChanged, isTrue);
    expect(
      importResult.inspectionJson['documentNumber'],
      isNot('20260420-0001'),
    );
    expect(
      importResult.inspectionJson['templateKey'],
      UndergroundTemplate.templateKey,
    );
    expect(
      importResult.inspectionJson['templateVersion'],
      UndergroundTemplate.templateVersion,
    );
    expect(
      importResult.inspectionJson['originalDocumentNumber'],
      '20260420-0001',
    );
    expect(
      importResult.inspectionJson['restoredFromExportPath'],
      exportResult.archiveFile.path,
    );
    expect(importResult.restoredPhotoFiles, isNotEmpty);
    expect(importResult.restoredPdfFile, isNotNull);
  });

  test(
    'Backup service preserves document number when there is no conflict',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'backup_service_no_conflict_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final pdfFile = await _writePdf(tempDir, 'report.pdf');
      final service = BackupService(
        documentsDirectoryProvider: () async => tempDir,
      );
      final exportResult = await service.exportInspection(
        data: InspectionBackupData(
          inspectionJson: <String, dynamic>{
            'documentNumber': '20260420-0002',
            'customer': 'CTS',
            'workOrderNumber': 'WO-1002',
          },
          documentNumber: '20260420-0002',
          customer: 'CTS',
          workOrderNumber: 'WO-1002',
          generatedPdfFile: pdfFile,
        ),
      );

      final importResult = await service.importInspection(
        archiveFile: exportResult.archiveFile,
        existingDocumentNumbers: const <String>{'20260420-9999'},
      );

      expect(importResult.documentNumber, '20260420-0002');
      expect(importResult.documentNumberChanged, isFalse);
    },
  );

  test('Backup service rejects parent traversal archive entries', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'backup_service_traversal_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final archiveFile = await _writeArchive(
      tempDir,
      'malicious.zip',
      <MapEntry<String, List<int>>>[
        MapEntry<String, List<int>>(
          'inspection.json',
          _jsonBytes(<String, dynamic>{'documentNumber': '20260420-0003'}),
        ),
        MapEntry<String, List<int>>('../evil.txt', utf8.encode('owned')),
        MapEntry<String, List<int>>(
          'photos/../../evil-photo.txt',
          utf8.encode('owned'),
        ),
      ],
    );
    final service = BackupService(
      documentsDirectoryProvider: () async => tempDir,
    );

    await expectLater(
      () => service.importInspection(archiveFile: archiveFile),
      throwsA(
        isA<BackupServiceException>().having(
          (BackupServiceException error) => error.code,
          'code',
          BackupServiceErrorCode.archive,
        ),
      ),
    );
    expect(
      await File(p.join(tempDir.path, 'imports', 'evil.txt')).exists(),
      isFalse,
    );
    expect(
      await File(p.join(tempDir.path, 'imports', 'evil-photo.txt')).exists(),
      isFalse,
    );
  });

  test('Backup service rejects absolute archive entries', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'backup_service_absolute_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final escapedFile = File(p.join(tempDir.path, 'absolute_escape.txt'));
    final archiveFile = await _writeArchive(
      tempDir,
      'absolute.zip',
      <MapEntry<String, List<int>>>[
        MapEntry<String, List<int>>(
          'inspection.json',
          _jsonBytes(<String, dynamic>{'documentNumber': '20260420-0004'}),
        ),
        MapEntry<String, List<int>>(escapedFile.path, utf8.encode('owned')),
      ],
    );
    final service = BackupService(
      documentsDirectoryProvider: () async => tempDir,
    );

    await expectLater(
      () => service.importInspection(archiveFile: archiveFile),
      throwsA(
        isA<BackupServiceException>().having(
          (BackupServiceException error) => error.code,
          'code',
          BackupServiceErrorCode.archive,
        ),
      ),
    );
    expect(await escapedFile.exists(), isFalse);
  });

  test('Backup service rejects duplicate inspection payloads', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'backup_service_duplicate_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final archiveFile = await _writeArchiveWithDuplicateInspectionJson(
      tempDir,
      'duplicate.zip',
    );
    final service = BackupService(
      documentsDirectoryProvider: () async => tempDir,
    );

    await expectLater(
      () => service.importInspection(archiveFile: archiveFile),
      throwsA(
        isA<BackupServiceException>().having(
          (BackupServiceException error) => error.code,
          'code',
          BackupServiceErrorCode.archive,
        ),
      ),
    );
  });

  test('Backup service rejects unsupported archive entries', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'backup_service_unknown_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final archiveFile = await _writeArchive(
      tempDir,
      'unknown.zip',
      <MapEntry<String, List<int>>>[
        MapEntry<String, List<int>>(
          'inspection.json',
          _jsonBytes(<String, dynamic>{'documentNumber': '20260420-0006'}),
        ),
        MapEntry<String, List<int>>('notes.txt', utf8.encode('unexpected')),
      ],
    );
    final service = BackupService(
      documentsDirectoryProvider: () async => tempDir,
    );

    await expectLater(
      () => service.importInspection(archiveFile: archiveFile),
      throwsA(
        isA<BackupServiceException>().having(
          (BackupServiceException error) => error.code,
          'code',
          BackupServiceErrorCode.archive,
        ),
      ),
    );
  });

  test('Backup service restores nested valid photo entries', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'backup_service_nested_photo_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final archiveFile = await _writeArchive(
      tempDir,
      'nested.zip',
      <MapEntry<String, List<int>>>[
        MapEntry<String, List<int>>(
          'inspection.json',
          _jsonBytes(<String, dynamic>{'documentNumber': '20260420-0007'}),
        ),
        MapEntry<String, List<int>>(
          'photos/front/serial.jpg',
          await _writePhoto(
            tempDir,
            'nested_source.jpg',
          ).then((File file) => file.readAsBytes()),
        ),
      ],
    );
    final service = BackupService(
      documentsDirectoryProvider: () async => tempDir,
    );

    final importResult = await service.importInspection(
      archiveFile: archiveFile,
    );

    expect(importResult.restoredPhotoFiles, hasLength(1));
    expect(
      importResult.restoredPhotoFiles.single.path,
      contains(p.join('photos', 'front', 'serial.jpg')),
    );
    expect(await importResult.restoredPhotoFiles.single.exists(), isTrue);
  });
}

Future<File> _writePhoto(Directory directory, String fileName) async {
  final image = img.Image(width: 60, height: 40);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgba(x, y, 200, 40 + x, 40 + y, 255);
    }
  }
  final file = File(p.join(directory.path, fileName));
  await file.writeAsBytes(
    Uint8List.fromList(img.encodeJpg(image, quality: 90)),
  );
  return file;
}

Future<File> _writePdf(Directory directory, String fileName) async {
  final file = File(p.join(directory.path, fileName));
  await file.writeAsBytes(
    Uint8List.fromList(List<int>.generate(72, (index) => (index * 3) % 255)),
  );
  return file;
}

Future<File> _writeArchive(
  Directory directory,
  String fileName,
  List<MapEntry<String, List<int>>> entries,
) async {
  final archive = Archive();
  for (final entry in entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  final archiveFile = File(p.join(directory.path, fileName));
  await archiveFile.writeAsBytes(ZipEncoder().encode(archive), flush: true);
  return archiveFile;
}

Future<File> _writeArchiveWithDuplicateInspectionJson(
  Directory directory,
  String fileName,
) async {
  final archiveBytes = _buildStoredZip(<MapEntry<String, List<int>>>[
    MapEntry<String, List<int>>(
      'inspection.json',
      _jsonBytes(<String, dynamic>{'documentNumber': '20260420-0005'}),
    ),
    MapEntry<String, List<int>>(
      'inspection.json',
      _jsonBytes(<String, dynamic>{'documentNumber': '20260420-9999'}),
    ),
  ]);
  final archiveFile = File(p.join(directory.path, fileName));
  await archiveFile.writeAsBytes(archiveBytes, flush: true);
  return archiveFile;
}

List<int> _jsonBytes(Map<String, dynamic> json) {
  return utf8.encode(jsonEncode(json));
}

List<int> _buildStoredZip(List<MapEntry<String, List<int>>> entries) {
  final output = BytesBuilder();
  final centralDirectory = BytesBuilder();
  var offset = 0;

  for (final entry in entries) {
    final entryOffset = offset;
    final nameBytes = utf8.encode(entry.key);
    final data = entry.value;
    final crc = _crc32(data);

    _writeUint32(output, 0x04034b50);
    _writeUint16(output, 20);
    _writeUint16(output, 0);
    _writeUint16(output, 0);
    _writeUint16(output, 0);
    _writeUint16(output, 0);
    _writeUint32(output, crc);
    _writeUint32(output, data.length);
    _writeUint32(output, data.length);
    _writeUint16(output, nameBytes.length);
    _writeUint16(output, 0);
    output.add(nameBytes);
    output.add(data);
    offset += 30 + nameBytes.length + data.length;

    _writeUint32(centralDirectory, 0x02014b50);
    _writeUint16(centralDirectory, 20);
    _writeUint16(centralDirectory, 20);
    _writeUint16(centralDirectory, 0);
    _writeUint16(centralDirectory, 0);
    _writeUint16(centralDirectory, 0);
    _writeUint16(centralDirectory, 0);
    _writeUint32(centralDirectory, crc);
    _writeUint32(centralDirectory, data.length);
    _writeUint32(centralDirectory, data.length);
    _writeUint16(centralDirectory, nameBytes.length);
    _writeUint16(centralDirectory, 0);
    _writeUint16(centralDirectory, 0);
    _writeUint16(centralDirectory, 0);
    _writeUint16(centralDirectory, 0);
    _writeUint32(centralDirectory, 0);
    _writeUint32(centralDirectory, entryOffset);
    centralDirectory.add(nameBytes);
  }

  final centralDirectoryBytes = centralDirectory.toBytes();
  output.add(centralDirectoryBytes);
  _writeUint32(output, 0x06054b50);
  _writeUint16(output, 0);
  _writeUint16(output, 0);
  _writeUint16(output, entries.length);
  _writeUint16(output, entries.length);
  _writeUint32(output, centralDirectoryBytes.length);
  _writeUint32(output, offset);
  _writeUint16(output, 0);
  return output.toBytes();
}

void _writeUint16(BytesBuilder builder, int value) {
  final data = ByteData(2)..setUint16(0, value, Endian.little);
  builder.add(data.buffer.asUint8List());
}

void _writeUint32(BytesBuilder builder, int value) {
  final data = ByteData(4)..setUint32(0, value & 0xffffffff, Endian.little);
  builder.add(data.buffer.asUint8List());
}

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 1 ? 0xedb88320 ^ (crc >> 1) : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

Future<Map<String, dynamic>> _readArchiveJson(
  File archiveFile,
  String name,
) async {
  final archive = ZipDecoder().decodeBytes(await archiveFile.readAsBytes());
  final entry = archive.files.singleWhere((file) => file.name == name);
  return jsonDecode(utf8.decode(entry.content as List<int>))
      as Map<String, dynamic>;
}
