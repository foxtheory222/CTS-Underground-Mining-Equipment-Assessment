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

Future<Map<String, dynamic>> _readArchiveJson(
  File archiveFile,
  String name,
) async {
  final archive = ZipDecoder().decodeBytes(await archiveFile.readAsBytes());
  final entry = archive.files.singleWhere((file) => file.name == name);
  return jsonDecode(utf8.decode(entry.content as List<int>))
      as Map<String, dynamic>;
}
