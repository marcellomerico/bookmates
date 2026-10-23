import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/user_book.dart';

/// Page numbers entered in [showReadingProgressSheet].
typedef ReadingProgress = ({int? currentPage, int? pageCount});

/// Error text for the given input, or null when it can be saved.
String? validateReadingProgress({int? currentPage, int? pageCount}) {
  if (pageCount != null && (pageCount < 1 || pageCount > 20000)) {
    return 'Die Seitenzahl muss zwischen 1 und 20.000 liegen.';
  }
  if (currentPage != null && pageCount != null && currentPage > pageCount) {
    return 'Die aktuelle Seite ist größer als die Seitenzahl.';
  }
  return null;
}

/// "Seite 187 von 320 · 58 %", or what is known so far.
String readingProgressLabel(UserBook entry) {
  final current = entry.currentPage;
  final total = entry.pageCount;
  if (current != null && total != null) {
    return 'Seite $current von $total · ${(entry.progress! * 100).round()} %';
  }
  if (current != null) return 'Seite $current';
  if (total != null) return '$total Seiten';
  return 'Lesefortschritt eintragen';
}

Future<ReadingProgress?> showReadingProgressSheet(
  BuildContext context,
  UserBook entry,
) {
  return showModalBottomSheet<ReadingProgress>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ProgressForm(entry: entry),
  );
}

class _ProgressForm extends StatefulWidget {
  const _ProgressForm({required this.entry});
  final UserBook entry;

  @override
  State<_ProgressForm> createState() => _ProgressFormState();
}

class _ProgressFormState extends State<_ProgressForm> {
  late final _current = TextEditingController(
    text: widget.entry.currentPage?.toString() ?? '',
  );
  late final _total = TextEditingController(
    text: widget.entry.pageCount?.toString() ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _total.dispose();
    super.dispose();
  }

  int? _parse(TextEditingController c) => int.tryParse(c.text.trim());

  void _save() {
    final current = _parse(_current);
    final total = _parse(_total);
    final error = validateReadingProgress(
      currentPage: current,
      pageCount: total,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop((currentPage: current, pageCount: total));
  }

  @override
  Widget build(BuildContext context) {
    final total = _parse(_total);
    final current = _parse(_current) ?? 0;
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Lesefortschritt',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _current,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  decoration: const InputDecoration(
                    labelText: 'Aktuelle Seite',
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('von'),
              ),
              Expanded(
                child: TextField(
                  controller: _total,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  decoration: const InputDecoration(labelText: 'Seitenzahl'),
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
            ],
          ),
          if (total != null && total > 0) ...[
            Slider(
              value: current.clamp(0, total).toDouble(),
              max: total.toDouble(),
              divisions: total,
              label: '${current.clamp(0, total)}',
              activeColor: context.palette.burgundy,
              onChanged: (v) => setState(() {
                _current.text = v.round().toString();
                _error = null;
              }),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Speichern')),
        ],
      ),
    );
  }
}
