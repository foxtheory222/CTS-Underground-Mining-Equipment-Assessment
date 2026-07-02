import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'constants.dart';
import 'file_utils.dart';
import 'theme.dart';
import 'underground_template.dart';
import 'validators.dart';
import '../data/models/inspection_enums.dart';
import '../data/models/inspection_models.dart';
import '../data/repositories/inspection_repository.dart';
import '../services/backup_service.dart';
import '../services/email_service.dart';
import '../services/inspection_report_mapper.dart';
import '../services/pdf_service.dart';
import '../services/photo_service.dart';
import 'workspace_models.dart';

typedef InspectionReportDirectoryProvider =
    Future<Directory> Function(String inspectionId);
typedef InspectionSignatureDirectoryProvider =
    Future<Directory> Function(String inspectionId);

class AppWorkspaceController extends ChangeNotifier {
  AppWorkspaceController({
    InspectionRepository? repository,
    PdfService? pdfService,
    EmailService? emailService,
    BackupService? backupService,
    PhotoService? photoService,
    InspectionReportDirectoryProvider? reportDirectoryProvider,
    InspectionSignatureDirectoryProvider? signatureDirectoryProvider,
    Uuid? uuid,
    bool autoLoad = true,
    List<InspectionSummary>? seedInspections,
  }) : _repository = repository,
       _pdfService = pdfService ?? PdfService(),
       _emailService = emailService ?? EmailService(),
       _backupService = backupService ?? BackupService(),
       _photoService = photoService ?? PhotoService(),
       _reportDirectoryProvider =
           reportDirectoryProvider ?? FileUtils.inspectionReportsDirectory,
       _signatureDirectoryProvider =
           signatureDirectoryProvider ?? FileUtils.inspectionDirectory,
       _uuid = uuid ?? const Uuid(),
       _inspections =
           seedInspections ??
           (repository == null ? _seedInspections() : <InspectionSummary>[]) {
    if (_repository != null && autoLoad) {
      unawaited(refresh());
    }
  }

  final InspectionRepository? _repository;
  final PdfService _pdfService;
  final EmailService _emailService;
  final BackupService _backupService;
  final PhotoService _photoService;
  final InspectionReportDirectoryProvider _reportDirectoryProvider;
  final InspectionSignatureDirectoryProvider _signatureDirectoryProvider;
  final Uuid _uuid;
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

  Future<InspectionSummary> saveFormDraft(InspectionFormDraft draft) async {
    final repository = _requiredRepository();
    final record = await _requiredRecord(draft.inspectionId);
    final signaturePath = draft.signaturePngBytes == null
        ? null
        : await _writeSignaturePng(record.id, draft.signaturePngBytes!);
    _applyFormDraft(record, draft, signaturePath: signaturePath);
    final saved = await repository.saveInspection(record);
    final summary = _summaryFromRecord(saved);
    _upsertSummary(summary, insertAtTop: false);
    return summary;
  }

  Future<InspectionSummary> attachPhotoForDraft(
    InspectionFormDraft draft, {
    PhotoInputSource source = PhotoInputSource.camera,
  }) async {
    final repository = _requiredRepository();
    final record = await _requiredRecord(draft.inspectionId);
    final signaturePath = draft.signaturePngBytes == null
        ? null
        : await _writeSignaturePng(record.id, draft.signaturePngBytes!);
    _applyFormDraft(record, draft, signaturePath: signaturePath);
    final itemKey = _draftActionItemKey;
    final photo = await _photoService.addPhoto(
      inspectionId: record.id,
      sectionKey: _draftActionSectionKey,
      itemKey: itemKey,
      source: source,
      sortOrder: record.photosForItem(itemKey).length,
      caption: draft.comment.trim().isEmpty
          ? 'Inspection evidence'
          : draft.comment.trim(),
    );
    if (photo != null) {
      record.photos.add(photo);
    }
    final saved = await repository.saveInspection(record);
    final summary = _summaryFromRecord(saved);
    _upsertSummary(summary, insertAtTop: false);
    return summary;
  }

  Future<File> generatePdfForInspection(String inspectionId) async {
    final repository = _requiredRepository();
    final record = await _requiredRecord(inspectionId);
    final outputDirectory = await _reportDirectoryProvider(record.id);
    final pdfFile = await _pdfService.generateInspectionReportFile(
      inspectionRecordToReportData(record),
      outputDirectory: outputDirectory,
    );
    record.generatedPdfPath = pdfFile.path;
    final saved = await repository.saveInspection(record);
    _upsertSummary(_summaryFromRecord(saved), insertAtTop: false);
    return pdfFile;
  }

