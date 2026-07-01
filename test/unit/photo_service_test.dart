import 'dart:io';

import 'package:cts_underground_mining_assessment/services/photo_service.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

class _MemoryAssetBundle extends CachingAssetBundle {
  _MemoryAssetBundle(this.assets);

  final Map<String, Uint8List> assets;

  @override
  Future<ByteData> load(String key) async {
    final bytes = assets[key];
    if (bytes == null) {
      throw FlutterError('Missing asset: $key');
    }
    return ByteData.sublistView(bytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'PhotoService saves camera, gallery, and sample photos locally',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'photo_service_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final cameraFile = await _writeTestImage(tempDir.path, 'camera.jpg');
      final galleryFile = await _writeTestImage(tempDir.path, 'gallery.jpg');
      final picker = FakeInspectionPhotoPicker(
        cameraPhoto: XFile(cameraFile.path),
        galleryPhotos: <XFile>[XFile(galleryFile.path)],
      );
      final bundle = _MemoryAssetBundle(<String, Uint8List>{
        'assets/demo/sample_photo_1.jpg': await File(
          cameraFile.path,
        ).readAsBytes(),
      });

      final service = PhotoService(
        photoPicker: picker,
        documentsDirectoryProvider: () async => tempDir,
        assetBundle: bundle,
        maxPhotosPerItem: 10,
      );

      final cameraPhoto = await service.captureFromCamera(
        inspectionId: 'inspection-1',
        sectionKey: 'job_asset_identification',
        itemKey: 'hpu_wide_shot',
        currentPhotoCount: 0,
        caption: 'Camera capture',
        sortOrder: 0,
      );
      expect(cameraPhoto, isNotNull);
      expect(await File(cameraPhoto!.filePath).exists(), isTrue);

      final galleryResult = await service.addFromGallery(
        inspectionId: 'inspection-1',
        sectionKey: 'job_asset_identification',
        itemKey: 'hpu_wide_shot',
        currentPhotoCount: 1,
        captionPrefix: 'Gallery',
        startingSortOrder: 1,
      );
      expect(galleryResult.savedPhotos, hasLength(1));
      expect(galleryResult.truncated, isFalse);

      final samplePhoto = await service.addSampleAssetPhoto(
        inspectionId: 'inspection-1',
        sectionKey: 'job_asset_identification',
        itemKey: 'hpu_wide_shot',
        assetPath: 'assets/demo/sample_photo_1.jpg',
        currentPhotoCount: 2,
        caption: 'Sample asset',
        sortOrder: 2,
      );
      expect(await File(samplePhoto.filePath).exists(), isTrue);

      final directory = await service.resolveInspectionPhotoDirectory(
        inspectionId: 'inspection-1',
        sectionKey: 'job_asset_identification',
        itemKey: 'hpu_wide_shot',
      );
      expect(
        directory.path,
        contains(p.join('inspections', 'inspection-1', 'photos')),
      );
    },
  );

  test('PhotoService enforces max photos per item', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'photo_service_limit_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final cameraFile = await _writeTestImage(tempDir.path, 'camera.jpg');
    final picker = FakeInspectionPhotoPicker(
      cameraPhoto: XFile(cameraFile.path),
    );
    final service = PhotoService(
      photoPicker: picker,
      documentsDirectoryProvider: () async => tempDir,
      maxPhotosPerItem: 1,
    );

    await service.captureFromCamera(
      inspectionId: 'inspection-1',
      sectionKey: 'section',
      itemKey: 'item',
      currentPhotoCount: 0,
    );

    expect(
      () => service.captureFromCamera(
        inspectionId: 'inspection-1',
        sectionKey: 'section',
        itemKey: 'item',
        currentPhotoCount: 1,
      ),
      throwsA(isA<PhotoServiceException>()),
    );
  });

  test('PhotoService uses jpg extension for recompressed PNG inputs', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'photo_service_png_extension_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final galleryFile = await _writeTestImage(
      tempDir.path,
      'gallery.png',
      format: _TestImageFormat.png,
    );
    final picker = FakeInspectionPhotoPicker(
      galleryPhotos: <XFile>[XFile(galleryFile.path)],
    );
    final service = PhotoService(
      photoPicker: picker,
      documentsDirectoryProvider: () async => tempDir,
      maxPhotosPerItem: 5,
    );

    final result = await service.addFromGallery(
      inspectionId: 'inspection-1',
      sectionKey: 'section',
      itemKey: 'item',
      currentPhotoCount: 0,
    );

    final savedPhoto = result.savedPhotos.single;
    expect(savedPhoto.originalFileName, 'gallery.png');
    expect(p.extension(savedPhoto.filePath).toLowerCase(), '.jpg');
    final savedBytes = await File(savedPhoto.filePath).readAsBytes();
    expect(savedBytes.take(2), <int>[0xff, 0xd8]);
  });
}

enum _TestImageFormat { jpg, png }

Future<File> _writeTestImage(
  String directory,
  String fileName, {
  _TestImageFormat format = _TestImageFormat.jpg,
}) async {
  final image = img.Image(width: 48, height: 48);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgba(x, y, 30 + x, 80 + y, 120, 255);
    }
  }
  final file = File(p.join(directory, fileName));
  final encoded = switch (format) {
    _TestImageFormat.jpg => img.encodeJpg(image, quality: 90),
    _TestImageFormat.png => img.encodePng(image),
  };
  await file.writeAsBytes(Uint8List.fromList(encoded));
  return file;
}
