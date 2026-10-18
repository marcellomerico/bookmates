import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/user_book.dart';

extension BookStatusIcon on BookStatus {
  IconData get icon => switch (this) {
    BookStatus.reading => Icons.auto_stories_outlined,
    BookStatus.unread => Icons.book_outlined,
    BookStatus.read => Icons.task_alt,
    BookStatus.wantToRead => Icons.bookmark_border,
  };

  /// One-line explanation shown in the status picker.
  String get hint => switch (this) {
    BookStatus.reading => 'Gerade auf dem Nachttisch',
    BookStatus.unread => 'Steht im Regal, noch nicht gelesen',
    BookStatus.read => 'Fertig gelesen',
    BookStatus.wantToRead => 'Möchte ich haben oder lesen',
  };
}

/// What the user picked in [showBookStatusSheet].
sealed class BookStatusChoice {
  const BookStatusChoice();
}

class SetStatus extends BookStatusChoice {
  const SetStatus(this.status);
  final BookStatus status;
}

class RemoveBook extends BookStatusChoice {
  const RemoveBook();
}

/// Picker for shelf statuses (reading, unread, read) and the separate wishlist.
Future<BookStatusChoice?> showBookStatusSheet(
  BuildContext context, {
  BookStatus? current,
  String? title,
}) {
  return showModalBottomSheet<BookStatusChoice>(
    context: context,
    useRootNavigator: true,
    // Size to the content (five options + remove) instead of the default 9/16 cap.
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      Widget option(BookStatus status) => ListTile(
        leading: Icon(status.icon, color: AppColors.burgundy),
        title: Text(status.label),
        subtitle: Text(status.hint),
        trailing: status == current
            ? const Icon(
                Icons.check,
                color: AppColors.burgundy,
                semanticLabel: 'Ausgewählt',
              )
            : null,
        selected: status == current,
        onTap: () => Navigator.pop(context, SetStatus(status)),
      );

      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              const _SectionLabel('In dein Regal'),
              for (final status in BookStatus.shelf) option(status),
              const Divider(height: 24),
              option(BookStatus.wantToRead),
              if (current != null) ...[
                const Divider(height: 24),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    current.onShelf
                        ? 'Aus dem Regal entfernen'
                        : 'Von der Wunschliste entfernen',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, const RemoveBook()),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: 1.2,
        color: AppColors.muted,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
