import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'constants.dart';
import 'underground_template.dart';

class FileUtils {
  static Future<Directory> appRootDirectory() async {
    final Directory documentsDir = await getApplicationDocumentsDirectory();
    final Directory root = Directory(
      p.join(documentsDir.path, AppConstants.databaseFolderName),
    );
    if (!root.existsSync()) {
      root.createSync(recursive: true);
    }
    return root;
  }

  static Future<Directory> inspectionsRootDirectory() async {
    final Directory root = await appRootDirectory();
    final Directory directory = Directory(
      p.join(root.path, AppConstants.inspectionsFolderName),
    );
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  static Future<Directory> reportsRootDirectory() async {
    final Directory root = await appRootDirectory();
    final Directory directory = Directory(
      p.join(root.path, AppConstants.reportsFolderName),
    );
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  static Future<Directory> exportsRootDirectory() async {
    final Directory root = await appRootDirectory();
    final Directory directory = Directory(
      p.join(root.path, AppConstants.exportsFolderName),
    );
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  static Future<Directory> importsRootDirectory() async {
    final Directory root = await appRootDirectory();
    final Directory directory = Directory(
      p.join(root.path, AppConstants.importsFolderName),
    );
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  static Future<Directory> inspectionDirectory(String inspectionId) async {
    final Directory root = await inspectionsRootDirectory();
    final Directory directory = Directory(p.join(root.path, inspectionId));
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  static Future<Directory> inspectionPhotosDirectory(
    String inspectionId,
  ) async {
    final Directory directory = Directory(
      p.join((await inspectionDirectory(inspectionId)).path, 'photos'),
    );
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  static Future<Directory> inspectionReportsDirectory(
    String inspectionId,
  ) async {
    final Directory directory = Directory(
      p.join((await inspectionDirectory(inspectionId)).path, 'reports'),
    );
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  static Future<File> writeAssetToInspection(
    String inspectionId,
    String assetPath,
    String fileName,
  ) async {
    final ByteData assetData = await rootBundle.load(assetPath);
    final File file = File(
      p.join((await inspectionPhotosDirectory(inspectionId)).path, fileName),
    );
    await file.writeAsBytes(assetData.buffer.asUint8List(), flush: true);
    return file;
  }

  static String sanitizeFileSegment(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'unknown';
    }
    final String sanitized = trimmed.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]+'),
      '_',
    );
    final String compacted = sanitized
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return compacted.isEmpty ? 'unknown' : compacted;
  }

  static String buildPdfFileName({
    required String documentNumber,
    required String customer,
    required String machineOrSerial,
    required DateTime inspectionDate,
  }) {
    final String safeCustomer = sanitizeFileSegment(customer);
    final String safeMachineOrSerial = sanitizeFileSegment(machineOrSerial);
    final String safeDocumentNumber = sanitizeFileSegment(documentNumber);
    return '${UndergroundTemplate.reportFilePrefix}_${safeCustomer}_'
        '${safeMachineOrSerial}_${_formatFileDate(inspectionDate)}_'
        '$safeDocumentNumber.pdf';
  }

  static String _formatFileDate(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }
}
