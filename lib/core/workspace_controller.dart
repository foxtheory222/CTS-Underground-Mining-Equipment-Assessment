import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'constants.dart';
import 'theme.dart';
import '../data/models/inspection_enums.dart';
import '../data/models/inspection_models.dart';
import '../data/repositories/inspection_repository.dart';
import '../services/backup_service.dart';
import 'workspace_models.dart';

class AppWorkspaceController extends ChangeNotifier {
  AppWorkspaceController({
    InspectionRepository? repository,
    bool autoLoad = true,
    List<InspectionSummary>? seedInspections,
  }) : _repository = repository,
       _inspections =
           seedInspections ??
           (repository == null ? _seedInspections() : <InspectionSummary>[]) {
    if (_repository != null && autoLoad) {
      unawaited(refresh());
    }
  }

  final InspectionRepository? _repository;
  final List<InspectionSummary> _inspections;
  String _searchQuery = '';
  InspectionStatus? _statusFilter;
  bool _isLoading = false;
  Object? _lastError;

  String get searchQuery => _searchQuery;
  InspectionStatus? get statusFilter => _statusFilter;
  bool get isLoading => _isLoading;
  Object? get lastError => _lastError;

  List<InspectionSummary> get inspections => List.unmodifiable(_inspections);

  List<InspectionSummary> get filteredInspections {
    final query = _searchQuery.trim().toLowerCase();
    return _inspections
        .where((inspection) {
          final matchesQuery =
              query.isEmpty || inspection.searchableText.contains(query);
          final matchesStatus =
              _statusFilter == null || inspection.status == _statusFilter;
          return matchesQuery && matchesStatus;
        })
        .toList(growable: false);
  }

  List<DashboardMetric> get dashboardMetrics => [
    DashboardMetric(
      label: 'Draft',
      value: _inspections
          .where((item) => item.status == InspectionStatus.draft)
          .length
          .toString(),
      icon: Icons.description_outlined,
      color: CtsPalette.slate,
      subtitle: 'Ready to continue',
    ),
    DashboardMetric(
      label: 'In Progress',
      value: _inspections
          .where((item) => item.status == InspectionStatus.inProgress)
          .length
          .toString(),
      icon: Icons.play_circle_outline,
      color: CtsPalette.orange,
      subtitle: 'Actively being filled out',
    ),
    DashboardMetric(
      label: 'Complete',
      value: _inspections
          .where((item) => item.status == InspectionStatus.complete)
          .length
          .toString(),
      icon: Icons.verified_outlined,
      color: CtsPalette.success,
      subtitle: 'Validated and signed',
    ),
    DashboardMetric(
      label: 'Emailed',
      value: _inspections
          .where((item) => item.status == InspectionStatus.emailed)
          .length
          .toString(),
      icon: Icons.mark_email_read_outlined,
      color: CtsPalette.info,
      subtitle: 'Handed off to the customer',
    ),
    DashboardMetric(
      label: 'Critical',
      value: _inspections
          .where((item) => item.criticalCount > 0)
          .length
          .toString(),
      icon: Icons.warning_amber_rounded,
      color: CtsPalette.danger,
      subtitle: 'LOTO attention required',
    ),
    DashboardMetric(
      label: 'Photos',
      value: _inspections
          .fold<int>(0, (sum, item) => sum + item.photoCount)
          .toString(),
      icon: Icons.photo_library_outlined,
      color: CtsPalette.orangeSoft,
      subtitle: 'Stored locally on device',
    ),
  ];

  InspectionSummary? inspectionById(String id) {
    for (final inspection in _inspections) {
      if (inspection.id == id) {
        return inspection;
      }
    }
    return null;
  }

