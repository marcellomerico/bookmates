import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Scrollable form body that avoids keyboard overflow.
class KeyboardSafeScroll extends StatelessWidget {
  const KeyboardSafeScroll({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 18, 24, 20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      padding: padding.copyWith(bottom: padding.bottom + bottomInset),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: child,
    );
  }
}

class BookmatesWordmark extends StatelessWidget {
  const BookmatesWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Booksquad',
      excludeSemantics: true,
      child: Text(
        'BOOKSQUAD',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.goldText,
          letterSpacing: 2.6,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class TinyPill extends StatelessWidget {
  const TinyPill({
    super.key,
    required this.label,
    this.selected = false,
    this.filled = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected || filled ? AppColors.burgundy : Colors.white;
    final fg = selected || filled ? Colors.white : AppColors.ink;

    final pill = Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected || filled ? AppColors.burgundy : AppColors.line,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
    if (onTap == null) return pill;
    // Visual size stays; the hit area is padded up to 48 tall.
    return Semantics(
      button: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Center(widthFactor: 1, child: pill),
      ),
    );
  }
}
