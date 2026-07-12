import '../core/constants.dart';
import '../core/underground_template.dart';
import '../core/validators.dart';
import '../data/models/inspection_enums.dart';
import '../data/models/inspection_models.dart';
import '../features/pdf_report/pdf_report_models.dart';

InspectionReportData inspectionRecordToReportData(InspectionRecord record) {
  return InspectionReportData(
    documentNumber: record.documentNumber,
    customer: record.customer,
    workOrderNumber: record.workOrderNumber,
    customerReference: record.customerReference,
    assetName: record.assetName,
    siteLocation: record.siteLocation,
    technicianName: record.technicianName,
    servicingShop: record.servicingShop,
    inspectionDateTime: record.inspectionDateTime,
    createdAt: record.createdAt,
    completedAt: record.completedAt,
    emailedAt: record.emailedAt,
    status: _reportStatus(record.status),
    finalTechComments: record.finalTechComments,
    criticalAcknowledged: record.criticalAcknowledged,
    signature: _reportSignature(record),
    customerSignature: _customerReportSignature(record),
    sections: _reportSections(record),
    actionItems: record.actionItems.map(_reportActionItem).toList(),
    branding: const InspectionReportBranding(
      logoAssetPath: AppConstants.placeholderLogoAsset,
    ),
  );
}

List<InspectionReportSection> _reportSections(InspectionRecord record) {
  final sections = <InspectionReportSection>[];
  for (final templateSection in UndergroundTemplate.sections) {
    final responses = record.responses
        .where((response) => response.sectionKey == templateSection.key)
        .toList(growable: false);
    final items = responses.isEmpty
        ? _fallbackItemsForSection(record, templateSection)
        : responses.map((response) => _reportItem(record, response)).toList();
    sections.add(
      InspectionReportSection(
        key: templateSection.key,
        title: templateSection.title,
        items: items,
      ),
    );
  }

  final orphanPhotos = record.photos
      .where(
        (photo) => !record.responses.any(
          (response) =>
              response.sectionKey == photo.sectionKey &&
              response.itemKey == photo.itemKey,
        ),
      )
      .toList(growable: false);
  if (orphanPhotos.isNotEmpty) {
    sections.add(
      InspectionReportSection(
        key: 'additional_photos',
        title: 'Additional Photographic Evidence',
        items: orphanPhotos
            .map(
              (photo) => InspectionReportItem(
                label: photo.caption?.trim().isEmpty ?? true
                    ? photo.itemKey
                    : photo.caption!.trim(),
                value: _sectionTitle(photo.sectionKey),
                photos: <InspectionReportPhoto>[_reportPhoto(photo)],
              ),
            )
            .toList(),
      ),
    );
  }

  return sections;
}

List<InspectionReportItem> _fallbackItemsForSection(
  InspectionRecord record,
  UndergroundTemplateSection section,
) {
  if (section.key == 'machine_identification') {
    return <InspectionReportItem>[
      InspectionReportItem(label: 'OEM', value: _display(record.manufacturer)),
      InspectionReportItem(label: 'Model', value: _display(record.model)),
      InspectionReportItem(
        label: 'Serial Number',
        value: _display(record.serialNumber),
      ),
      InspectionReportItem(
        label: 'Current Hours',
        value: _display(record.machineHours),
      ),
      InspectionReportItem(
        label: 'Machine Type',
        value: _display(record.machineType),
      ),
      InspectionReportItem(
        label: 'Purpose',
        value: record.selectedPurposes.isEmpty
            ? 'Not recorded'
            : record.selectedPurposes.join(', '),
      ),
      InspectionReportItem(
        label: 'Asset Status',
        value: _display(record.assetStatus),
      ),
    ];
  }

  if (section.key == 'estimated_rebuild_cost_forecast') {
    return record.requiredItems
        .map(
          (item) => InspectionReportItem(
            label: _display(item.itemName),
            value: [
              item.description ?? '',
              if ((item.partNumber ?? '').trim().isNotEmpty)
                'Part ${item.partNumber}',
              if (item.quantity != null) 'Qty ${item.quantity}',
              item.notes ?? '',
            ].where((part) => part.trim().isNotEmpty).join(' | '),
          ),
        )
        .toList();
  }

  if (section.key == 'final_recommendation_signoff') {
    return <InspectionReportItem>[
      InspectionReportItem(
        label: 'Final CTS Recommendation',
        value: _display(record.finalRecommendation),
      ),
      InspectionReportItem(
        label: 'CTS Inspector Typed Name',
        value: _display(record.technicianName),
      ),
      InspectionReportItem(
        label: 'CTS Inspector Drawn Signature',
        value: (record.signatureFilePath ?? '').trim().isEmpty
            ? 'Not captured'
            : 'Captured',
      ),
    ];
  }

  return const <InspectionReportItem>[];
}

