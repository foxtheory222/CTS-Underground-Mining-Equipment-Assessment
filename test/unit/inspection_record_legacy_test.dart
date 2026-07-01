import 'package:cts_underground_mining_assessment/data/models/inspection_enums.dart';
import 'package:cts_underground_mining_assessment/data/models/inspection_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inspection JSON uses alternateAssetId and reads legacy asset ids', () {
    final record = InspectionRecord(
      id: 'inspection-1',
      documentNumber: '20260420-0001',
      status: InspectionStatus.draft,
      alternateAssetId: 'ALT-42',
      inspectionDateTime: DateTime.utc(2026, 4, 20, 12),
      createdAt: DateTime.utc(2026, 4, 20, 12),
      updatedAt: DateTime.utc(2026, 4, 20, 12),
    );

    expect(record.toJson(), isNot(contains('hpuAssetIdName')));
    expect(record.toJson()['alternateAssetId'], 'ALT-42');

    final legacy = InspectionRecord.fromJson(<String, dynamic>{
      'id': 'inspection-legacy',
      'documentNumber': '20260420-0002',
      'status': 'draft',
      'assetName': 'Legacy asset',
      'hpuAssetIdName': 'LEGACY-ALT',
      'inspectionDateTime': DateTime.utc(2026, 4, 20, 12).toIso8601String(),
      'createdAt': DateTime.utc(2026, 4, 20, 12).toIso8601String(),
      'updatedAt': DateTime.utc(2026, 4, 20, 12).toIso8601String(),
    });

    expect(legacy.alternateAssetId, 'LEGACY-ALT');
    expect(legacy.toJson(), isNot(contains('hpuAssetIdName')));
  });
}
