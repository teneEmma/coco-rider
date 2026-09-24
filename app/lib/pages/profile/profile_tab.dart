import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/common/utilities/formatters.dart';
import 'package:coco_rider/common/widgets/async_view.dart';
import 'package:coco_rider/constants/coco_colors.dart';
import 'package:coco_rider/services/api/models.dart';
import 'package:coco_rider/services/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// "Profil": identity, verification status per role, documents, sign-out.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionController session = Get.find();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Obx(() {
            final profile = session.profile.value;
            if (profile == null) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: CircleAvatar(child: Text(profile.firstName.characters.first.toUpperCase())),
                  title: Text('${profile.firstName} ${profile.lastName}', style: Theme.of(context).textTheme.titleLarge),
                  subtitle: Text(profile.phoneNumber),
                ),
                if (profile.isSuspended)
                  Card(
                    color: CocoColors.keyError.withAlpha(30),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('profile.suspended'.trParams({'date': Formatters.day(profile.suspendedUntil!)})),
                    ),
                  ),
                _RoleCard(title: 'profile.asPassenger'.tr, verification: profile.passenger),
                _RoleCard(title: 'profile.asDriver'.tr, verification: profile.driver),
                const SizedBox(height: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.badge_outlined),
                  label: Text('profile.documents'.tr),
                  onPressed: () async {
                    await Get.toNamed(CocoRoutes.keyDocumentsPage);
                    await session.refreshProfile();
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: Text('profile.edit'.tr),
                  onPressed: () => Get.toNamed(CocoRoutes.keyProfileSetupPage),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.logout),
                  label: Text('profile.logout'.tr),
                  onPressed: session.logout,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final RoleVerification verification;

  const _RoleCard({required this.title, required this.verification});

  @override
  Widget build(BuildContext context) {
    final color = switch (verification.status) {
      VerificationStatus.verified => CocoColors.keySuccess,
      VerificationStatus.manualReview => const Color(0xFF9A5B00),
      VerificationStatus.rejected => CocoColors.keyError,
      VerificationStatus.incomplete => CocoColors.keyGrey,
    };
    String names(List<DocumentType> types) => types.map((t) => 'doc.${t.name}'.tr).join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                StatusChip(label: 'status.${verification.status.name}'.tr, color: color),
              ],
            ),
            if (verification.missing.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('profile.missing'.trParams({'docs': names(verification.missing)})),
            ],
            if (verification.expired.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('profile.expired'.trParams({'docs': names(verification.expired)})),
            ],
          ],
        ),
      ),
    );
  }
}
