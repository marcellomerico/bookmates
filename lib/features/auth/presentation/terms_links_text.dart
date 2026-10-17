import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/launch_utils.dart';

/// Text "before + Nutzungsbedingungen und Datenschutzerklärung + after" with both
/// document names tappable.
class TermsLinksText extends StatefulWidget {
  const TermsLinksText({
    super.key,
    required this.before,
    this.after = '.',
    this.style,
    this.textAlign,
  });

  final String before;
  final String after;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  State<TermsLinksText> createState() => _TermsLinksTextState();
}

class _TermsLinksTextState extends State<TermsLinksText> {
  late final _terms = TapGestureRecognizer()
    ..onTap = () => openExternalUrl(AppConfig.termsUrl);
  late final _privacy = TapGestureRecognizer()
    ..onTap = () => openExternalUrl(AppConfig.privacyPolicyUrl);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.style ?? Theme.of(context).textTheme.bodySmall;
    final link = base?.copyWith(
      color: AppColors.burgundy,
      decoration: TextDecoration.underline,
    );
    return Text.rich(
      TextSpan(style: base, children: [
        TextSpan(text: widget.before),
        TextSpan(text: 'Nutzungsbedingungen', style: link, recognizer: _terms),
        const TextSpan(text: ' und '),
        TextSpan(text: 'Datenschutzerklärung', style: link, recognizer: _privacy),
        TextSpan(text: widget.after),
      ]),
      textAlign: widget.textAlign,
    );
  }
}
