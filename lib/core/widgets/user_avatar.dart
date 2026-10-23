import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.url,
    this.name,
    this.radius = 18,
    this.semanticLabel,
  });

  /// Overrides the default "Profilbild von $name" label.
  final String? semanticLabel;

  final String? url;
  final String? name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final px = (radius * 2 * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(1, 300);
    final label =
        semanticLabel ??
        ((name == null || name!.trim().isEmpty)
            ? 'Profilbild'
            : 'Profilbild von ${name!.trim()}');
    return Semantics(
      label: label,
      image: true,
      excludeSemantics: true,
      child: _build(context, px),
    );
  }

  Widget _build(BuildContext context, int px) {
    final initial = (name == null || name!.trim().isEmpty)
        ? '?'
        : name!.trim().characters.first.toUpperCase();

    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: context.palette.parchment,
        backgroundImage: CachedNetworkImageProvider(url!, maxWidth: px),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: context.palette.parchment,
      child: Text(
        initial,
        style: TextStyle(
          color: context.palette.burgundy,
          fontSize: radius * 0.85,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
