import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';

import '../../core/theme.dart';
import '../../core/underground_template.dart';
import '../../core/validators.dart';
import '../../core/workspace_models.dart';
import '../../core/workspace_providers.dart';
import '../../data/models/inspection_enums.dart';
import '../../data/models/inspection_models.dart';
import '../../data/repositories/inspection_repository.dart';
import '../../widgets/section_card.dart';
import '../../widgets/signature_pad.dart';

class InspectionFormScreen extends ConsumerStatefulWidget {
  const InspectionFormScreen({super.key, this.seed, this.inspectionId});

  final InspectionSummary? seed;
  final String? inspectionId;

  @override
  ConsumerState<InspectionFormScreen> createState() =>
      _InspectionFormScreenState();
}

class _InspectionFormScreenState extends ConsumerState<InspectionFormScreen> {
  late final ScrollController _scrollController;
  late final SignatureController _signatureController;
  late final SignatureController _customerSignatureController;
  late final TextEditingController _customer;
  late final TextEditingController _mineSite;
  late final TextEditingController _manufacturer;
  late final TextEditingController _model;
  late final TextEditingController _serialNumber;
  late final TextEditingController _machineHours;
  late final TextEditingController _inspector;
  late final TextEditingController _customerRepresentative;
  late final TextEditingController _customerUnavailableNote;
  late final TextEditingController _comment;
  late final TextEditingController _costComponent;
  late final TextEditingController _costRepair;
  late final TextEditingController _costAmount;
  late final TextEditingController _costDowntime;

  final Set<String> _selectedPurposes = <String>{'Condition Assessment'};
  final Map<String, int> _scores = <String, int>{
    for (final field in UndergroundTemplate.healthScoreFields) field.key: 7,
  };
  final Map<String, String> _itemRatings = <String, String>{};
  final Map<String, String> _itemComments = <String, String>{};
  final Map<String, String> _itemValues = <String, String>{};

  String _machineType = 'Rock Scaler';
  String _assetStatus = 'Good';
  String _rating = 'Good';
  String _finalRecommendation = 'Continue Operating';
  bool _critical = false;
  bool _criticalAcknowledged = false;
  bool _signed = false;
  bool _customerSigned = false;
  bool _technicianSignatureCleared = false;
  bool _customerSignatureCleared = false;
  String? _activeFindingSectionKey;
  String? _activeFindingItemKey;
  String? _activeFindingItemLabel;
  String? _inspectionId;