InspectionReportItem _reportItem(
  InspectionRecord record,
  InspectionResponse response,
) {
  return InspectionReportItem(
    label: response.itemLabel,
    value: _display(response.value),
    conditionRating: _reportConditionRating(response.conditionRating),
    isExplicitlyFlagged: response.isFlagged,
    comment: response.comment,
    photos: record.photos
        .where(
          (photo) =>
              photo.sectionKey == response.sectionKey &&
              photo.itemKey == response.itemKey,
        )
        .map(_reportPhoto)
        .toList(),
  );
}

InspectionReportPhoto _reportPhoto(InspectionPhoto photo) {
  return InspectionReportPhoto(
    filePath: photo.filePath,
    caption: photo.caption?.trim().isEmpty ?? true
        ? 'Inspection photo'
        : photo.caption!.trim(),
    sectionTitle: _sectionTitle(photo.sectionKey),
    itemLabel: photo.itemKey,
    capturedAt: photo.capturedAt,
    sortOrder: photo.sortOrder,
  );
}

InspectionReportActionItem _reportActionItem(ActionItem actionItem) {
  return InspectionReportActionItem(
    title: actionItem.title,
    description: actionItem.description,
    sourceSection: actionItem.sourceSectionKey == null
        ? null
        : _sectionTitle(actionItem.sourceSectionKey!),
    sourceItem: actionItem.sourceItemKey,
    partsRequired: actionItem.partsRequired,
    isAutoGenerated: actionItem.isAutoGenerated,
    conditionRating: _reportConditionRating(actionItem.conditionRating),
  );
}

InspectionReportSignature? _reportSignature(InspectionRecord record) {
  final path = (record.signatureFilePath ?? '').trim();
  if (path.isEmpty) {
    return null;
  }
  return InspectionReportSignature(
    filePath: path,
    signerName: record.technicianName,
    signedAt: record.completedAt ?? record.updatedAt,
  );
}

InspectionReportSignature? _customerReportSignature(InspectionRecord record) {
  final path = (record.customerSignatureFilePath ?? '').trim();
  if (path.isEmpty) {
    return null;
  }
  final representativeKey = InspectionValidator.templateItemKey(
    'final_recommendation_signoff',
    'Customer Representative Name',
  );
  final representative = record
      .responseByKey('final_recommendation_signoff', representativeKey)
      ?.value
      ?.trim();
  return InspectionReportSignature(
    filePath: path,
    signerName: representative == null || representative.isEmpty
        ? (record.customer.trim().isEmpty ? 'Customer' : record.customer)
        : representative,
    signedAt: record.completedAt ?? record.updatedAt,
  );
}

InspectionReportStatus _reportStatus(InspectionStatus status) {
  return switch (status) {
    InspectionStatus.draft => InspectionReportStatus.draft,
    InspectionStatus.inProgress => InspectionReportStatus.inProgress,
    InspectionStatus.complete => InspectionReportStatus.complete,
    InspectionStatus.emailed => InspectionReportStatus.emailed,
  };
}

ReportConditionRating? _reportConditionRating(ConditionRating? rating) {
  if (rating == null) {
    return null;
  }
  return switch (rating) {
    ConditionRating.satisfactory => ReportConditionRating.satisfactory,
    ConditionRating.monitorAtRisk => ReportConditionRating.monitor,
    ConditionRating.unsatisfactory => ReportConditionRating.unsatisfactory,
    ConditionRating.criticalOutOfService => ReportConditionRating.critical,
  };
}

String _sectionTitle(String sectionKey) {
  for (final section in UndergroundTemplate.sections) {
    if (section.key == sectionKey) {
      return section.title;
    }
  }
  for (final descriptor in InspectionSectionKeys.ordered) {
    if (descriptor.key == sectionKey) {
      return descriptor.title;
    }
  }
  return sectionKey;
}

String _display(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? 'Not recorded' : trimmed;
}
