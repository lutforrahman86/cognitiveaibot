import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/cognitive_aibot_theme.dart';
import '../../core/usecases/usecase.dart';
import '../../domain/entities/content_report.dart';
import '../../domain/usecases/report_message.dart';
import '../providers/providers.dart';

/// "Report" on a saved reply: a reason and optional details, sent to the
/// admins for review.
Future<void> showReportDialog(BuildContext context, String messageId) async {
  final sent = await showDialog<bool>(context: context, builder: (_) => _ReportDialog(messageId: messageId));
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Thanks. The reply was reported for review.')));
  }
}

class _ReportDialog extends ConsumerStatefulWidget {
  const _ReportDialog({required this.messageId});

  final String messageId;

  @override
  ConsumerState<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<_ReportDialog> {
  final _details = TextEditingController();
  ReportReason? _reason;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(reportMessageProvider)
        .call(ReportMessageParams(messageId: widget.messageId, reason: reason, details: _details.text));
    if (!mounted) return;
    switch (result) {
      case Success():
        Navigator.of(context).pop(true);
      case FailureResult(:final failure):
        setState(() {
          _busy = false;
          _error = failure.message ?? 'Couldn’t send the report. Try again.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: CognitiveAIBotTheme.cardBackground,
      title: const Text('Report this reply'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'What’s wrong with it? Our team reviews every report.',
                style: TextStyle(fontSize: 14, color: CognitiveAIBotTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in ReportReason.values)
                    ChoiceChip(
                      key: Key('report-reason-${r.name}'),
                      label: Text(r.label),
                      selected: _reason == r,
                      onSelected: _busy ? null : (_) => setState(() => _reason = r),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('report-details'),
                controller: _details,
                minLines: 2,
                maxLines: 5,
                maxLength: ReportMessage.maxDetails,
                decoration: InputDecoration(
                  labelText: 'Details (optional)',
                  filled: true,
                  fillColor: CognitiveAIBotTheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, key: const Key('report-error'), style: const TextStyle(fontSize: 13, color: Color(0xFFFF7B72))),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        TextButton(
          key: const Key('report-submit'),
          onPressed: _reason == null || _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Send report'),
        ),
      ],
    );
  }
}
