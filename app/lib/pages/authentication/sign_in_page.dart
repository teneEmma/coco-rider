import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/common/widgets/coco_ui.dart';
import 'package:coco_rider/constants/image_keys.dart';
import 'package:coco_rider/services/authentication/auth.dart';
import 'package:coco_rider/services/authentication/base_authentication.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

/// Cameroonian numbers as the API accepts them: 9 digits starting with 2 or 6.
final _cameroonNumber = RegExp(r'^[26]\d{8}$');
final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// "+237690000001" from "6 90 00 00 01".
String cameroonE164(String digits) => '+237${digits.replaceAll(RegExp(r'\D'), '')}';

/// Translates a sign-in error type (Cognito exception name or local code).
String authErrorMessage(String type) {
  final key = 'auth.error.$type';
  final translated = key.tr;
  return translated == key ? 'auth.error.generic'.tr : translated;
}

/// Sends a one-time code to [identifier] (E.164 phone number or email address).
Future<String?> sendSignInCode(Auth auth, String identifier) async {
  String? failure;
  void failed(String type) => failure = type;
  if (identifier.contains('@')) {
    await auth.authenticateWithEmail(EmailAuthenticationParameter(
      email: identifier,
      onVerificationCodeSent: () {},
      onVerificationFailed: failed,
    ));
  } else {
    await auth.authenticateWithPhoneNumber(PhoneNumberAuthenticationParameter(
      phoneNumber: identifier,
      onVerificationCompleted: () {},
      onVerificationFailed: failed,
      onVerificationCodeSent: () {},
      onVerificationAutoRetrievalTimeout: () {},
    ));
  }
  return failure;
}

/// "Let's get started": sign in (or sign up) with a phone number or an email address.
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _emailField = TextEditingController();
  bool _useEmail = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _emailField.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final identifier = _useEmail ? _emailField.text.trim().toLowerCase() : cameroonE164(_phone.text);
    setState(() => _busy = true);
    final failure = await sendSignInCode(Get.find<Auth>(), identifier);
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure != null) {
      setState(() => _error = authErrorMessage(failure));
      return;
    }
    Get.toNamed(CocoRoutes.keyOTPVerificationCodePage, arguments: identifier);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ContentWidth(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
                    children: [
                      Text('auth.title'.tr, style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 10),
                      Text(
                        _useEmail ? 'auth.subtitleEmail'.tr : 'auth.subtitlePhone'.tr,
                        style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
                      ),
                      const SizedBox(height: 28),
                      Text(_useEmail ? 'auth.emailLabel'.tr : 'auth.phoneLabel'.tr, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 10),
                      if (_useEmail)
                        TextFormField(
                          key: const ValueKey('email'),
                          controller: _emailField,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          autocorrect: false,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: 'auth.emailHint'.tr,
                            prefixIcon: Icon(Icons.mail_outline_rounded, color: theme.colorScheme.primary),
                          ),
                          validator: (v) => _email.hasMatch((v ?? '').trim()) ? null : 'auth.invalidEmail'.tr,
                        )
                      else
                        TextFormField(
                          key: const ValueKey('phone'),
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          autofillHints: const [AutofillHints.telephoneNumberNational],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
                          style: theme.textTheme.titleMedium?.copyWith(letterSpacing: 1.2),
                          decoration: InputDecoration(
                            hintText: '6XX XX XX XX',
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 16, right: 10),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                SvgPicture.asset(ImageKeys.keyCameroonFlag, width: 26, height: 18),
                                const SizedBox(width: 8),
                                Text('+237', style: theme.textTheme.titleMedium),
                              ]),
                            ),
                          ),
                          validator: (v) => _cameroonNumber.hasMatch(v ?? '') ? null : 'auth.invalidPhone'.tr,
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
                      ],
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () => setState(() {
                            _useEmail = !_useEmail;
                            _error = null;
                          }),
                          child: Text(_useEmail ? 'auth.usePhone'.tr : 'auth.useEmail'.tr),
                        ),
                      ),
                      const SizedBox(height: 36),
                      Center(child: Image.asset(ImageKeys.figmaLogo, width: 110, semanticLabel: 'Coco Rider')),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('auth.sendCode'.tr),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
