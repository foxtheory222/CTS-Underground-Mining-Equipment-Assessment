import '../data/models/inspection_enums.dart';
import '../data/models/inspection_models.dart';
import 'constants.dart';
import 'underground_template.dart';

class ValidationIssue {
  const ValidationIssue({
    required this.sectionKey,
    this.itemKey,
    required this.message,
    this.severity = ValidationSeverity.error,
  });

  final String sectionKey;
  final String? itemKey;
  final String message;
  final ValidationSeverity severity;
}

class ValidationResult {
  const ValidationResult(this.issues);

  final List<ValidationIssue> issues;

  bool get isValid => issues.isEmpty;
}

class InspectionValidator {
  static String templateItemKey(String sectionKey, String itemLabel) {
    final normalizedItem = itemLabel
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return '${sectionKey}_$normalizedItem';
  }

  static ValidationResult validateForCompletion(InspectionRecord inspection) {
    final List<ValidationIssue> issues = <ValidationIssue>[];

    void requireHeader(String value, String message) {
      if (value.trim().isEmpty) {
        issues.add(
          ValidationIssue(
            sectionKey: InspectionSectionKeys.jobAssetIdentification,
            message: message,
          ),
        );
      }
    }

    requireHeader(inspection.customer, 'Customer is required.');
    requireHeader(inspection.mineSite, 'Mine site is required.');
    requireHeader(inspection.machineType, 'Machine type is required.');
    requireHeader(inspection.manufacturer, 'Manufacturer is required.');
    requireHeader(inspection.model, 'Model is required.');
    if (inspection.serialNumber.trim().isEmpty &&
        inspection.alternateAssetId.trim().isEmpty) {
      issues.add(
        const ValidationIssue(
          sectionKey: 'machine_identification',
          message: 'Serial number or alternate asset ID/comment is required.',
        ),
      );
    }
    requireHeader(inspection.machineHours, 'Machine hours are required.');
    requireHeader(inspection.technicianName, 'CTS inspector is required.');
    if (inspection.selectedPurposes.isEmpty) {
      issues.add(
        const ValidationIssue(
          sectionKey: 'machine_identification',
          message: 'At least one purpose of inspection is required.',
        ),
      );
    }
    if (inspection.assetStatus.trim().isEmpty) {
      issues.add(
        const ValidationIssue(
          sectionKey: 'machine_identification',
          message: 'Asset status is required.',
        ),
      );
    }
    if (inspection.finalRecommendation.trim().isEmpty) {
      issues.add(
        const ValidationIssue(
          sectionKey: 'final_recommendation_signoff',
          message: 'Final CTS recommendation is required.',
        ),
      );
    }
    for (final UndergroundHealthScoreField scoreField
        in UndergroundTemplate.healthScoreFields) {
      final int? score = inspection.healthScores[scoreField.key];
      if (score == null) {
        issues.add(
          ValidationIssue(
            sectionKey: 'machine_identification',
            message: '${scoreField.label} score is required.',
          ),
        );
      } else if (score < scoreField.min || score > scoreField.max) {
        issues.add(
          ValidationIssue(
            sectionKey: 'machine_identification',
            message:
                '${scoreField.label} score must be between ${scoreField.min} and ${scoreField.max}.',
          ),
        );
      }
    }
    requireHeader(inspection.assetName, 'Asset / equipment name is required.');
    requireHeader(inspection.siteLocation, 'Location / site is required.');

    for (final UndergroundTemplateSection section
        in UndergroundTemplate.sections) {
      if (_sectionIsValidatedOutsideResponses(section.key)) {
        continue;
      }
      for (final String itemLabel in section.items) {
        if (!_hasCompletedTemplateItem(inspection, section, itemLabel)) {
          issues.add(
            ValidationIssue(
              sectionKey: section.key,
              itemKey: templateItemKey(section.key, itemLabel),
              message: '${section.title} requires $itemLabel.',
            ),
          );
        }
      }
    }

    for (final InspectionResponse response in inspection.responses) {
      final String ratingValue = (response.value ?? '').trim().toLowerCase();
      final bool isFair =
          ratingValue == 'fair' ||
          response.conditionRating == ConditionRating.monitorAtRisk;
      final bool isPoor =
          ratingValue == 'poor' ||
          response.conditionRating == ConditionRating.unsatisfactory;
      final bool isNotInspected = ratingValue == 'not inspected';
      final bool isCritical =
          response.conditionRating == ConditionRating.criticalOutOfService;
      final bool isFlagged =
          response.isFlagged || (response.conditionRating?.isFlagged ?? false);
      final bool requiresComment =
          isFair ||
          isPoor ||
          isNotInspected ||
          isCritical ||
          response.isFlagged;
      final bool requiresPhotoAndAction =
          isPoor || isCritical || response.isFlagged;
      if (!requiresComment && !requiresPhotoAndAction) {
        continue;
      }

      if (requiresComment && (response.comment ?? '').trim().isEmpty) {
        issues.add(
          ValidationIssue(
            sectionKey: response.sectionKey,
            itemKey: response.itemKey,
            message: '${response.itemLabel} requires a comment.',
          ),
        );
      }

      final Iterable<InspectionPhoto> matchingPhotos = inspection.photos.where(
        (InspectionPhoto photo) =>
            photo.sectionKey == response.sectionKey &&
            photo.itemKey == response.itemKey,
      );
      if (requiresPhotoAndAction && matchingPhotos.isEmpty) {
        issues.add(
          ValidationIssue(
            sectionKey: response.sectionKey,
            itemKey: response.itemKey,
            message: '${response.itemLabel} requires at least one photo.',
          ),
        );
      }

      final bool hasActionItem = inspection.actionItems.any((actionItem) {
        return actionItem.sourceSectionKey == response.sectionKey &&
            actionItem.sourceItemKey == response.itemKey;
      });
      if (requiresPhotoAndAction && !hasActionItem) {
        issues.add(
          ValidationIssue(
            sectionKey: response.sectionKey,
            itemKey: response.itemKey,
            message: '${response.itemLabel} requires a linked action item.',
          ),
        );
      }

      if (isCritical && !isFlagged) {
        issues.add(
          ValidationIssue(
            sectionKey: response.sectionKey,
            itemKey: response.itemKey,
            message: '${response.itemLabel} is critical/out of service.',
          ),
        );
      }
    }

    for (final HoseEntry hoseEntry in inspection.hoseEntries) {
      if (!hoseEntry.hasFailure) {
        continue;
      }
      final String hoseKey = 'hose:${hoseEntry.id}';
      final bool hasActionItem = inspection.actionItems.any((
        ActionItem actionItem,
      ) {
        return actionItem.sourceItemKey == hoseKey;
      });
      if (!hasActionItem) {
        issues.add(
          ValidationIssue(
            sectionKey: InspectionSectionKeys.hoseConnectionInspection,
            itemKey: hoseKey,
            message: 'Failed hose entry requires an action item.',
          ),
        );
      }
    }

    for (final FilterEntry filterEntry in inspection.filterEntries) {
      if (filterEntry.replacedStatus != FilterReplacementStatus.no &&
          !(filterEntry.conditionRating?.isFlagged ?? false)) {
        continue;
      }
      final String filterKey = 'filter:${filterEntry.id}';
      if ((filterEntry.notes ?? '').trim().isEmpty) {
        issues.add(
          ValidationIssue(
            sectionKey: InspectionSectionKeys.filtrationBreatherService,
            itemKey: filterKey,
            message: 'Filter replacement entries require a comment.',
          ),
        );
      }
      if (inspection.photosForItem(filterKey).isEmpty) {
        issues.add(
          ValidationIssue(
            sectionKey: InspectionSectionKeys.filtrationBreatherService,
            itemKey: filterKey,
            message: 'Filter replacement entries require at least one photo.',
          ),
        );
      }
      final bool hasActionItem = inspection.actionItems.any((
        ActionItem actionItem,
      ) {
        return actionItem.sourceItemKey == filterKey;
      });
      if (!hasActionItem) {
        issues.add(
          ValidationIssue(
            sectionKey: InspectionSectionKeys.filtrationBreatherService,
            itemKey: filterKey,
            message: 'Filter replacement entries require a linked action item.',
          ),
        );
      }
    }

    for (final InspectionPhoto photo in inspection.photos) {
      final int perItemCount = inspection.photosForItem(photo.itemKey).length;
      if (perItemCount > AppConstants.maxPhotosPerInspectionItem) {
        issues.add(
          ValidationIssue(
            sectionKey: photo.sectionKey,
            itemKey: photo.itemKey,
            message:
                'No more than ${AppConstants.maxPhotosPerInspectionItem} photos are allowed per item.',
          ),
        );
      }
    }

    if (inspection.hasCriticalItems && !inspection.criticalAcknowledged) {
      issues.add(
        ValidationIssue(
          sectionKey: InspectionSectionKeys.reviewCompletion,
          itemKey: InspectionItemKeys.criticalAcknowledgement,
          message: AppConstants.lotOWarning,
        ),
      );
    }

    if ((inspection.signatureFilePath ?? '').trim().isEmpty) {
      issues.add(
        const ValidationIssue(
          sectionKey: InspectionSectionKeys.reviewCompletion,
          itemKey: InspectionItemKeys.technicianSignature,
          message: 'Inspector signature is required.',
        ),
      );
    }

    final InspectionResponse? additionalRepairsResponse = inspection
        .responseByKey(
          InspectionSectionKeys.followUpRepairsQuoting,
          InspectionItemKeys.additionalPartsRepairs,
        );
    if ((additionalRepairsResponse?.value ?? '') == 'yes' &&
        inspection.requiredItems.isEmpty &&
        inspection.actionItems.isEmpty) {
      issues.add(
        const ValidationIssue(
          sectionKey: InspectionSectionKeys.followUpRepairsQuoting,
          itemKey: InspectionItemKeys.additionalPartsRepairs,
          message:
              'Additional parts / repairs requires at least one required item or action item.',
        ),
      );
    }

    return ValidationResult(issues);
  }

