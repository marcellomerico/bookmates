import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _fadeDuration = Duration(milliseconds: 280);
const _fadeReverseDuration = Duration(milliseconds: 240);

/// Subtle fade + vertical slide for auth and onboarding flows.
CustomTransitionPage<T> fadeSlidePage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: _fadeDuration,
    reverseTransitionDuration: _fadeReverseDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.025),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Pushed detail screens use the platform transitions from the theme
/// (Cupertino with swipe-back on iOS, FadeForwards on Android).
MaterialPage<T> slidePushPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return MaterialPage<T>(key: key, child: child);
}
