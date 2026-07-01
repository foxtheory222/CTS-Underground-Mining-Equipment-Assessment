import 'package:flutter/material.dart';

import '../../core/app_build_metadata.dart';
import '../../core/theme.dart';
import '../../core/underground_template.dart';
import '../../widgets/section_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    this.buildMetadata = AppBuildMetadata.current,
  });

  final AppBuildMetadata buildMetadata;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionCard(
            title: 'Settings',
            subtitle:
                'Tablet-safe local workflow settings and display preferences.',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const [
                _SettingsChip(text: 'Offline-first'),
                _SettingsChip(text: 'Local storage only'),
                _SettingsChip(text: 'Landscape preferred'),
                _SettingsChip(text: 'Large touch targets'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1180;
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(child: _SettingsPanel()),
                        const SizedBox(width: 18),
                        SizedBox(
                          width: 360,
                          child: _AboutPanel(buildMetadata: buildMetadata),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        const _SettingsPanel(),
                        const SizedBox(height: 18),
                        _AboutPanel(buildMetadata: buildMetadata),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Workflow Preferences',
      subtitle: 'These settings align the UI to the current V1 tablet scope.',
      child: Column(
        children: const [
          _SettingStatusRow(
            key: Key('settings_lock_landscape'),
            icon: Icons.screen_lock_landscape_outlined,
            title: 'Landscape mode',
            subtitle: 'Optimized for 10-inch Android tablets.',
            status: 'Always on',
          ),
          _SettingStatusRow(
            key: Key('settings_compress_images'),
            icon: Icons.photo_size_select_large_outlined,
            title: 'Report image compression',
            subtitle: 'Managed photos are saved as local JPEG files.',
            status: 'Always on',
          ),
          _SettingStatusRow(
            key: Key('settings_save_recent_recipients'),
            icon: Icons.alternate_email_outlined,
            title: 'Recent recipients',
            subtitle: 'Recipient history is stored in the local database.',
            status: 'Always on',
          ),
          _SettingStatusRow(
            key: Key('settings_branded_theme'),
            icon: Icons.palette_outlined,
            title: 'CTS theme',
            subtitle: 'Combined Technical Services branding is fixed for V1.',
            status: 'Always on',
          ),
        ],
      ),
    );
  }
}

class _AboutPanel extends StatelessWidget {
  const _AboutPanel({required this.buildMetadata});

  final AppBuildMetadata buildMetadata;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'About / Version',
      subtitle: 'Android tablet local-only V1',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Note(text: buildMetadata.versionLabel),
          const _Note(
            text: 'Template version ${UndergroundTemplate.templateVersion}',
          ),
          const _Note(text: UndergroundTemplate.templateKey),
          _Note(text: buildMetadata.buildDateLabel),
          const SizedBox(height: 12),
          Text(
            UndergroundTemplate.reportTitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          const _Note(text: 'Public Sans headings with Inter body text.'),
          const _Note(
            text:
                'Navy branded header with light, high-contrast field '
                'screens and safety orange accents.',
          ),
          const _Note(text: 'No login, cloud sync, GPS, or remote logging.'),
        ],
      ),
    );
  }
}

class _SettingStatusRow extends StatelessWidget {
  const _SettingStatusRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: CtsPalette.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: CtsPalette.orange),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(subtitle),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _StatusPill(text: status),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CtsPalette.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CtsPalette.success.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: CtsPalette.success,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.fiber_manual_record,
            size: 10,
            color: CtsPalette.orange,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _SettingsChip extends StatelessWidget {
  const _SettingsChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(text),
      backgroundColor: CtsPalette.orange.withValues(alpha: 0.12),
      side: BorderSide(color: CtsPalette.orange.withValues(alpha: 0.24)),
    );
  }
}
