import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/common/utilities/formatters.dart';
import 'package:coco_rider/common/widgets/async_view.dart';
import 'package:coco_rider/common/widgets/coco_ui.dart';
import 'package:coco_rider/constants/coco_colors.dart';
import 'package:coco_rider/services/api/models.dart';
import 'package:coco_rider/services/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Opened from the avatar in the header: identity, verification per role, documents, sign-out.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionController session = Get.find();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('profile.title'.tr)),
      body: SafeArea(
        child: ContentWidth(
          child: Obx(() {
            final profile = session.profile.value;
            if (profile == null) return const SizedBox.shrink();
            final name = '${profile.firstName} ${profile.lastName}';
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Center(child: CocoAvatar(name: name, radius: 44, verified: profile.passenger.isVerified)),
                const SizedBox(height: 12),
                Text(name, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(profile.phoneNumber, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                if (!profile.phoneVerified)
                  Text('profile.phoneNotVerified'.tr, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                if (profile.email != null)
                  Text(profile.email!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 18),
                if (profile.isSuspended)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: CocoColors.keyDanger.withAlpha(30), borderRadius: BorderRadius.circular(16)),
                    child: Text('profile.suspended'.trParams({'date': Formatters.day(profile.suspendedUntil!)})),
                  ),
                _RoleCard(title: 'profile.asPassenger'.tr, icon: Icons.event_seat_rounded, verification: profile.passenger),
                _RoleCard(title: 'profile.asDriver'.tr, icon: Icons.directions_car_rounded, verification: profile.driver),
                const SizedBox(height: 14),
                FilledButton.icon(
                  icon: const Icon(Icons.badge_outlined),
                  label: Text('profile.documents'.tr),
                  onPressed: () async {
                    await Get.toNamed(CocoRoutes.keyDocumentsPage);
                    await session.refreshProfile();
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_rounded),
                  label: Text('profile.edit'.tr),
                  onPressed: () => Get.toNamed(CocoRoutes.keyProfileSetupPage),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: Text('inbox.title'.tr),
                  onPressed: () => Get.toNamed(CocoRoutes.keyInboxPage),
                ),
                const SizedBox(height: 18),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: CocoColors.keyDanger),
                  icon: const Icon(Icons.logout_rounded),
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
  final IconData icon;
  final RoleVerification verification;

  const _RoleCard({required this.title, required this.icon, required this.verification});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (verification.status) {
      VerificationStatus.verified => CocoColors.keySuccess,
      VerificationStatus.manualReview => const Color(0xFF9A5B00),
      VerificationStatus.rejected => CocoColors.keyError,
      VerificationStatus.incomplete => CocoColors.keyGrey,
    };
    String names(List<DocumentType> types) => types.map((t) => 'doc.${t.name}'.tr).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              StatusChip(label: 'status.${verification.status.name}'.tr, color: color),
            ],
          ),
          if (verification.missing.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('profile.missing'.trParams({'docs': names(verification.missing)}), style: theme.textTheme.bodySmall),
          ],
          if (verification.expired.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('profile.expired'.trParams({'docs': names(verification.expired)}), style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
