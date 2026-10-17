/// App-wide constants (support, legal URLs).
class AppConfig {
  AppConfig._();

  static const supportEmail = 'support@bookmates.app';
  // Live once GitHub Pages is enabled — see docs/RELEASE.md (Rechtstexte veröffentlichen).
  static const _legalBase = 'https://marcellomerico.github.io/bookmates';
  static const privacyPolicyUrl = '$_legalBase/privacy.html';
  static const termsUrl = '$_legalBase/terms.html';
  static const imprintUrl = '$_legalBase/imprint.html';
  static const deleteAccountUrl = '$_legalBase/delete-account.html';

  /// Deep link Supabase redirects to after e-mail confirmation / password reset.
  /// Must also be listed under Auth → URL Configuration → Redirect URLs.
  static const authRedirectUrl = 'bookmates://auth-callback';

  static Uri get supportMailto => Uri(
        scheme: 'mailto',
        path: supportEmail,
        query: 'subject=Bookmates Support',
      );
}

/// Mirrors CHECK constraints in 20261016120000_security_hardening.sql.
class AppLimits {
  AppLimits._();

  static const displayName = 50;
  static const bio = 300;
  static const postContent = 5000;
  static const comment = 2000;
  static const groupName = 80;
  static const groupDescription = 500;
  static const reportReason = 1000;
}
