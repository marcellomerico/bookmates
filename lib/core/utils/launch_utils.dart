import 'package:url_launcher/url_launcher.dart';

import '../constants/app_config.dart';

Future<bool> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<bool> openSupportEmail() async {
  return launchUrl(AppConfig.supportMailto);
}