  @override
  void initState() {
    super.initState();
    final seed = widget.seed;
    _inspectionId = seed?.id ?? widget.inspectionId;
    _scrollController = ScrollController();
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: CtsPalette.orange,
      exportBackgroundColor: Colors.white,
    )..addListener(_handleSignatureChange);
    _customerSignatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: CtsPalette.orange,
      exportBackgroundColor: Colors.white,
    )..addListener(_handleCustomerSignatureChange);
    _customer = TextEditingController(text: seed?.customer ?? '');
    _mineSite = TextEditingController(text: seed?.siteLocation ?? '');
    _manufacturer = TextEditingController();
    _model = TextEditingController();
    _serialNumber = TextEditingController(text: seed?.assetName ?? '');
    _machineHours = TextEditingController();
    _inspector = TextEditingController(text: seed?.technicianName ?? '');
    _customerRepresentative = TextEditingController();
    _customerUnavailableNote = TextEditingController();
    _comment = TextEditingController();
    _costComponent = TextEditingController();
    _costRepair = TextEditingController();
    _costAmount = TextEditingController();
    _costDowntime = TextEditingController();
    final inspectionId = _inspectionId;
    if (inspectionId != null) {
      unawaited(_hydrateInspection(inspectionId));
    }
  }

  @override
  void dispose() {
    _signatureController.removeListener(_handleSignatureChange);
    _signatureController.dispose();
    _customerSignatureController.removeListener(_handleCustomerSignatureChange);
    _customerSignatureController.dispose();
    _scrollController.dispose();
    _customer.dispose();
    _mineSite.dispose();
    _manufacturer.dispose();
    _model.dispose();
    _serialNumber.dispose();
    _machineHours.dispose();
    _inspector.dispose();
    _customerRepresentative.dispose();
    _customerUnavailableNote.dispose();
    _comment.dispose();
    _costComponent.dispose();
    _costRepair.dispose();
    _costAmount.dispose();
    _costDowntime.dispose();
    super.dispose();
  }

  void _handleSignatureChange() {
    final bool hasSignature = _signatureController.isNotEmpty;
    if (hasSignature != _signed && mounted) {
      setState(() {
        _signed = hasSignature;
        if (hasSignature) {
          _technicianSignatureCleared = false;
        }
      });
    }
  }

  void _handleCustomerSignatureChange() {
    final bool hasSignature = _customerSignatureController.isNotEmpty;
    if (hasSignature != _customerSigned && mounted) {
      setState(() {
        _customerSigned = hasSignature;
        if (hasSignature) {
          _customerSignatureCleared = false;
        }
      });
    }
  }

  Future<void> _hydrateInspection(String inspectionId) async {
    final record = await ref
        .read(workspaceProvider)
        .inspectionRecordById(inspectionId);
    if (!mounted || record == null) {
      return;
    }
    setState(() => _applyRecord(record));
  }

  void _applyRecord(InspectionRecord record) {
    _inspectionId = record.id;
    _customer.text = record.customer;
    _mineSite.text = record.mineSite;
    _manufacturer.text = record.manufacturer;
    _model.text = record.model;
    _serialNumber.text = record.serialNumber;
    _machineHours.text = record.machineHours;
    _inspector.text = record.technicianName;
    _comment.text = record.finalTechComments;
    if (record.selectedPurposes.isNotEmpty) {
      _selectedPurposes
        ..clear()
        ..addAll(record.selectedPurposes);
    }
    for (final field in UndergroundTemplate.healthScoreFields) {
      final score = record.healthScores[field.key];
      if (score != null) {
        _scores[field.key] = score;
      }
    }
    if (UndergroundTemplate.machineTypes.contains(record.machineType)) {
      _machineType = record.machineType;
    }
    if (UndergroundTemplate.assetStatusOptions.contains(record.assetStatus)) {
      _assetStatus = record.assetStatus;
    }
    if (UndergroundTemplate.finalRecommendationOptions.contains(
      record.finalRecommendation,
    )) {
      _finalRecommendation = record.finalRecommendation;
    }
    _criticalAcknowledged = record.criticalAcknowledged;
    _signed = (record.signatureFilePath ?? '').trim().isNotEmpty;
    _customerSigned = (record.customerSignatureFilePath ?? '')
        .trim()
        .isNotEmpty;
    _technicianSignatureCleared = false;
    _customerSignatureCleared = false;

    _itemRatings.clear();
    _itemComments.clear();
    _itemValues.clear();
    for (final response in record.responses) {
      if (!UndergroundTemplate.isConditionChecklistSectionKey(
        response.sectionKey,
      )) {
        final value = response.value?.trim();
        if (value != null && value.isNotEmpty) {
          _itemValues[response.itemKey] = value;
        }
        continue;
      }
      final rating = _ratingFromResponse(response);
      if (rating != null) {
        _itemRatings[response.itemKey] = rating;
      }
      final comment = response.comment?.trim();
      if (comment != null && comment.isNotEmpty) {
        _itemComments[response.itemKey] = comment;
      }
    }
    _critical = _itemRatings.values.contains('Critical / Out of Service');
    final defaultFindingRating = _itemRatings[_defaultFindingItemKey];
    if (defaultFindingRating != null) {
      _rating = defaultFindingRating;
    }
    _customerRepresentative.text =
        _itemValues[_customerRepresentativeItemKey] ?? '';
    _customerUnavailableNote.text =
        _itemValues[_customerUnavailableNoteItemKey] ?? '';

    if (record.requiredItems.isNotEmpty) {
      final requiredItem = record.requiredItems.first;
      _costComponent.text = requiredItem.itemName ?? '';
      _costRepair.text = requiredItem.description ?? '';
      final notes = requiredItem.notes ?? '';
      _costAmount.text = _extractCostNoteValue(notes, 'Estimated cost');
      _costDowntime.text = _extractCostNoteValue(notes, 'Estimated downtime');
    }
  }

  String? _ratingFromResponse(InspectionResponse response) {
    final value = (response.value ?? '').trim();
    if (UndergroundTemplate.globalRatingOptions.contains(value)) {
      return value;
    }
    return switch (response.conditionRating) {
      ConditionRating.satisfactory => 'Good',
      ConditionRating.monitorAtRisk => 'Fair',
      ConditionRating.unsatisfactory => 'Poor',
      ConditionRating.criticalOutOfService => 'Critical / Out of Service',
      null => null,
    };
  }

  String _extractCostNoteValue(String notes, String label) {
    for (final part in notes.split('|')) {
      final trimmed = part.trim();
      if (!trimmed.startsWith(label)) {
        continue;
      }
      final separator = trimmed.indexOf(':');
      if (separator == -1) {
        return '';
      }
      return trimmed.substring(separator + 1).trim();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showRail = constraints.maxWidth >= 1100;
        final showSummary = constraints.maxWidth >= 1360;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showRail) ...[
              SizedBox(width: 286, child: _SectionRail(onJump: _jumpToTop)),
              const SizedBox(width: 18),
            ],
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderBanner(isEdit: _inspectionId != null),
                    const SizedBox(height: 18),
                    _machineIdentification(),
                    const SizedBox(height: 18),
                    _healthScores(),
                    const SizedBox(height: 18),
                    _templateSections(),
                    const SizedBox(height: 18),
                    _ratingRules(),
                    const SizedBox(height: 18),
                    _machineSpecificSystems(),
                    const SizedBox(height: 18),
                    _recommendationsAndCost(),
                    const SizedBox(height: 18),
                    _signoff(),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
            if (showSummary) ...[
              const SizedBox(width: 18),
              SizedBox(width: 360, child: _reviewSummary()),
            ],
          ],
        );
      },
    );
  }

  Widget _machineIdentification() {
    return SectionCard(
      title: 'SECTION 1 - MACHINE IDENTIFICATION',
      subtitle:
          'Header details, purpose, machine type, hours, and required asset identity.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldGrid(<Widget>[
            _textField(_customer, 'Customer'),
            _textField(_mineSite, 'Mine Site'),
            _textField(_manufacturer, 'Manufacturer'),
            _textField(_model, 'Model'),
            _textField(_serialNumber, 'Serial Number or Asset ID'),
            _textField(_machineHours, 'Machine Hours', number: true),
            _textField(_inspector, 'CTS Inspector'),
          ]),
          const SizedBox(height: 18),
          _subhead('Purpose of Inspection'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final purpose in UndergroundTemplate.purposeOptions)
                FilterChip(
                  key: Key('purpose_${_controlKeyPart(purpose)}'),
                  label: Text(purpose),
                  selected: _selectedPurposes.contains(purpose),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedPurposes.add(purpose);
                      } else if (_selectedPurposes.length > 1) {
                        _selectedPurposes.remove(purpose);
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 18),
          _subhead('Machine Type'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final machineType in UndergroundTemplate.machineTypes)
                ChoiceChip(
                  key: Key('machine_${_controlKeyPart(machineType)}'),
                  label: Text(machineType),
                  selected: _machineType == machineType,
                  onSelected: (_) => setState(() => _machineType = machineType),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _healthScores() {
    return SectionCard(
      title: 'Machine Health Score',
      subtitle:
          'Manual scores only. Overall Asset Health is not calculated automatically.',
      trailing: StatusChip(
        text: 'Asset Status: $_assetStatus',
        color: _statusColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final status in UndergroundTemplate.assetStatusOptions)
                ChoiceChip(
                  key: Key('asset_status_${_controlKeyPart(status)}'),
                  label: Text(status),
                  selected: _assetStatus == status,
                  onSelected: (_) => setState(() => _assetStatus = status),
                ),
            ],
          ),
          const SizedBox(height: 18),
          for (final scoreField in UndergroundTemplate.healthScoreFields)
            _scoreSlider(scoreField),
        ],
      ),
    );
  }

  Widget _templateSections() {
    final checklistTotal = UndergroundTemplate.conditionChecklistSections.fold(
      0,
      (total, section) => total + section.items.length,
    );
    final narrativeTotal = UndergroundTemplate.narrativeSections.fold(
      0,
      (total, section) => total + section.items.length,
    );
    final completedNarratives = UndergroundTemplate.narrativeSections.fold(
      0,
      (total, section) =>
          total +
          section.items.where((item) {
            final value = _itemValues[_itemKey(section, item)]?.trim();
            return value != null && value.isNotEmpty;
          }).length,
    );
    return SectionCard(
      title: 'Assessment Sections',
      subtitle:
          'Rate each checklist item explicitly and record narrative results. '
          'Use N/A or Not Inspected only when that is the field finding.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(
                text: 'Checklist ${_itemRatings.length} / $checklistTotal',
                color: _itemRatings.length == checklistTotal
                    ? CtsPalette.success
                    : CtsPalette.warning,
              ),
              StatusChip(
                text: 'Narrative $completedNarratives / $narrativeTotal',
                color: completedNarratives == narrativeTotal
                    ? CtsPalette.success
                    : CtsPalette.warning,
              ),
              OutlinedButton.icon(
                key: const Key('mark_unreviewed_good_button'),
                onPressed: _markUnreviewedChecklistGood,
                icon: const Icon(Icons.done_all_outlined),
                label: const Text('Mark unreviewed Good'),
              ),
              OutlinedButton.icon(
                key: const Key('mark_unrecorded_narrative_na_button'),
                onPressed: _markUnrecordedNarrativesNotApplicable,
                icon: const Icon(Icons.not_interested_outlined),
                label: const Text('Mark unrecorded N/A'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final section in UndergroundTemplate.conditionChecklistSections)
            _SectionSummaryTile(
              section: section,
              onItemPressed: _openChecklistPrompt,
              ratingFor: _ratingForItem,
            ),
          const Divider(height: 28),
          Text(
            'Condition monitoring, life extension, and rebuild notes',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final section in UndergroundTemplate.narrativeSections)
            _NarrativeSectionTile(
              section: section,
              onItemPressed: _openNarrativePrompt,
              valueFor: _valueForNarrativeItem,
            ),
        ],
      ),
    );
  }

  String _itemKey(UndergroundTemplateSection section, String itemLabel) {
    return InspectionValidator.templateItemKey(section.key, itemLabel);
  }

  String get _defaultFindingSectionKey =>
      UndergroundTemplate.sectionByKey('hydraulic_system_assessment').key;

  String get _defaultFindingItemKey => InspectionValidator.templateItemKey(
    _defaultFindingSectionKey,
    _defaultFindingItemLabel,
  );

  String get _currentFindingSectionKey =>
      _activeFindingSectionKey ?? _defaultFindingSectionKey;

  String get _currentFindingItemKey =>
      _activeFindingItemKey ?? _defaultFindingItemKey;

  String get _currentFindingItemLabel =>
      _activeFindingItemLabel ?? _defaultFindingItemLabel;

  String get _customerRepresentativeItemKey =>
      InspectionValidator.templateItemKey(
        'final_recommendation_signoff',
        'Customer Representative Name',
      );

  String get _customerUnavailableNoteItemKey =>
      InspectionValidator.templateItemKey(
        'final_recommendation_signoff',
        'Customer Unavailable / Declined Note',
      );

  static const String _defaultFindingItemLabel = 'Hydraulic Hose Inspection';

  String? _ratingForItem(UndergroundTemplateSection section, String itemLabel) {
    return _itemRatings[_itemKey(section, itemLabel)];
  }

  String? _valueForNarrativeItem(
    UndergroundTemplateSection section,
    String itemLabel,
  ) {
    return _itemValues[_itemKey(section, itemLabel)];
  }

  Future<void> _markUnreviewedChecklistGood() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark unreviewed items Good?'),
        content: const Text(
          'Only use this after physically reviewing every remaining item. '
          'Existing Fair, Poor, Critical, N/A, and Not Inspected findings '
          'will not be changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_mark_unreviewed_good'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm reviewed'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      for (final section in UndergroundTemplate.conditionChecklistSections) {
        for (final item in section.items) {
          _itemRatings.putIfAbsent(_itemKey(section, item), () => 'Good');
        }
      }
    });
  }

  Future<void> _markUnrecordedNarrativesNotApplicable() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark unrecorded narrative fields N/A?'),
        content: const Text(
          'Use this only when the remaining condition-monitoring, '
          'life-extension, and rebuild fields genuinely do not apply. '
          'Existing notes will not be changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_mark_unrecorded_narrative_na'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm N/A'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      for (final section in UndergroundTemplate.narrativeSections) {
        for (final item in section.items) {
          _itemValues.putIfAbsent(_itemKey(section, item), () => 'N/A');
        }
      }
    });
  }

  Future<void> _openNarrativePrompt(
    UndergroundTemplateSection section,
    String itemLabel,
  ) async {
    final key = _itemKey(section, itemLabel);
    final valueController = TextEditingController(text: _itemValues[key] ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(itemLabel),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: valueController,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Result / finding',
              hintText: 'Enter the result, observation, or N/A',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final value = valueController.text.trim();
    valueController.dispose();
    if (saved == true && mounted) {
      setState(() {
        if (value.isEmpty) {
          _itemValues.remove(key);
        } else {
          _itemValues[key] = value;
        }
      });
    }
  }

  Future<void> _openChecklistPrompt(
    UndergroundTemplateSection section,
    String itemLabel,
  ) async {
    final key = _itemKey(section, itemLabel);
    var selectedRating = _itemRatings[key] ?? 'Good';
    final commentController = TextEditingController(
      text: _itemComments[key] ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('$itemLabel prompt'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedRating,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Condition rating',
                  ),
                  selectedItemBuilder: (context) => UndergroundTemplate
                      .globalRatingOptions
                      .map(
                        (rating) =>
                            Text(rating, overflow: TextOverflow.ellipsis),
                      )
                      .toList(growable: false),
                  items: UndergroundTemplate.globalRatingOptions
                      .map(
                        (rating) => DropdownMenuItem(
                          value: rating,
                          child: Text(rating, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedRating = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Item comment'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        _itemRatings[key] = selectedRating;
        _itemComments[key] = commentController.text.trim();
        _activeFindingSectionKey = section.key;
        _activeFindingItemKey = key;
        _activeFindingItemLabel = itemLabel;
        if (selectedRating != 'Critical / Out of Service') {
          _rating = selectedRating;
        }
        _critical = _itemRatings.values.contains('Critical / Out of Service');
        if (!_critical) {
          _criticalAcknowledged = false;
        }
      });
    }
    commentController.dispose();
  }

  Widget _ratingRules() {
    return SectionCard(
      title: 'Selected Finding Controls',
      subtitle:
          'Select a checklist item first, then use these focused controls to '
          'record its rating, evidence, and follow-up.',
      trailing: StatusChip(
        text: _critical ? 'Critical / Out of Service' : 'No critical toggle',
        color: _critical ? CtsPalette.danger : CtsPalette.success,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Active finding: $_currentFindingItemLabel',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final rating in UndergroundTemplate.globalRatingOptions)
                ChoiceChip(
                  key: Key('rating_${_controlKeyPart(rating)}'),
                  label: Text(rating),
                  selected: _rating == rating,
                  onSelected: (_) => _setCurrentFindingRating(rating),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            key: const Key('critical_switch'),
            contentPadding: EdgeInsets.zero,
            value: _critical,
            onChanged: _setCurrentFindingCritical,
            title: const Text('Critical / Out of Service'),
            subtitle: const Text(
              'Requires comment, photo, action item, and escalation acknowledgement.',
            ),
            activeThumbColor: CtsPalette.orange,
          ),
          if (_critical)
            CheckboxListTile(
              key: const Key('critical_ack_checkbox'),
              contentPadding: EdgeInsets.zero,
              value: _criticalAcknowledged,
              onChanged: (value) {
                setState(() => _criticalAcknowledged = value ?? false);
              },
              title: const Text(
                'Inspector acknowledges critical/out-of-service item has been communicated/escalated according to CTS/site procedure.',
              ),
            ),
          TextField(
            controller: _comment,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Required comment / observation',
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => unawaited(_attachPhoto()),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Attach Photo to Finding'),
              ),
              OutlinedButton.icon(
                onPressed: () => unawaited(_createActionItem()),
                icon: const Icon(Icons.assignment_turned_in_outlined),
                label: const Text('Create Finding Action'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setCurrentFindingRating(String rating) {
    setState(() {
      _rating = rating;
      _itemRatings[_currentFindingItemKey] = rating;
      _activeFindingSectionKey = _currentFindingSectionKey;
      _activeFindingItemKey = _currentFindingItemKey;
      _activeFindingItemLabel = _currentFindingItemLabel;
      _critical = _itemRatings.values.contains('Critical / Out of Service');
      if (!_critical) {
        _criticalAcknowledged = false;
      }
    });
  }

  void _setCurrentFindingCritical(bool value) {
    setState(() {
      _activeFindingSectionKey = _currentFindingSectionKey;
      _activeFindingItemKey = _currentFindingItemKey;
      _activeFindingItemLabel = _currentFindingItemLabel;
      _itemRatings[_currentFindingItemKey] = value
          ? 'Critical / Out of Service'
          : (_rating == 'Critical / Out of Service' ? 'Good' : _rating);
      _critical = _itemRatings.values.contains('Critical / Out of Service');
      if (!_critical) {
        _criticalAcknowledged = false;
      }
    });
  }

  Widget _machineSpecificSystems() {
    final items = UndergroundTemplate.machineSpecificItems[_machineType]!;
    return SectionCard(
      title: 'SECTION 9B - MACHINE SPECIFIC SYSTEMS',
      subtitle:
          'Conditional checklist content changes with the selected machine type.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected: $_machineType',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [for (final item in items) Chip(label: Text(item))],
          ),
        ],
      ),
    );
  }

  Widget _recommendationsAndCost() {
    return SectionCard(
      title: 'Final CTS Recommendation',
      subtitle:
          'USD forecast rows and final recommendation are required before completion.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final recommendation
                  in UndergroundTemplate.finalRecommendationOptions)
                ChoiceChip(
                  key: Key('recommendation_${_controlKeyPart(recommendation)}'),
                  label: Text(recommendation),
                  selected: _finalRecommendation == recommendation,
                  onSelected: (_) {
                    setState(() => _finalRecommendation = recommendation);
                  },
                ),
            ],
          ),
          const SizedBox(height: 18),
          _subhead('SECTION 13 - ESTIMATED REBUILD COST FORECAST'),
          const SizedBox(height: 10),
          _fieldGrid(<Widget>[
            _textField(_costComponent, 'Component'),
            _textField(_costRepair, 'Repair Required'),
            _textField(_costAmount, 'Estimated Cost (USD)', number: true),
            _textField(_costDowntime, 'Estimated Downtime'),
          ]),
        ],
      ),
    );
  }

  Widget _signoff() {
    return SectionCard(
      title: 'SIGNOFF',
      subtitle:
          'CTS inspector typed name and drawn signature are required. '
          'Customer sign-off is optional and can be documented or declined.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _textField(_inspector, 'CTS Inspector Typed Name'),
          const SizedBox(height: 16),
          SignaturePad(
            controller: _signatureController,
            isSigned: _signed,
            onClear: () {
              _signatureController.clear();
              setState(() {
                _signed = false;
                _technicianSignatureCleared = true;
              });
            },
          ),
          const SizedBox(height: 18),
          _fieldGrid(<Widget>[
            _textField(
              _customerRepresentative,
              'Customer Representative Name (optional)',
            ),
            _textField(
              _customerUnavailableNote,
              'Customer Unavailable / Declined Note',
            ),
          ]),
          const SizedBox(height: 16),
          SignaturePad(
            title: 'Customer signature',
            controller: _customerSignatureController,
            isSigned: _customerSigned,
            padKey: const Key('customer_signature_pad_area'),
            inputKey: const Key('customer_signature_input_area'),
            onClear: () {
              _customerSignatureController.clear();
              setState(() {
                _customerSigned = false;
                _customerSignatureCleared = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _reviewSummary() {
    final missing = <String>[
      if (_selectedPurposes.isEmpty) 'Purpose of inspection',
      if (!_signed) 'Inspector signature',
      if (_critical && !_criticalAcknowledged) 'Critical acknowledgement',
    ];
    return SectionCard(
      title: 'Review Summary',
      subtitle: 'Validation, photos, actions, and report handoff.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryLine('Template', UndergroundTemplate.templateVersion),
          _summaryLine('Machine type', _machineType),
          _summaryLine(
            'Rating',
            _critical ? 'Critical / Out of Service' : _rating,
          ),
          _summaryLine('Photos', _critical ? 'Required' : 'Optional'),
          _summaryLine(
            'Action items',
            _critical || _rating == 'Poor' ? 'Required' : 'As needed',
          ),
          _summaryLine('Recommendation', _finalRecommendation),
          const SizedBox(height: 14),
          if (missing.isEmpty)
            const StatusChip(
              text: 'Ready for PDF review',
              color: CtsPalette.success,
            )
          else
            for (final issue in missing)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Missing: $issue'),
              ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => unawaited(_generatePdf()),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Generate PDF'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => unawaited(_shareEmailHandoff()),
            icon: const Icon(Icons.ios_share_outlined),
            label: const Text('Share / Email Handoff'),
          ),
        ],
      ),
    );
  }

  Widget _scoreSlider(UndergroundHealthScoreField field) {
    final score = _scores[field.key] ?? field.min;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  field.label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '$score / ${field.max}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
          Slider(
            key: Key('score_slider_${field.key}'),
            value: score.toDouble(),
            min: field.min.toDouble(),
            max: field.max.toDouble(),
            divisions: field.max - field.min,
            label: score.toString(),
            onChanged: (value) {
              setState(() => _scores[field.key] = value.round());
            },
          ),
        ],
      ),
    );
  }

  String _controlKeyPart(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  Widget _fieldGrid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 900
            ? (constraints.maxWidth - 24) / 3
            : constraints.maxWidth >= 580
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool number = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _subhead(String text) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }

  Widget _summaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Color get _statusColor {
    return switch (_assetStatus) {
      'Excellent' || 'Good' => CtsPalette.success,
      'Fair' => CtsPalette.warning,
      'Poor' || 'Immediate Rebuild Required' => CtsPalette.danger,
      _ => CtsPalette.slate,
    };
  }

  void _jumpToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  Future<void> _attachPhoto() async {
    await _runFormAction(() async {
      final draft = await _buildDraft();
      await ref.read(workspaceProvider).attachPhotoForDraft(draft);
      return 'Photo attached to $_currentFindingItemLabel.';
    });
  }

  Future<void> _createActionItem() async {
    await _runFormAction(() async {
      final draft = await _buildDraft(createActionItem: true);
      await ref.read(workspaceProvider).saveFormDraft(draft);
      return 'Action item created for $_currentFindingItemLabel.';
    });
  }

  Future<void> _generatePdf() async {
    await _runFormAction(() async {
      final draft = await _buildDraft();
      final saved = await ref.read(workspaceProvider).saveFormDraft(draft);
      final file = await ref
          .read(workspaceProvider)
          .generatePdfForInspection(saved.id);
      return 'PDF generated: ${file.path}';
    });
  }

  Future<void> _shareEmailHandoff() async {
    await _runFormAction(() async {
      final draft = await _buildDraft();
      final saved = await ref.read(workspaceProvider).saveFormDraft(draft);
      final result = await ref
          .read(workspaceProvider)
          .sharePdfForInspection(saved.id);
      return 'Email/share handoff opened: ${result.attachmentPath}';
    });
  }

  Future<void> _runFormAction(Future<String> Function() action) async {
    try {
      final message = await action();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_formActionError(error))));
      }
    }
  }

  String _formActionError(Object error) {
    if (error is InspectionRepositoryException &&
        error.validationIssues.isNotEmpty) {
      return error.validationIssues.first.message;
    }
    return error.toString();
  }

  Future<InspectionFormDraft> _buildDraft({
    bool createActionItem = false,
  }) async {
    final signatureBytes = _signatureController.isNotEmpty
        ? await _signatureController.toPngBytes()
        : null;
    final customerSignatureBytes = _customerSignatureController.isNotEmpty
        ? await _customerSignatureController.toPngBytes()
        : null;
    final itemValues = Map<String, String>.of(_itemValues);
    final customerRepresentative = _customerRepresentative.text.trim();
    final customerUnavailableNote = _customerUnavailableNote.text.trim();
    if (customerRepresentative.isEmpty) {
      itemValues.remove(_customerRepresentativeItemKey);
    } else {
      itemValues[_customerRepresentativeItemKey] = customerRepresentative;
    }
    if (customerUnavailableNote.isEmpty) {
      itemValues.remove(_customerUnavailableNoteItemKey);
    } else {
      itemValues[_customerUnavailableNoteItemKey] = customerUnavailableNote;
    }
    return InspectionFormDraft(
      inspectionId: await _ensureInspectionId(),
      customer: _customer.text,
      mineSite: _mineSite.text,
      manufacturer: _manufacturer.text,
      model: _model.text,
      serialNumber: _serialNumber.text,
      machineHours: _machineHours.text,
      inspector: _inspector.text,
      selectedPurposes: Set<String>.of(_selectedPurposes),
      healthScores: Map<String, int>.of(_scores),
      machineType: _machineType,
      assetStatus: _assetStatus,
      rating: _rating,
      finalRecommendation: _finalRecommendation,
      critical: _critical,
      criticalAcknowledged: _criticalAcknowledged,
      comment: _comment.text,
      costComponent: _costComponent.text,
      costRepair: _costRepair.text,
      costAmount: _costAmount.text,
      costDowntime: _costDowntime.text,
      itemRatings: Map<String, String>.of(_itemRatings),
      itemComments: Map<String, String>.of(_itemComments),
      itemValues: itemValues,
      signaturePngBytes: signatureBytes,
      customerSignaturePngBytes: customerSignatureBytes,
      clearTechnicianSignature: _technicianSignatureCleared,
      clearCustomerSignature: _customerSignatureCleared,
      createActionItem: createActionItem,
      actionSectionKey: _currentFindingSectionKey,
      actionItemKey: _currentFindingItemKey,
      actionItemLabel: _currentFindingItemLabel,
    );
  }

  Future<String> _ensureInspectionId() async {
    final existing = _inspectionId;
    if (existing != null) {
      return existing;
    }
    final inspection = await ref.read(workspaceProvider).createInspection();
    _inspectionId = inspection.id;
    return inspection.id;
  }
}