  List<InspectionSummary> get recentInspections {
    final copy = List<InspectionSummary>.of(_inspections);
    copy.sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));
    return copy.take(6).toList(growable: false);
  }

  List<InspectionActionItemView> get openActionItems =>
      _inspections.expand((item) => item.actionItems).toList(growable: false);

  void setSearchQuery(String value) {
    if (value == _searchQuery) {
      return;
    }
    _searchQuery = value;
    notifyListeners();
  }

  void setStatusFilter(InspectionStatus? status) {
    if (status == _statusFilter) {
      return;
    }
    _statusFilter = status;
    notifyListeners();
  }

  Future<void> refresh() async {
    final repository = _repository;
    if (repository == null) {
      return;
    }

    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final records = await repository.allInspections();
      _inspections
        ..clear()
        ..addAll(records.map(_summaryFromRecord));
    } catch (error) {
      _lastError = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<InspectionSummary> createInspection({DateTime? createdAt}) async {
    final repository = _repository;
    if (repository != null) {
      final record = await repository.createInspection(createdAt: createdAt);
      final summary = _summaryFromRecord(record);
      _upsertSummary(summary, insertAtTop: true);
      return summary;
    }

    final now = DateTime.now();
    final documentNumber = _nextDocumentNumberForDate(now);
    final inspection = InspectionSummary(
      id: _makeId(documentNumber),
      documentNumber: documentNumber,
      customer: '',
      workOrderNumber: '',
      customerReference: '',
      assetName: '',
      siteLocation: '',
      technicianName: '',
      servicingShop: '',
      inspectionDateTime: now,
      createdAt: now,
      status: InspectionStatus.draft,
      sections: _defaultSections(),
      actionItems: [],
      photos: [],
      flaggedCount: 0,
      atRiskCount: 0,
      unsatisfactoryCount: 0,
      criticalCount: 0,
      photoCount: 0,
      lastUpdatedAt: now,
    );
    _inspections.insert(0, inspection);
    notifyListeners();
    return inspection;
  }

  Future<InspectionSummary> duplicateInspection(
    InspectionSummary source, {
    DateTime? createdAt,
  }) async {
    final repository = _repository;
    if (repository != null) {
      final sourceRecord = await repository.getInspection(source.id);
      if (sourceRecord == null) {
        throw StateError('Inspection not found for duplicate: ${source.id}');
      }
      final record = await repository.duplicateInspection(
        sourceRecord,
        createdAt: createdAt,
      );
      final summary = _summaryFromRecord(record);
      _upsertSummary(summary, insertAtTop: true);
      return summary;
    }

    final now = DateTime.now();
    final documentNumber = _nextDocumentNumberForDate(now);
    final clone = source.copyWith(
      id: _makeId(documentNumber),
      documentNumber: documentNumber,
      status: InspectionStatus.draft,
      createdAt: now,
      inspectionDateTime: now,
      completedAt: null,
      emailedAt: null,
      finalTechComments: null,
      criticalAcknowledged: false,
      generatedPdfPath: null,
      sections: _defaultSections(),
      actionItems: [],
      photos: [],
      flaggedCount: 0,
      atRiskCount: 0,
      unsatisfactoryCount: 0,
      criticalCount: 0,
      photoCount: 0,
      lastUpdatedAt: now,
    );
    _inspections.insert(0, clone);
    notifyListeners();
    return clone;
  }

  void replaceInspection(InspectionSummary updated) {
    final index = _inspections.indexWhere((item) => item.id == updated.id);
    if (index != -1) {
      _inspections[index] = updated;
      notifyListeners();
    }
  }

  Future<InspectionSummary> importInspection(
    BackupImportResult importResult,
  ) async {
    final repository = _repository;
    if (repository == null) {
      throw StateError('Import persistence requires an inspection repository.');
    }
    final record = await repository.importInspectionJson(
      importResult.inspectionJson,
      restoredPhotoFiles: importResult.restoredPhotoFiles,
      restoredPdfFile: importResult.restoredPdfFile,
    );
    final summary = _summaryFromRecord(record);
    _upsertSummary(summary, insertAtTop: true);
    return summary;
  }

  void _upsertSummary(InspectionSummary summary, {required bool insertAtTop}) {
    final index = _inspections.indexWhere((item) => item.id == summary.id);
    if (index == -1) {
      if (insertAtTop) {
        _inspections.insert(0, summary);
      } else {
        _inspections.add(summary);
      }
    } else {
      _inspections[index] = summary;
    }
    notifyListeners();
  }

  InspectionSummary _summaryFromRecord(InspectionRecord record) {
    return InspectionSummary(
      id: record.id,
      documentNumber: record.documentNumber,
      customer: record.customer,
      workOrderNumber: record.workOrderNumber,
      customerReference: record.customerReference,
      assetName: record.assetName.isEmpty
          ? record.serialNumber
          : record.assetName,
      siteLocation: record.siteLocation.isEmpty
          ? record.mineSite
          : record.siteLocation,
      technicianName: record.technicianName,
      servicingShop: record.servicingShop,
      inspectionDateTime: record.inspectionDateTime,
      createdAt: record.createdAt,
      status: record.status,
      sections: _sectionsFromRecord(record),
      actionItems: record.actionItems
          .map((actionItem) => _actionItemFromRecord(record, actionItem))
          .toList(growable: false),
      photos: record.photos
          .map((photo) => _photoFromRecord(record, photo))
          .toList(growable: false),
      flaggedCount: record.flaggedItemCount,
      atRiskCount: record.atRiskCount,
      unsatisfactoryCount: record.unsatisfactoryCount,
      criticalCount: record.criticalCount,
      photoCount: record.photoCount,
      lastUpdatedAt: record.updatedAt,
      completedAt: record.completedAt,
      emailedAt: record.emailedAt,
      finalTechComments: record.finalTechComments,
      criticalAcknowledged: record.criticalAcknowledged,
      generatedPdfPath: record.generatedPdfPath,
    );
  }

  List<InspectionSectionView> _sectionsFromRecord(InspectionRecord record) {
    if (record.sections.isEmpty) {
      return _defaultSections(
        atRisk: record.atRiskCount,
        unsat: record.unsatisfactoryCount,
        critical: record.criticalCount,
        photoCount: record.photoCount,
      );
    }
    return record.sections
        .map((section) {
          final flaggedCount = record.responses
              .where(
                (response) =>
                    response.sectionKey == section.sectionKey &&
                    (response.isFlagged ||
                        (response.conditionRating?.isFlagged ?? false)),
              )
              .length;
          final criticalWarning = record.responses.any(
            (response) =>
                response.sectionKey == section.sectionKey &&
                response.conditionRating ==
                    ConditionRating.criticalOutOfService,
          );
          final photoCount = record.photos
              .where((photo) => photo.sectionKey == section.sectionKey)
              .length;
          return InspectionSectionView(
            key: section.sectionKey,
            title: section.title,
            completionState: section.completionState,
            summary: _summaryForSectionState(section.completionState),
            photoCount: photoCount,
            flaggedCount: flaggedCount,
            criticalWarning: criticalWarning,
          );
        })
        .toList(growable: false);
  }

  InspectionActionItemView _actionItemFromRecord(
    InspectionRecord record,
    ActionItem actionItem,
  ) {
    return InspectionActionItemView(
      title: actionItem.title,
      description: actionItem.description,
      conditionRating:
          actionItem.conditionRating ?? ConditionRating.monitorAtRisk,
      sourceSection: _sectionTitle(record, actionItem.sourceSectionKey),
      sourceItem: _itemLabel(record, actionItem.sourceItemKey),
      partsRequired: actionItem.partsRequired,
      isAutoGenerated: actionItem.isAutoGenerated,
    );
  }

  InspectionPhotoView _photoFromRecord(
    InspectionRecord record,
    InspectionPhoto photo,
  ) {
    return InspectionPhotoView(
      assetPath: photo.filePath,
      caption: photo.caption?.trim().isEmpty ?? true
          ? 'Inspection photo'
          : photo.caption!,
      sectionTitle: _sectionTitle(record, photo.sectionKey),
      itemLabel: _itemLabel(record, photo.itemKey),
      capturedAt: photo.capturedAt,
    );
  }

  String _sectionTitle(InspectionRecord record, String? sectionKey) {
    if (sectionKey == null) {
      return 'Inspection';
    }
    for (final section in record.sections) {
      if (section.sectionKey == sectionKey) {
        return section.title;
      }
    }
    return inspectionSectionTitles[sectionKey] ?? sectionKey;
  }

  String _itemLabel(InspectionRecord record, String? itemKey) {
    if (itemKey == null) {
      return 'Inspection item';
    }
    for (final response in record.responses) {
      if (response.itemKey == itemKey) {
        return response.itemLabel;
      }
    }
    return itemKey;
  }

  String _summaryForSectionState(SectionCompletionState state) {
    return switch (state) {
      SectionCompletionState.notStarted => 'No saved entries yet.',
      SectionCompletionState.inProgress => 'Saved work remains in progress.',
      SectionCompletionState.complete => 'Section validation is complete.',
      SectionCompletionState.blocked =>
        'Section needs attention before signoff.',
    };
  }

  String _nextDocumentNumberForDate(DateTime date) {
    final dayStamp = DateFormat('yyyyMMdd').format(date);
    final matches = _inspections
        .where((item) => item.documentNumber.startsWith('$dayStamp-'))
        .length;
    final sequence = matches + 1;
    return '$dayStamp-${sequence.toString().padLeft(4, '0')}';
  }

  String _makeId(String documentNumber) {
    return 'inspection_${documentNumber.replaceAll('-', '_')}';
  }

  static List<InspectionSummary> _seedInspections() {
    final today = DateTime(2026, 4, 20, 8, 30);
    final yesterday = today.subtract(const Duration(days: 1));
    final inspection1 = InspectionSummary(
      id: 'inspection_20260420_0001',
      documentNumber: '20260420-0001',
      customer: 'Moraine Underground',
      workOrderNumber: 'WO-48912',
      customerReference: 'PO-55412',
      assetName: 'Rock Scaler RS-1001',
      siteLocation: 'East Decline Service Bay',
      technicianName: 'R. Ellis',
      servicingShop: 'CTS Edmonton Service',
      inspectionDateTime: today,
      createdAt: today,
      status: InspectionStatus.complete,
      sections: _defaultSections(
        atRisk: 1,
        unsat: 1,
        critical: 0,
        photoCount: 5,
      ),
      actionItems: [
        InspectionActionItemView(
          title: 'Replace damaged boom hose at articulation area',
          description:
              'Abrasion near the fitting on boom hose H-12 was flagged during the inspection.',
          conditionRating: ConditionRating.unsatisfactory,
          sourceSection: 'Hydraulic System Assessment',
          sourceItem: 'Hydraulic hose defect entry',
          partsRequired: 'Hose assembly, two JIC fittings, crimp sleeves',
        ),
      ],
      photos: [
        InspectionPhotoView(
          assetPath: 'assets/demo/sample_photo_1.jpg',
          caption: 'As-found unit overview',
          sectionTitle: 'Job & Asset Identification',
          itemLabel: 'Machine wide shot',
          capturedAt: DateTime(2026, 4, 20, 8, 45),
        ),
        InspectionPhotoView(
          assetPath: 'assets/demo/sample_photo_2.jpg',
          caption: 'Machine nameplate close-up',
          sectionTitle: 'Machine Identification',
          itemLabel: 'Nameplate',
          capturedAt: DateTime(2026, 4, 20, 9, 10),
        ),
      ],
      flaggedCount: 2,
      atRiskCount: 1,
      unsatisfactoryCount: 1,
      criticalCount: 0,
      photoCount: 5,
      lastUpdatedAt: today.add(const Duration(minutes: 32)),
      completedAt: today.add(const Duration(hours: 1, minutes: 14)),
      finalTechComments:
          'Machine operating within service limits after hose replacement planning.',
      generatedPdfPath:
          '/storage/emulated/0/Download/CTS_UMEA_Moraine_Underground_RS-1001_20260420_20260420-0001.pdf',
    );

    final inspection2 = InspectionSummary(
      id: 'inspection_20260420_0002',
      documentNumber: '20260420-0002',
      customer: 'North Basin Processing',
      workOrderNumber: 'WO-48921',
      customerReference: 'JOB-7745',
      assetName: 'Jumbo Drill JD-04',
      siteLocation: 'North Ore Zone',
      technicianName: 'K. Morgan',
      servicingShop: 'CTS Calgary Service',
      inspectionDateTime: today.add(const Duration(hours: 2)),
      createdAt: today.add(const Duration(hours: 2)),
      status: InspectionStatus.emailed,
      sections: _defaultSections(
        atRisk: 2,
        unsat: 1,
        critical: 1,
        photoCount: 7,
      ),
      actionItems: [
        InspectionActionItemView(
          title: 'Lockout/Tagout before restart',
          description:
              'Critical brake system issue requires isolation until corrective work is complete.',
          conditionRating: ConditionRating.criticalOutOfService,
          sourceSection: 'Braking System',
          sourceItem: 'Service Brakes',
          partsRequired: 'Brake valve kit, lockout hardware',
        ),
        InspectionActionItemView(
          title: 'Replace breather element',
          description:
              'Hydraulic filtration contamination noted; element replacement recommended.',
          conditionRating: ConditionRating.monitorAtRisk,
          sourceSection: 'Hydraulic System Assessment',
          sourceItem: 'Filtration System',
          partsRequired: 'Breather element 12-7781',
        ),
      ],
      photos: [
        InspectionPhotoView(
          assetPath: 'assets/demo/sample_photo_1.jpg',
          caption: 'Critical service brake test result',
          sectionTitle: 'Braking System',
          itemLabel: 'Service Brakes',
          capturedAt: DateTime(2026, 4, 20, 10, 12),
        ),
        InspectionPhotoView(
          assetPath: 'assets/demo/sample_photo_2.jpg',
          caption: 'Hydraulic pressure test under load',
          sectionTitle: 'Hydraulic System Assessment',
          itemLabel: 'Pressure Testing',
          capturedAt: DateTime(2026, 4, 20, 10, 18),
        ),
      ],
      flaggedCount: 3,
      atRiskCount: 2,
      unsatisfactoryCount: 1,
      criticalCount: 1,
      photoCount: 7,
      lastUpdatedAt: today.add(const Duration(hours: 2, minutes: 55)),
      completedAt: today.add(const Duration(hours: 3, minutes: 10)),
      emailedAt: today.add(const Duration(hours: 3, minutes: 42)),
      criticalAcknowledged: true,
      generatedPdfPath:
          '/storage/emulated/0/Download/CTS_UMEA_North_Basin_Processing_JD-04_20260420_20260420-0002.pdf',
    );

    final inspection3 = InspectionSummary(
      id: 'inspection_20260419_0001',
      documentNumber: '20260419-0001',
      customer: 'Prairie Shaft Services',
      workOrderNumber: 'WO-48888',
      customerReference: 'PR-1182',
      assetName: 'Utility Vehicle UV-42',
      siteLocation: 'Maintenance Drift',
      technicianName: 'T. Singh',
      servicingShop: 'CTS Red Deer Service',
      inspectionDateTime: yesterday,
      createdAt: yesterday,
      status: InspectionStatus.inProgress,
      sections: _defaultSections(
        atRisk: 0,
        unsat: 0,
        critical: 0,
        photoCount: 2,
      ),
      actionItems: [],
      photos: [
        InspectionPhotoView(
          assetPath: 'assets/demo/sample_photo_1.jpg',
          caption: 'Asset identification photo',
          sectionTitle: 'Job & Asset Identification',
          itemLabel: 'Machine wide shot',
          capturedAt: DateTime(2026, 4, 19, 15, 01),
        ),
      ],
      flaggedCount: 0,
      atRiskCount: 0,
      unsatisfactoryCount: 0,
      criticalCount: 0,
      photoCount: 2,
      lastUpdatedAt: yesterday.add(const Duration(hours: 1, minutes: 45)),
    );

    return [inspection2, inspection1, inspection3];
  }

  static List<InspectionSectionView> _defaultSections({
    int atRisk = 0,
    int unsat = 0,
    int critical = 0,
    int photoCount = 0,
  }) {
    return [
      InspectionSectionView(
        key: InspectionSectionKeys.jobAssetIdentification,
        title:
            inspectionSectionTitles[InspectionSectionKeys
                .jobAssetIdentification]!,
        completionState: SectionCompletionState.complete,
        summary: 'Machine identification complete and photos captured.',
        photoCount: photoCount > 0 ? 2 : 0,
      ),
      InspectionSectionView(
        key: InspectionSectionKeys.componentTracking,
        title:
            inspectionSectionTitles[InspectionSectionKeys.componentTracking]!,
        completionState: SectionCompletionState.complete,
        summary: 'Structural observations and component notes captured.',
        photoCount: photoCount > 1 ? 2 : 0,
      ),
      InspectionSectionView(
        key: InspectionSectionKeys.fluidTankService,
        title: inspectionSectionTitles[InspectionSectionKeys.fluidTankService]!,
        completionState: critical > 0
            ? SectionCompletionState.blocked
            : atRisk > 0 || unsat > 0
            ? SectionCompletionState.inProgress
            : SectionCompletionState.complete,
        summary: critical > 0
            ? 'Critical hydraulic warning acknowledged.'
            : atRisk > 0 || unsat > 0
            ? 'Flagged hydraulic system items need follow-up.'
            : 'Hydraulic system condition is within tolerance.',
        photoCount: photoCount > 2 ? 1 : 0,
        flaggedCount: atRisk + unsat + critical,
        criticalWarning: critical > 0,
      ),
      InspectionSectionView(
        key: InspectionSectionKeys.hoseConnectionInspection,
        title:
            inspectionSectionTitles[InspectionSectionKeys
                .hoseConnectionInspection]!,
        completionState: atRisk > 0 || unsat > 0
            ? SectionCompletionState.inProgress
            : SectionCompletionState.complete,
        summary: 'Hose defect entries and fitting notes documented.',
        photoCount: photoCount > 3 ? 1 : 0,
        flaggedCount: atRisk > 0 ? 1 : 0,
      ),
      InspectionSectionView(
        key: InspectionSectionKeys.filtrationBreatherService,
        title:
            inspectionSectionTitles[InspectionSectionKeys
                .filtrationBreatherService]!,
        completionState: atRisk > 0
            ? SectionCompletionState.inProgress
            : SectionCompletionState.complete,
        summary: 'Condition monitoring observations captured.',
        photoCount: photoCount > 4 ? 1 : 0,
      ),
      InspectionSectionView(
        key: InspectionSectionKeys.operationalDataSystemTest,
        title:
            inspectionSectionTitles[InspectionSectionKeys
                .operationalDataSystemTest]!,
        completionState: SectionCompletionState.complete,
        summary: 'Remaining life estimates stored.',
        photoCount: photoCount > 5 ? 1 : 0,
      ),
      InspectionSectionView(
        key: InspectionSectionKeys.followUpRepairsQuoting,
        title:
            inspectionSectionTitles[InspectionSectionKeys
                .followUpRepairsQuoting]!,
        completionState: atRisk > 0
            ? SectionCompletionState.inProgress
            : SectionCompletionState.complete,
        summary: 'Rebuild recommendations and follow-up actions are tracked.',
        photoCount: photoCount > 6 ? 1 : 0,
      ),
      InspectionSectionView(
        key: InspectionSectionKeys.reviewCompletion,
        title: inspectionSectionTitles[InspectionSectionKeys.reviewCompletion]!,
        completionState: atRisk > 0 || unsat > 0 || critical > 0
            ? SectionCompletionState.blocked
            : SectionCompletionState.complete,
        summary: 'Ready for signoff when validation is clear.',
        photoCount: 0,
        flaggedCount: atRisk + unsat + critical,
        criticalWarning: critical > 0,
      ),
    ];
  }
}
