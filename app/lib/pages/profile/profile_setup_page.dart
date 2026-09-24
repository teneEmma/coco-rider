import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/common/utilities/formatters.dart';
import 'package:coco_rider/common/utilities/utility_functions.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:coco_rider/services/api/models.dart';
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
  late Gender _gender = _session.profile.value?.gender ?? Gender.unspecified;
  late Language _language = _session.profile.value?.language ??
      (Get.locale?.languageCode == 'en' ? Language.english : Language.french);
  bool _saving = false;

  bool get _isEdit => _session.profile.value != null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final profile = await Get.find<CocoApi>().saveProfile(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        gender: _gender,
        language: _language,
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
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _firstName,
                    decoration: InputDecoration(labelText: 'profile.firstName'.tr),
                    textCapitalization: TextCapitalization.words,
                    validator: required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lastName,
                    decoration: InputDecoration(labelText: 'profile.lastName'.tr),
                    textCapitalization: TextCapitalization.words,
                    validator: required,
                  ),
                  const SizedBox(height: 20),
                  Text('profile.gender'.tr, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<Gender>(
                    segments: [
                      for (final g in [Gender.female, Gender.male, Gender.unspecified])
                        ButtonSegment(value: g, label: Text('gender.${g.name}'.tr)),
                    ],
                    selected: {_gender},
                    onSelectionChanged: (s) => setState(() => _gender = s.first),
                  ),
                  const SizedBox(height: 20),
                  Text('profile.language'.tr, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
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
