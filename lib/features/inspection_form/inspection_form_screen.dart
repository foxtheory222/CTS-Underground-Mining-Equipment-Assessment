import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';

import '../../core/theme.dart';
import '../../core/underground_template.dart';
import '../../core/workspace_models.dart';
import '../../core/workspace_providers.dart';
import '../../data/repositories/inspection_repository.dart';
import '../../widgets/section_card.dart';
import '../../widgets/signature_pad.dart';

class InspectionFormScreen extends ConsumerStatefulWidget {
  const InspectionFormScreen({super.key, this.seed});

  final InspectionSummary? seed;

  @override
  ConsumerState<InspectionFormScreen> createState() =>
      _InspectionFormScreenState();
}

class _InspectionFormScreenState extends ConsumerState<InspectionFormScreen> {
  late final ScrollController _scrollController;
  late final SignatureController _signatureController;
  late final TextEditingController _customer;
  late final TextEditingController _mineSite;
  late final TextEditingController _manufacturer;
  late final TextEditingController _model;
  late final TextEditingController _serialNumber;
  late final TextEditingController _machineHours;
  late final TextEditingController _inspector;
  late final TextEditingController _comment;
  late final TextEditingController _costComponent;
  late final TextEditingController _costRepair;
  late final TextEditingController _costAmount;
  late final TextEditingController _costDowntime;

  final Set<String> _selectedPurposes = <String>{'Condition Assessment'};
  final Map<String, int> _scores = <String, int>{
    for (final field in UndergroundTemplate.healthScoreFields) field.key: 7,
  };

  String _machineType = 'Rock Scaler';
  String _assetStatus = 'Good';
  String _rating = 'Good';
  String _finalRecommendation = 'Continue Operating';
  bool _critical = false;
  bool _criticalAcknowledged = false;
  bool _signed = false;
  String? _inspectionId;

  @override
  void initState() {
    super.initState();
    final seed = widget.seed;
    _inspectionId = seed?.id;
    _scrollController = ScrollController();
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: CtsPalette.orange,
      exportBackgroundColor: Colors.white,
    )..addListener(_handleSignatureChange);
    _customer = TextEditingController(text: seed?.customer ?? 'Moraine Mine');
    _mineSite = TextEditingController(
      text: seed?.siteLocation ?? 'North Decline',
    );
    _manufacturer = TextEditingController(text: 'MacLean');
    _model = TextEditingController(text: 'SL3 Scaler');
    _serialNumber = TextEditingController(text: seed?.assetName ?? 'RS-1001');
    _machineHours = TextEditingController(text: '12450');
    _inspector = TextEditingController(
      text: seed?.technicianName ?? 'R. Ellis',
    );
    _comment = TextEditingController(text: 'No active defect selected.');
    _costComponent = TextEditingController(text: 'Hydraulic pumps');
    _costRepair = TextEditingController(text: 'Reseal and bench test');
    _costAmount = TextEditingController(text: '18500');
    _costDowntime = TextEditingController(text: '2 shifts');
  }

  @override
  void dispose() {
    _signatureController.removeListener(_handleSignatureChange);
    _signatureController.dispose();
    _scrollController.dispose();
    _customer.dispose();
    _mineSite.dispose();
    _manufacturer.dispose();
    _model.dispose();
    _serialNumber.dispose();
    _machineHours.dispose();
    _inspector.dispose();
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
      setState(() => _signed = hasSignature);
    }
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
                    _HeaderBanner(isEdit: widget.seed != null),
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
    return SectionCard(
      title: 'Assessment Sections',
      subtitle:
          'Required V1 report order with transparent N/A and Not Inspected handling.',
      child: Column(
        children: [
          for (final section in UndergroundTemplate.sections)
            _SectionSummaryTile(section: section),
        ],
      ),
    );
  }

  Widget _ratingRules() {
    return SectionCard(
      title: 'Global Item Rating Rules',
      subtitle:
          'Fair, Poor, Not Inspected, and Critical states enforce documentation.',
      trailing: StatusChip(
        text: _critical ? 'Critical / Out of Service' : 'No critical toggle',
        color: _critical ? CtsPalette.danger : CtsPalette.success,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final rating in UndergroundTemplate.globalRatingOptions)
                ChoiceChip(
                  key: Key('rating_${_controlKeyPart(rating)}'),
                  label: Text(rating),
                  selected: _rating == rating,
                  onSelected: (_) => setState(() => _rating = rating),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            key: const Key('critical_switch'),
            contentPadding: EdgeInsets.zero,
            value: _critical,
            onChanged: (value) => setState(() => _critical = value),
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
                label: const Text('Attach Photo'),
              ),
              OutlinedButton.icon(
                onPressed: () => unawaited(_createActionItem()),
                icon: const Icon(Icons.assignment_turned_in_outlined),
                label: const Text('Create Action Item'),
              ),
            ],
          ),
        ],
      ),
    );
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
          'CTS inspector typed name and drawn signature are required. Customer signature is optional.',
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
              setState(() => _signed = false);
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
      return 'Photo attached to inspection evidence.';
    });
  }

  Future<void> _createActionItem() async {
    await _runFormAction(() async {
      final draft = await _buildDraft(createActionItem: true);
      await ref.read(workspaceProvider).saveFormDraft(draft);
      return 'Action item created.';
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
      signaturePngBytes: signatureBytes,
      createActionItem: createActionItem,
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
            text: 'Landscape-first',
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
  const _SectionSummaryTile({required this.section});

  final UndergroundTemplateSection section;

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
              for (final item in section.items.take(12))
                Chip(label: Text(item)),
              if (section.items.length > 12)
                Chip(label: Text('+${section.items.length - 12} more')),
            ],
          ),
        ),
      ],
    );
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
