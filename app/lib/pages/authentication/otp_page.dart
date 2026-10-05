import 'dart:async';

import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/common/widgets/coco_ui.dart';
import 'package:coco_rider/pages/authentication/sign_in_page.dart';
import 'package:coco_rider/services/authentication/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// "Enter the code": the 6-digit code sent by SMS or email. The argument is the phone
/// number (E.164) or the email address the code was sent to.
class OtpPage extends StatefulWidget {
  const OtpPage({super.key});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  static const _length = 6;
  static const _resendDelay = 60;

  final String _identifier = Get.arguments as String? ?? '';
  final _code = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  String? _error;
  int _resendIn = _resendDelay;
  Timer? _timer;

  bool get _byEmail => _identifier.contains('@');

  @override
  void initState() {
    super.initState();
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _resendIn = _resendDelay);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendIn <= 1) t.cancel();
      if (mounted) setState(() => _resendIn--);
    });
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    final failure = await sendSignInCode(Get.find<Auth>(), _identifier);
    if (!mounted) return;
    if (failure != null) {
      setState(() => _error = authErrorMessage(failure));
    } else {
      _code.clear();
      _startCountdown();
      Get.snackbar('auth.codeResent'.tr, _identifier);
    }
  }

  Future<void> _confirm() async {
    if (_code.text.length != _length || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    await Get.find<Auth>().authenticateWithOTPCode(
      _identifier,
      _code.text,
      onVerificationCompleted: () => Get.offAllNamed(CocoRoutes.keyStartPage),
      onVerificationFailed: (type) {
        if (mounted) setState(() => _error = authErrorMessage(type));
      },
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Text('auth.codeTitle'.tr, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text(
                (_byEmail ? 'auth.codeSentEmail' : 'auth.codeSentPhone').trParams({'to': _identifier}),
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: 28),
              _CodeBoxes(controller: _code, focusNode: _focus, length: _length, onCompleted: _confirm),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 20),
              Center(
                child: _resendIn > 0
                    ? Text('auth.resendIn'.trParams({'seconds': '$_resendIn'}), style: theme.textTheme.bodyMedium)
                    : TextButton(onPressed: _resend, child: Text('auth.resend'.tr)),
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder(
                valueListenable: _code,
                builder: (context, value, _) => FilledButton(
                  onPressed: value.text.length == _length && !_busy ? _confirm : null,
                  child: _busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('common.confirm'.tr),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One invisible text field drawn as separate boxes: typing, pasting and SMS autofill all work.
class _CodeBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final VoidCallback onCompleted;

  const _CodeBoxes({required this.controller, required this.focusNode, required this.length, required this.onCompleted});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        ListenableBuilder(
          listenable: Listenable.merge([controller, focusNode]),
          builder: (context, _) {
            final text = controller.text;
            return Row(
              children: [
                for (var i = 0; i < length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 0.9,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: focusNode.hasFocus && i == text.length.clamp(0, length - 1) ? scheme.primary : Colors.transparent,
                            width: 1.6,
                          ),
                        ),
                        child: Text(i < text.length ? text[i] : '', style: Theme.of(context).textTheme.headlineSmall),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        Positioned.fill(
          child: Semantics(
            label: 'auth.codeTitle'.tr,
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(length)],
                showCursor: false,
                enableInteractiveSelection: true,
                decoration: const InputDecoration(filled: false, border: InputBorder.none, counterText: ''),
                onChanged: (value) {
                  if (value.length == length) onCompleted();
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
