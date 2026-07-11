import 'package:cts_underground_mining_assessment/data/models/inspection_enums.dart';
import 'package:cts_underground_mining_assessment/data/models/inspection_models.dart';
import 'package:cts_underground_mining_assessment/core/validators.dart';
import 'package:cts_underground_mining_assessment/services/inspection_report_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/persistence_test_helpers.dart';

void main() {
  test('maps customer signature separately from technician signature', () {
    final inspection = buildInspection(
      id: 'signed-underground',
      documentNumber: '20260701-0001',
      status: InspectionStatus.complete,
      customer: 'Moraine Mine',
      signatureFilePath: '/tmp/technician-signature.png',
    );
    inspection.customerSignatureFilePath = '/tmp/customer-signature.png';
    final representativeKey = InspectionValidator.templateItemKey(
      'final_recommendation_signoff',
      'Customer Representative Name',
    );
    inspection.responses.add(
      InspectionResponse(
        id: 'customer-representative',
        inspectionId: inspection.id,
        sectionKey: 'final_recommendation_signoff',
        itemKey: representativeKey,
        itemLabel: 'Customer Representative Name',
        fieldType: InspectionFieldType.text,
        value: 'Taylor Morgan',
        createdAt: inspection.createdAt,
        updatedAt: inspection.updatedAt,
      ),
    );

    final report = inspectionRecordToReportData(inspection);

    expect(report.signature?.filePath, '/tmp/technician-signature.png');
    expect(report.customerSignature?.filePath, '/tmp/customer-signature.png');
    expect(report.customerSignature?.signerName, 'Taylor Morgan');
  });

  test('maps explicitly flagged unrated responses as flagged report items', () {
    final now = DateTime.utc(2026, 7, 9, 9);
    final inspection = buildInspection(
      id: 'flagged-unrated-underground',
      documentNumber: '20260709-0001',
      status: InspectionStatus.inProgress,
      responses: <InspectionResponse>[
        InspectionResponse(
          id: 'not-inspected',
          inspectionId: 'flagged-unrated-underground',
          sectionKey: 'structural_inspection',
          itemKey: 'structural_inspection_main_frame',
          itemLabel: 'Main Frame',
          fieldType: InspectionFieldType.conditionRating,
          value: 'Not Inspected',
          isFlagged: true,
          comment: 'Blocked by guarding.',
          createdAt: now,
          updatedAt: now,
        ),
        InspectionResponse(
          id: 'not-applicable',
          inspectionId: 'flagged-unrated-underground',
          sectionKey: 'structural_inspection',
          itemKey: 'structural_inspection_articulation_area',
          itemLabel: 'Articulation Area',
          fieldType: InspectionFieldType.conditionRating,
          value: 'N/A',
          isFlagged: true,
          comment: 'Machine configuration does not include this area.',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    final report = inspectionRecordToReportData(inspection);

    expect(report.flaggedItemCount, 2);
    expect(
      report.flaggedItems.map((item) => item.value),
      containsAll(<String>['Not Inspected', 'N/A']),
    );
  });
}