  Future<EmailHandoffResult> sharePdfForInspection(
    String inspectionId, {
    List<String> recipients = const <String>[],
  }) async {
    final repository = _requiredRepository();
    var record = await _requiredRecord(inspectionId);
    var pdfFile = _existingGeneratedPdf(record);
    if (pdfFile == null) {
      pdfFile = await generatePdfForInspection(record.id);
      record = await _requiredRecord(inspectionId);
    }

    final validation = InspectionValidator.validateForCompletion(record);
    if (!validation.isValid) {
      throw InspectionRepositoryException(
        'Inspection must be complete before email handoff.',
        code: InspectionRepositoryErrorCode.invalidCompletion,
        validationIssues: validation.issues,
      );
    }

    final result = await _emailService.handoffPdf(
      request: EmailHandoffRequest(
        pdfFile: pdfFile,
        subject: 'CTS inspection report ${record.documentNumber}',
        body:
            'Attached is the Combined Technical Services underground mining equipment assessment report for ${record.assetName}.',
        recipients: recipients,
        customer: record.customer,
      ),
    );
    final emailed = await repository.markEmailed(record);
    _upsertSummary(_summaryFromRecord(emailed), insertAtTop: false);
    return result;
  }

  Future<BackupExportResult> exportInspectionBundle(
    String inspectionId, {
    bool generatePdfIfMissing = true,
  }) async {
    var record = await _requiredRecord(inspectionId);
    if (generatePdfIfMissing && _existingGeneratedPdf(record) == null) {
      await generatePdfForInspection(record.id);
      record = await _requiredRecord(inspectionId);
    }
    return _backupService.exportInspection(
      data: InspectionBackupData(
        inspectionJson: record.toJson(),
        documentNumber: record.documentNumber,
        customer: record.customer,
        workOrderNumber: record.workOrderNumber,
        photoFiles: record.photos
            .map((photo) => File(photo.filePath))
            .toList(growable: false),
        generatedPdfFile: _existingGeneratedPdf(record),
      ),
    );
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

  InspectionRepository _requiredRepository() {
    final repository = _repository;
    if (repository == null) {
      throw StateError(
        'This action requires the persistent inspection repository.',
      );
    }
    return repository;
  }

  Future<InspectionRecord> _requiredRecord(String inspectionId) async {
    final record = await _requiredRepository().getInspection(inspectionId);
    if (record == null) {
      throw StateError('Inspection not found: $inspectionId');
    }
    return record;
  }

  Future<String> _writeSignaturePng(
    String inspectionId,
    List<int> signaturePngBytes,
  ) async {
    final directory = await _signatureDirectoryProvider(inspectionId);
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      '${AppConstants.signatureFileName}',
    );
    await file.writeAsBytes(signaturePngBytes, flush: true);
    return file.path;
  }

