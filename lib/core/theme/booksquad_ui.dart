import 'dart:math' as math;

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

class BooksquadWordmark extends StatelessWidget {
  const BooksquadWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Booksquad',
      excludeSemantics: true,
      child: Text(
        'BOOKSQUAD',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: context.palette.goldText,
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
    // Light: lifted by a warm shadow. Dark: shadows vanish, a hairline edge does the job.
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(22),
        border: dark ? Border.all(color: context.palette.line) : null,
        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x145B3C1E),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
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
    final bg = selected || filled
        ? context.palette.burgundy
        : context.palette.card;
    final fg = selected || filled
        ? context.palette.onBurgundy
        : context.palette.ink;

    final pill = Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected || filled
              ? context.palette.burgundy
              : context.palette.line,
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

/// Fades and slides a card up, staggered by [index].
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + index * 90),
      curve: Interval(
        math.min(index * 0.15, 0.6),
        1,
        curve: Curves.easeOutBack,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// A tappable list row as a card (messages, activity, followers): same look as
/// [SoftCard], but on a Material so ink splashes stay visible.
class ListCard extends StatelessWidget {
  const ListCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x145B3C1E),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: context.palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: dark
              ? BorderSide(color: context.palette.line)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: child,
        ),
      ),
    );
  }
}