class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner({required this.isEdit});

  final bool isEdit;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: isEdit ? 'Edit Assessment' : 'New Underground Mining Assessment',
      subtitle: UndergroundTemplate.reportTitle,
      trailing: const StatusChip(
        text: 'Local-only V1',
        color: CtsPalette.success,
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: const [
          _FeatureChip(icon: Icons.tablet_android, text: 'Android tablet'),
          _FeatureChip(
            icon: Icons.screen_rotation_alt,
            text: 'Adaptive layout',
          ),
          _FeatureChip(icon: Icons.storage, text: 'SQLite local storage'),
          _FeatureChip(icon: Icons.picture_as_pdf, text: 'Local PDF'),
          _FeatureChip(icon: Icons.archive_outlined, text: 'Export / Import'),
        ],
      ),
    );
  }
}

class _SectionRail extends StatelessWidget {
  const _SectionRail({required this.onJump});

  final VoidCallback onJump;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SectionCard(
        title: 'Sections',
        subtitle: 'Report order',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: onJump,
              icon: const Icon(Icons.vertical_align_top),
              label: const Text('Top'),
            ),
            const SizedBox(height: 12),
            for (final section in UndergroundTemplate.sections)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  section.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionSummaryTile extends StatelessWidget {
  const _SectionSummaryTile({
    required this.section,
    required this.onItemPressed,
    required this.ratingFor,
  });

  final UndergroundTemplateSection section;
  final void Function(UndergroundTemplateSection section, String itemLabel)
  onItemPressed;
  final String? Function(UndergroundTemplateSection section, String itemLabel)
  ratingFor;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(section.title),
      subtitle: Text('${section.items.length} checklist fields'),
      childrenPadding: const EdgeInsets.only(left: 12, bottom: 12),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in section.items)
                _ChecklistItemChip(
                  itemLabel: item,
                  rating: ratingFor(section, item),
                  onPressed: () => onItemPressed(section, item),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NarrativeSectionTile extends StatelessWidget {
  const _NarrativeSectionTile({
    required this.section,
    required this.onItemPressed,
    required this.valueFor,
  });

  final UndergroundTemplateSection section;
  final void Function(UndergroundTemplateSection section, String itemLabel)
  onItemPressed;
  final String? Function(UndergroundTemplateSection section, String itemLabel)
  valueFor;

  @override
  Widget build(BuildContext context) {
    final completed = section.items
        .where((item) => (valueFor(section, item) ?? '').trim().isNotEmpty)
        .length;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(section.title),
      subtitle: Text('$completed / ${section.items.length} results recorded'),
      childrenPadding: const EdgeInsets.only(left: 12, bottom: 12),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in section.items)
                _NarrativeItemChip(
                  itemLabel: item,
                  value: valueFor(section, item),
                  onPressed: () => onItemPressed(section, item),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NarrativeItemChip extends StatelessWidget {
  const _NarrativeItemChip({
    required this.itemLabel,
    required this.value,
    required this.onPressed,
  });

  final String itemLabel;
  final String? value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final hasValue = (value ?? '').trim().isNotEmpty;
    final color = hasValue ? CtsPalette.info : null;
    return ActionChip(
      backgroundColor: color?.withValues(alpha: 0.12),
      side: BorderSide(
        color: color ?? Theme.of(context).colorScheme.outlineVariant,
      ),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(itemLabel, overflow: TextOverflow.ellipsis),
            if (hasValue)
              Text(
                value!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
      onPressed: onPressed,
    );
  }
}

class _ChecklistItemChip extends StatelessWidget {
  const _ChecklistItemChip({
    required this.itemLabel,
    required this.rating,
    required this.onPressed,
  });

  final String itemLabel;
  final String? rating;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ratingColor = rating == null ? null : _ratingColor(rating!);
    return ActionChip(
      backgroundColor: ratingColor?.withValues(alpha: 0.12),
      side: BorderSide(
        color: ratingColor ?? Theme.of(context).colorScheme.outlineVariant,
      ),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(itemLabel, overflow: TextOverflow.ellipsis),
            if (rating != null)
              Text(
                rating!,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: ratingColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
      onPressed: onPressed,
    );
  }

  Color _ratingColor(String rating) {
    return switch (rating) {
      'Good' => CtsPalette.success,
      'Fair' => CtsPalette.warning,
      'Poor' ||
      'Critical / Out of Service' ||
      'Not Inspected' => CtsPalette.danger,
      'N/A' => CtsPalette.info,
      _ => CtsPalette.slate,
    };
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(text),
      backgroundColor: CtsPalette.orange.withValues(alpha: 0.12),
      side: BorderSide(color: CtsPalette.orange.withValues(alpha: 0.24)),
    );
  }
}
