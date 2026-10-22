import 'package:flutter/material.dart';

import '../../models/profile.dart';
import '../theme/app_theme.dart';

/// Check mark next to the names of verified accounts; nothing for everyone else.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, required this.profile, this.size = 16});

  final Profile? profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    if (p == null || !p.isVerified) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Tooltip(
        message: p.verifiedKind == null
            ? 'Verifiziert'
            : 'Verifiziert · ${p.verifiedKind!.label}',
        child: Icon(
          Icons.verified,
          size: size,
          color: AppColors.burgundy,
          semanticLabel: 'Verifiziert',
        ),
      ),
    );
  }
}
