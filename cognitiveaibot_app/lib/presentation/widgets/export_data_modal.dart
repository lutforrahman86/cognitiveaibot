import 'package:flutter/material.dart';

import '../../core/theme/cognitive_aibot_theme.dart';

/// Format options for export
enum ExportFormat {
  csv,
  json,
  pdf,
}

/// Modal dialog for exporting data - matches the design with file format selection
class ExportDataModal extends StatefulWidget {
  const ExportDataModal({
    super.key,
    this.title = 'Export Usage Data',
    this.description =
        'Select your preferred file format to download your organization\'s usage history from the last 30 days.',
    this.onExport,
  });

  final String title;
  final String description;
  final ValueChanged<ExportFormat>? onExport;

  @override
  State<ExportDataModal> createState() => _ExportDataModalState();
}

class _ExportDataModalState extends State<ExportDataModal> {
  ExportFormat _selectedFormat = ExportFormat.csv;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: CognitiveAIBotTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: CognitiveAIBotTheme.cardBackgroundAlt,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: CognitiveAIBotTheme.textSecondary.withValues(alpha: 0.95),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'FILE FORMAT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CognitiveAIBotTheme.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FormatOption(
                    format: ExportFormat.csv,
                    icon: Icons.grid_on,
                    title: 'CSV',
                    subtitle: 'Comma Separated Values',
                    selectedFormat: _selectedFormat,
                    onTap: () => setState(() => _selectedFormat = ExportFormat.csv),
                  ),
                  const SizedBox(height: 8),
                  _FormatOption(
                    format: ExportFormat.json,
                    icon: Icons.code,
                    title: 'JSON',
                    subtitle: 'JavaScript Object Notation',
                    selectedFormat: _selectedFormat,
                    onTap: () => setState(() => _selectedFormat = ExportFormat.json),
                  ),
                  const SizedBox(height: 8),
                  _FormatOption(
                    format: ExportFormat.pdf,
                    icon: Icons.picture_as_pdf,
                    title: 'PDF',
                    subtitle: 'Portable Document Format',
                    selectedFormat: _selectedFormat,
                    onTap: () => setState(() => _selectedFormat = ExportFormat.pdf),
                  ),
                  const SizedBox(height: 24),
                  _buildButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: CognitiveAIBotTheme.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: CognitiveAIBotTheme.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(
              minimumSize: const Size(40, 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              backgroundColor: CognitiveAIBotTheme.cardBackgroundAlt,
              foregroundColor: CognitiveAIBotTheme.textPrimary,
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              widget.onExport?.call(_selectedFormat);
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.download, size: 20),
            label: const Text('Export Data'),
            style: FilledButton.styleFrom(
              backgroundColor: CognitiveAIBotTheme.primaryBlue,
              foregroundColor: CognitiveAIBotTheme.textPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FormatOption extends StatelessWidget {
  const _FormatOption({
    required this.format,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selectedFormat,
    required this.onTap,
  });

  final ExportFormat format;
  final IconData icon;
  final String title;
  final String subtitle;
  final ExportFormat selectedFormat;
  final VoidCallback onTap;

  bool get isSelected => format == selectedFormat;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CognitiveAIBotTheme.cardBackgroundAlt.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? CognitiveAIBotTheme.primaryBlue
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CognitiveAIBotTheme.cardBackgroundAlt,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 22,
                color: isSelected
                    ? CognitiveAIBotTheme.primaryBlue
                    : CognitiveAIBotTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CognitiveAIBotTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: CognitiveAIBotTheme.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            Radio<ExportFormat>(
              value: format,
              groupValue: selectedFormat,
              onChanged: (_) => onTap(),
              fillColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return CognitiveAIBotTheme.primaryBlue;
                }
                return CognitiveAIBotTheme.textSecondary;
              }),
            ),
          ],
        ),
      ),
    );
  }
}
