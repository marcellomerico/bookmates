import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.url, this.name, this.radius = 18});

  final String? url;
  final String? name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = (name == null || name!.trim().isEmpty)
        ? '?'
        : name!.trim().characters.first.toUpperCase();

    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.parchment,
        backgroundImage: CachedNetworkImageProvider(url!),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.parchment,
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.burgundy,
          fontSize: radius * 0.85,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
