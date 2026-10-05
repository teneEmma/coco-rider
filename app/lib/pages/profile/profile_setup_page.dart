import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/common/utilities/formatters.dart';
import 'package:coco_rider/common/utilities/utility_functions.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:coco_rider/services/api/models.dart';
import 'package:coco_rider/services/authentication/auth.dart';
import 'package:coco_rider/common/widgets/coco_ui.dart';
import 'package:flutter/services.dart';
import 'package:coco_rider/services/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Creates the profile right after sign-up, and edits it later.
class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final SessionController _session = Get.find();
  final _formKey = GlobalKey<FormState>();
  late final _firstName = TextEditingController(text: _session.profile.value?.firstName);
  late final _lastName = TextEditingController(text: _session.profile.value?.lastName);
  late Language _language = _session.profile.value?.language ??
      (Get.locale?.languageCode == 'en' ? Language.english : Language.french);
  late final _phone = TextEditingController(text: _session.profile.value?.phoneNumber.replaceFirst('+237', ''));
  bool _saving = false;

  bool get _isEdit => _session.profile.value != null;

  /// Email sign-in: the phone number is typed here (an SMS-verified number cannot change).
  bool get _asksPhone {
    final profile = _session.profile.value;
    if (profile != null) return !profile.phoneVerified;
    return Get.find<Auth>().user?.signedInWithEmail ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final profile = await Get.find<CocoApi>().saveProfile(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        language: _language,
        phoneNumber: _asksPhone ? '+237${_phone.text}' : null,
      );
      final wasEdit = _isEdit;
      _session.setProfile(profile);
      if (!mounted) return;
      if (wasEdit && Navigator.of(context).canPop()) {
        Get.back();
      } else {
        Get.offAllNamed(CocoRoutes.keyHomePage);
      }
    } catch (e) {
      UtilityFunctions.showErrorSnackBar(Formatters.error(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? required(String? value) =>
        value == null || value.trim().isEmpty ? 'common.required'.tr : null;

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'profile.edit'.tr : 'profile.setupTitle'.tr)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  TextFormField(
                    controller: _firstName,
                    decoration: InputDecoration(labelText: 'profile.firstName'.tr, prefixIcon: const Icon(Icons.person_outline_rounded)),
                    textCapitalization: TextCapitalization.words,
                    validator: required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lastName,
                    decoration: InputDecoration(labelText: 'profile.lastName'.tr, prefixIcon: const Icon(Icons.badge_outlined)),
                    textCapitalization: TextCapitalization.words,
                    validator: required,
                  ),
                  if (_asksPhone) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
                      decoration: InputDecoration(
                        labelText: 'profile.phone'.tr,
                        prefixText: '+237 ',
                        prefixIcon: const Icon(Icons.phone_rounded),
                        helperText: 'profile.phoneHelp'.tr,
                        helperMaxLines: 3,
                      ),
                      validator: (v) => RegExp(r'^[26]\d{8}$').hasMatch(v ?? '') ? null : 'auth.invalidPhone'.tr,
                    ),
                  ],
                  const SizedBox(height: 20),
                  SectionTitle('profile.language'.tr),
                  SegmentedButton<Language>(
                    segments: [
                      for (final l in Language.values)
                        ButtonSegment(value: l, label: Text('language.${l.name}'.tr)),
                    ],
                    selected: {_language},
                    onSelectionChanged: (s) => setState(() => _language = s.first),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('profile.save'.tr),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
