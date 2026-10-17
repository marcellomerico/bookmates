import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/profile.dart';

const _publicRoutes = {'/login', '/register', '/forgot-password'};
const _onboardingRoutes = {'/onboarding', '/books/search'};
const _entryRoutes = {
  ..._publicRoutes,
  '/splash',
  '/onboarding',
  '/reset-password',
};

String? _stayOr(String location, String target) =>
    location == target ? null : target;

/// Pure routing decision; kept free of Riverpod refs so it can be unit tested.
String? authRedirect({
  required String location,
  required AsyncValue<AuthState> auth,
  required AsyncValue<Profile?> profile,
  required bool recoveringPassword,
}) {
  if (!auth.hasValue) {
    return auth.hasError
        ? _stayOr(location, '/login')
        : _stayOr(location, '/splash');
  }

  final userId = auth.value!.session?.user.id;
  if (userId == null) {
    return _publicRoutes.contains(location) ? null : '/login';
  }

  if (recoveringPassword) return _stayOr(location, '/reset-password');

  final current = profile.valueOrNull;
  final hasOwnProfile = current != null && current.id == userId;
  // On load errors stay on splash (it offers retry) rather than re-running onboarding.
  if ((profile.isLoading || profile.hasError) && !hasOwnProfile) {
    return _stayOr(location, '/splash');
  }

  final onboarded = hasOwnProfile && current.onboardingCompleted;
  if (!onboarded) {
    return _onboardingRoutes.contains(location) ? null : '/onboarding';
  }

  return _entryRoutes.contains(location) ? '/home' : null;
}