  static InspectionStatus deriveStatus(InspectionRecord inspection) {
    final ValidationResult result = validateForCompletion(inspection);
    final bool hasGeneratedPdf = (inspection.generatedPdfPath ?? '')
        .trim()
        .isNotEmpty;
    if (inspection.emailedAt != null &&
        result.isValid &&
        inspection.completedAt != null &&
        hasGeneratedPdf) {
      return InspectionStatus.emailed;
    }
    if (result.isValid && inspection.completedAt != null) {
      return InspectionStatus.complete;
    }
    if (_hasMeaningfulProgress(inspection)) {
      return InspectionStatus.inProgress;
    }
    return InspectionStatus.draft;
  }

  static bool _hasMeaningfulProgress(InspectionRecord inspection) {
    return inspection.customer.trim().isNotEmpty ||
        inspection.workOrderNumber.trim().isNotEmpty ||
        inspection.responses.isNotEmpty ||
        inspection.photos.isNotEmpty ||
        inspection.componentEntries.any(
          (ComponentEntry entry) =>
              (entry.modelPartNumber ?? '').trim().isNotEmpty ||
              (entry.serialNumber ?? '').trim().isNotEmpty,
        ) ||
        inspection.hoseEntries.any(
          (HoseEntry entry) =>
              (entry.hoseNameLocation ?? '').trim().isNotEmpty ||
              entry.failureType != null,
        ) ||
        inspection.filterEntries.any(
          (FilterEntry entry) =>
              (entry.filterName ?? '').trim().isNotEmpty ||
              (entry.partNumber ?? '').trim().isNotEmpty,
        );
  }

  static bool _sectionIsValidatedOutsideResponses(String sectionKey) {
    return sectionKey == 'machine_identification' ||
        sectionKey == 'photographic_evidence' ||
        sectionKey == 'final_recommendation_signoff';
  }

  static bool _hasCompletedTemplateItem(
    InspectionRecord inspection,
    UndergroundTemplateSection section,
    String itemLabel,
  ) {
    final expectedItemKey = templateItemKey(section.key, itemLabel);
    for (final InspectionResponse response in inspection.responses) {
      if (response.sectionKey != section.key) {
        continue;
      }
      final bool matchesItem =
          response.itemKey == expectedItemKey ||
          response.itemLabel == itemLabel;
      if (!matchesItem) {
        continue;
      }
      if ((response.value ?? '').trim().isNotEmpty ||
          (response.comment ?? '').trim().isNotEmpty ||
          response.conditionRating != null ||
          inspection.photosForItem(response.itemKey).isNotEmpty) {
        return true;
      }
    }
    return false;
  }
}