  File? _existingGeneratedPdf(InspectionRecord record) {
    final path = (record.generatedPdfPath ?? '').trim();
    if (path.isEmpty) {
      return null;
    }
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  void _applyFormDraft(
    InspectionRecord record,
    InspectionFormDraft draft, {
    String? signaturePath,
  }) {
    record.customer = draft.customer.trim();
    record.mineSite = draft.mineSite.trim();
    record.siteLocation = draft.mineSite.trim();
    record.manufacturer = draft.manufacturer.trim();
    record.model = draft.model.trim();
    record.serialNumber = draft.serialNumber.trim();
    record.machineHours = draft.machineHours.trim();
    record.technicianName = draft.inspector.trim();
    record.machineType = draft.machineType;
    record.selectedPurposes = draft.selectedPurposes.toList(growable: false);
    record.healthScores = Map<String, int>.of(draft.healthScores);
    record.assetStatus = draft.assetStatus;
    record.finalRecommendation = draft.finalRecommendation;
    record.finalTechComments = draft.comment.trim();
    record.criticalAcknowledged = draft.criticalAcknowledged;
    record.assetName = _draftAssetName(draft);
    record.responses = _responsesFromDraft(record, draft);
    record.requiredItems = _requiredItemsFromDraft(record, draft);
    if (signaturePath != null) {
      record.signatureFilePath = signaturePath;
    }
    if (draft.createActionItem) {
      _ensureDraftActionItem(record, draft);
    }
  }

  List<InspectionResponse> _responsesFromDraft(
    InspectionRecord record,
    InspectionFormDraft draft,
  ) {
    final now = DateTime.now();
    final responses = <InspectionResponse>[];
    for (final section in UndergroundTemplate.sections) {
      if (section.key == 'photographic_evidence') {
        continue;
      }
      for (final itemLabel in section.items) {
        final itemKey = InspectionValidator.templateItemKey(
          section.key,
          itemLabel,
        );
        final isDraftActionItem =
            section.key == _draftActionSectionKey &&
            itemKey == _draftActionItemKey;
        final conditionRating = isDraftActionItem
            ? _conditionRatingFromDraft(draft)
            : ConditionRating.satisfactory;
        final value = isDraftActionItem
            ? _draftRatingValue(draft)
            : _valueForTemplateItem(draft, itemLabel);
        responses.add(
          InspectionResponse(
            id: _uuid.v4(),
            inspectionId: record.id,
            sectionKey: section.key,
            itemKey: itemKey,
            itemLabel: itemLabel,
            fieldType: InspectionFieldType.conditionRating,
            value: value,
            conditionRating: conditionRating,
            isFlagged:
                isDraftActionItem &&
                (draft.critical ||
                    conditionRating?.isFlagged == true ||
                    draft.rating == 'Not Inspected'),
            comment: isDraftActionItem ? draft.comment.trim() : null,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }
    return responses;
  }

  List<RequiredItemEntry> _requiredItemsFromDraft(
    InspectionRecord record,
    InspectionFormDraft draft,
  ) {
    final hasCostRow = <String>[
      draft.costComponent,
      draft.costRepair,
      draft.costAmount,
      draft.costDowntime,
    ].any((value) => value.trim().isNotEmpty);
    if (!hasCostRow) {
      return <RequiredItemEntry>[];
    }
    return <RequiredItemEntry>[
      RequiredItemEntry(
        id: _uuid.v4(),
        inspectionId: record.id,
        itemName: draft.costComponent.trim().isEmpty
            ? 'Cost forecast item'
            : draft.costComponent.trim(),
        description: draft.costRepair.trim(),
        relatedSectionItem: 'Estimated Rebuild Cost Forecast',
        notes: [
          if (draft.costAmount.trim().isNotEmpty)
            'Estimated cost (${UndergroundTemplate.currency}): '
                '${draft.costAmount.trim()}',
          if (draft.costDowntime.trim().isNotEmpty)
            'Estimated downtime: ${draft.costDowntime.trim()}',
        ].join(' | '),
      ),
    ];
  }

  void _ensureDraftActionItem(
    InspectionRecord record,
    InspectionFormDraft draft,
  ) {
    final existing = record.actionItems.any(
      (action) =>
          !action.isAutoGenerated &&
          action.sourceSectionKey == _draftActionSectionKey &&
          action.sourceItemKey == _draftActionItemKey,
    );
    if (existing) {
      return;
    }
    final now = DateTime.now();
    record.actionItems.add(
      ActionItem(
        id: _uuid.v4(),
        inspectionId: record.id,
        sourceSectionKey: _draftActionSectionKey,
        sourceItemKey: _draftActionItemKey,
        conditionRating: _conditionRatingFromDraft(draft),
        title: draft.critical
            ? 'Critical / out-of-service follow-up'
            : 'Inspection follow-up action',
        description: draft.comment.trim().isEmpty
            ? 'Review and correct the flagged inspection item.'
            : draft.comment.trim(),
        isAutoGenerated: false,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  String _valueForTemplateItem(InspectionFormDraft draft, String itemLabel) {
    return switch (itemLabel) {
      'OEM' => draft.manufacturer.trim(),
      'Model' => draft.model.trim(),
      'Serial Number' => draft.serialNumber.trim(),
      'Current Hours' => draft.machineHours.trim(),
      'Comments' => draft.comment.trim(),
      'Final CTS Recommendation' => draft.finalRecommendation,
      'CTS Inspector Typed Name' => draft.inspector.trim(),
      'CTS Inspector Drawn Signature' =>
        draft.signaturePngBytes == null ? 'Not captured' : 'Captured',
      'Component' => draft.costComponent.trim(),
      'Repair Required' => draft.costRepair.trim(),
      'Estimated Cost' => draft.costAmount.trim(),
      'Estimated Downtime' => draft.costDowntime.trim(),
      _ => 'Good',
    };
  }

  String _draftRatingValue(InspectionFormDraft draft) {
    if (draft.critical) {
      return ConditionRating.criticalOutOfService.value;
    }
    return draft.rating;
  }

  ConditionRating? _conditionRatingFromDraft(InspectionFormDraft draft) {
    if (draft.critical) {
      return ConditionRating.criticalOutOfService;
    }
    return switch (draft.rating) {
      'Good' => ConditionRating.satisfactory,
      'Fair' => ConditionRating.monitorAtRisk,
      'Poor' => ConditionRating.unsatisfactory,
      _ => null,
    };
  }

  String _draftAssetName(InspectionFormDraft draft) {
    final parts = <String>[
      draft.machineType,
      draft.manufacturer,
      draft.model,
      draft.serialNumber,
    ].map((part) => part.trim()).where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? draft.serialNumber.trim() : parts.join(' ');
  }

  static final String _draftActionSectionKey = UndergroundTemplate.sectionByKey(
    'hydraulic_system_assessment',
  ).key;
  static final String _draftActionItemKey = InspectionValidator.templateItemKey(
    _draftActionSectionKey,
    'Hydraulic Hose Inspection',
  );

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
