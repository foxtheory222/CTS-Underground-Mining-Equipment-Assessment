import 'package:cts_underground_mining_assessment/core/constants.dart';
import 'package:cts_underground_mining_assessment/core/underground_template.dart';
import 'package:cts_underground_mining_assessment/core/validators.dart';
import 'package:cts_underground_mining_assessment/data/models/inspection_enums.dart';
import 'package:cts_underground_mining_assessment/data/models/inspection_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/persistence_test_helpers.dart';

void main() {
  test(
    'completion requires mining header purpose scores status recommendation and signature',
    () {
      final inspection = buildInspection(
        id: 'inspection-mining-required',
        documentNumber: '20260420-0001',
        status: InspectionStatus.inProgress,
        customer: '',
        mineSite: '',
        machineType: '',
        manufacturer: '',
        model: '',
        serialNumber: '',
        alternateAssetId: '',
        machineHours: '',
        selectedPurposes: const <String>[],
        healthScores: const <String, int>{},
        assetStatus: '',
        finalRecommendation: '',
        signatureFilePath: null,
      );

      final result = InspectionValidator.validateForCompletion(inspection);

      expect(result.isValid, isFalse);
      expect(
        result.issues.map((issue) => issue.message),
        containsAll(<String>[
          'Customer is required.',
          'Mine site is required.',
          'Machine type is required.',
          'Manufacturer is required.',
          'Model is required.',
          'Serial number or alternate asset ID/comment is required.',
          'Machine hours are required.',
          'At least one purpose of inspection is required.',
          'Asset status is required.',
          'Final CTS recommendation is required.',
          'Inspector signature is required.',
        ]),
      );
      for (final scoreField in UndergroundTemplate.healthScoreFields) {
        expect(
          result.issues.map((issue) => issue.message),
          contains('${scoreField.label} score is required.'),
        );
      }
    },
  );

  test('completion requires saved responses for required template items', () {
    final inspection = buildInspection(
      id: 'inspection-mining-complete',
      documentNumber: '20260420-0002',
      status: InspectionStatus.inProgress,
      selectedPurposes: const <String>['Condition Assessment'],
      healthScores: <String, int>{
        for (final scoreField in UndergroundTemplate.healthScoreFields)
          scoreField.key: scoreField.max,
      },
      assetStatus: 'Good',
      finalRecommendation: 'Continue Operating',
      signatureFilePath: '/tmp/signature.png',
    );

    final result = InspectionValidator.validateForCompletion(inspection);

    expect(result.isValid, isFalse);
    expect(
      result.issues.map((issue) => issue.message),
      contains('SECTION 2 - STRUCTURAL INSPECTION requires Main Frame.'),
    );
  });

  test(
    'emailed timestamp does not override missing completion or PDF state',
    () {
      final incomplete = buildInspection(
        id: 'inspection-email-incomplete',
        documentNumber: '20260420-0020',
        status: InspectionStatus.inProgress,
        customer: '',
        emailedAt: DateTime.utc(2026, 4, 20, 13, 0),
      );

      expect(
        InspectionValidator.deriveStatus(incomplete),
        isNot(InspectionStatus.emailed),
      );

      final completeWithoutPdf = buildInspection(
        id: 'inspection-email-without-pdf',
        documentNumber: '20260420-0021',
        status: InspectionStatus.inProgress,
        signatureFilePath: '/tmp/signature.png',
        completedAt: DateTime.utc(2026, 4, 20, 12, 30),
        emailedAt: DateTime.utc(2026, 4, 20, 13, 0),
      );
      fillRequiredResponses(completeWithoutPdf);

      expect(
        InspectionValidator.deriveStatus(completeWithoutPdf),
        InspectionStatus.complete,
      );
    },
  );

  test(
    'global item ratings enforce comment photo action and critical rules',
    () {
      final now = DateTime.utc(2026, 4, 20, 12, 0);
      final inspection = buildInspection(
        id: 'inspection-rating-rules',
        documentNumber: '20260420-0003',
        status: InspectionStatus.inProgress,
        selectedPurposes: const <String>['Rebuild Assessment'],
        healthScores: <String, int>{
          for (final scoreField in UndergroundTemplate.healthScoreFields)
            scoreField.key: 7,
        },
        assetStatus: 'Fair',
        finalRecommendation: 'Monitor Monthly',
        signatureFilePath: '/tmp/signature.png',
        criticalAcknowledged: false,
        responses: <InspectionResponse>[
          InspectionResponse(
            id: 'fair-response',
            inspectionId: 'inspection-rating-rules',
            sectionKey: 'structural_inspection',
            itemKey: 'main_frame',
            itemLabel: 'Main Frame',
            fieldType: InspectionFieldType.dropdown,
            value: 'Fair',
            createdAt: now,
            updatedAt: now,
          ),
          InspectionResponse(
            id: 'poor-response',
            inspectionId: 'inspection-rating-rules',
            sectionKey: 'braking_system',
            itemKey: 'service_brakes',
            itemLabel: 'Service Brakes',
            fieldType: InspectionFieldType.dropdown,
            value: 'Poor',
            comment: 'Low brake response.',
            createdAt: now,
            updatedAt: now,
          ),
          InspectionResponse(
            id: 'critical-response',
            inspectionId: 'inspection-rating-rules',
            sectionKey: 'electrical_system',
            itemKey: 'emergency_shutdown',
            itemLabel: 'Emergency Shutdown',
            fieldType: InspectionFieldType.dropdown,
            value: 'Good',
            conditionRating: ConditionRating.criticalOutOfService,
            comment: 'Failed shutdown test.',
            createdAt: now,
            updatedAt: now,
          ),
        ],
        photos: <InspectionPhoto>[
          InspectionPhoto(
            id: 'critical-photo',
            inspectionId: 'inspection-rating-rules',
            sectionKey: 'electrical_system',
            itemKey: 'emergency_shutdown',
            filePath: '/tmp/critical.jpg',
            caption: 'Failed shutdown',
            sortOrder: 0,
            capturedAt: now,
            createdAt: now,
          ),
        ],
        actionItems: <ActionItem>[
          ActionItem(
            id: 'critical-action',
            inspectionId: 'inspection-rating-rules',
            sourceSectionKey: 'electrical_system',
            sourceItemKey: 'emergency_shutdown',
            conditionRating: ConditionRating.criticalOutOfService,
            title: 'Emergency Shutdown',
            description: 'Failed shutdown test.',
            isAutoGenerated: true,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      final result = InspectionValidator.validateForCompletion(inspection);

      expect(result.isValid, isFalse);
      expect(
        result.issues.map((issue) => issue.message),
        containsAll(<String>[
          'Main Frame requires a comment.',
          'Service Brakes requires at least one photo.',
          'Service Brakes requires a linked action item.',
          AppConstants.lotOWarning,
        ]),
      );
    },
  );

  test('completion passes when required fields and signoff are present', () {
    final inspection = buildInspection(
      id: 'inspection-1',
      documentNumber: '20260420-0001',
      status: InspectionStatus.inProgress,
    );
    fillRequiredResponses(inspection);
    inspection.signatureFilePath = '/tmp/signature.png';
    inspection.completedAt = DateTime.utc(2026, 4, 20, 12, 30);

    final result = InspectionValidator.validateForCompletion(inspection);

    expect(result.isValid, isTrue);
  });

  test('flagged responses require comment photo and action item', () {
    final inspection = buildInspection(
      id: 'inspection-2',
      documentNumber: '20260420-0002',
      status: InspectionStatus.inProgress,
    );
    fillRequiredResponses(inspection);
    inspection.signatureFilePath = '/tmp/signature.png';
    inspection.completedAt = DateTime.utc(2026, 4, 20, 12, 30);
    inspection.responses = inspection.responses
        .map(
          (response) => response.itemKey == InspectionItemKeys.tankIntegrity
              ? InspectionResponse(
                  id: response.id,
                  inspectionId: response.inspectionId,
                  sectionKey: response.sectionKey,
                  itemKey: response.itemKey,
                  itemLabel: response.itemLabel,
                  fieldType: response.fieldType,
                  value: ConditionRating.monitorAtRisk.value,
                  conditionRating: ConditionRating.monitorAtRisk,
                  isFlagged: true,
                  comment: null,
                  createdAt: response.createdAt,
                  updatedAt: response.updatedAt,
                )
              : response,
        )
        .toList(growable: false);

    final result = InspectionValidator.validateForCompletion(inspection);

    expect(result.isValid, isFalse);
    expect(
      result.issues.map((issue) => issue.message),
      contains('Tank Integrity requires a comment.'),
    );
    expect(
      result.issues.map((issue) => issue.message),
      contains('Tank Integrity requires at least one photo.'),
    );
    expect(
      result.issues.map((issue) => issue.message),
      contains('Tank Integrity requires a linked action item.'),
    );
  });

  test('critical responses require LOTO acknowledgement', () {
    final inspection = buildInspection(
      id: 'inspection-3',
      documentNumber: '20260420-0003',
      status: InspectionStatus.inProgress,
    );
    fillRequiredResponses(inspection);
    inspection.signatureFilePath = '/tmp/signature.png';
    inspection.completedAt = DateTime.utc(2026, 4, 20, 12, 30);
    inspection.criticalAcknowledged = false;
    inspection.responses = inspection.responses
        .map(
          (response) => response.itemKey == InspectionItemKeys.tankIntegrity
              ? InspectionResponse(
                  id: response.id,
                  inspectionId: response.inspectionId,
                  sectionKey: response.sectionKey,
                  itemKey: response.itemKey,
                  itemLabel: response.itemLabel,
                  fieldType: response.fieldType,
                  value: ConditionRating.criticalOutOfService.value,
                  conditionRating: ConditionRating.criticalOutOfService,
                  isFlagged: true,
                  comment: 'Severe damage.',
                  createdAt: response.createdAt,
                  updatedAt: response.updatedAt,
                )
              : response,
        )
        .toList(growable: false);
    inspection.photos.add(
      InspectionPhoto(
        id: 'photo-1',
        inspectionId: inspection.id,
        sectionKey: InspectionSectionKeys.fluidTankService,
        itemKey: InspectionItemKeys.tankIntegrity,
        filePath: '/tmp/photo.jpg',
        caption: 'Damage',
        sortOrder: 0,
        capturedAt: DateTime.utc(2026, 4, 20, 12, 0),
        createdAt: DateTime.utc(2026, 4, 20, 12, 0),
      ),
    );
    inspection.actionItems.add(
      ActionItem(
        id: 'action-1',
        inspectionId: inspection.id,
        sourceSectionKey: InspectionSectionKeys.fluidTankService,
        sourceItemKey: InspectionItemKeys.tankIntegrity,
        conditionRating: ConditionRating.criticalOutOfService,
        title: 'Tank Integrity requires attention',
        description: 'Severe damage.',
        isAutoGenerated: true,
        createdAt: DateTime.utc(2026, 4, 20, 12, 0),
        updatedAt: DateTime.utc(2026, 4, 20, 12, 0),
      ),
    );

    final result = InspectionValidator.validateForCompletion(inspection);

    expect(result.isValid, isFalse);
    expect(
      result.issues.map((issue) => issue.message),
      contains(AppConstants.lotOWarning),
    );
  });
}
