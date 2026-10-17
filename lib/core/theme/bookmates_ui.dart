import 'package:flutter/material.dart';

import 'app_theme.dart';

class BookmatesScaffold extends StatelessWidget {
  const BookmatesScaffold({
    super.key,
    this.title,
    this.actions,
    this.bottomNavigationBar,
    this.safeTop = true,
    this.safeBottom = true,
    required this.body,
  });

  final String? title;
  final List<Widget>? actions;
  final Widget body;
  final Widget? bottomNavigationBar;
  final bool safeTop;
  final bool safeBottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title == null
          ? null
          : AppBar(title: Text(title!), actions: actions),
      body: SafeArea(
        top: safeTop && title == null,
        bottom: safeBottom,
        child: body,
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

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
    return Text(
      'BOOKMATES',
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: AppColors.gold,
        letterSpacing: 2.6,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class EditorialSectionTitle extends StatelessWidget {
  const EditorialSectionTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
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

class SearchStrip extends StatelessWidget {
  const SearchStrip({
    super.key,
    required this.hint,
    this.trailing,
    this.leadingIcon = Icons.search,
  });

  final String hint;
  final Widget? trailing;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(leadingIcon, size: 18, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
            const SizedBox(width: 8),
          ] else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class TinyPill extends StatelessWidget {
  const TinyPill({
    super.key,
    required this.label,
    this.selected = false,
    this.filled = false,
  });

  final String label;
  final bool selected;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bg = selected || filled ? AppColors.burgundy : Colors.white;
    final fg = selected || filled ? Colors.white : AppColors.ink;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected || filled ? AppColors.burgundy : AppColors.line,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
