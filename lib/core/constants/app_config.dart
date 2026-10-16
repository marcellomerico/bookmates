/// App-wide constants (support, legal URLs).
class AppConfig {
  AppConfig._();

  static const supportEmail = 'support@bookmates.app';
  static const privacyPolicyUrl = 'https://bookmates.app/privacy';
  static const termsUrl = 'https://bookmates.app/terms';
  static const imprintUrl = 'https://bookmates.app/impressum';

  static Uri get supportMailto => Uri(
        scheme: 'mailto',
        path: supportEmail,
        query: 'subject=Bookmates Support',
      );
}
