import 'package:coco_rider/common/utilities/formatters.dart';
import 'package:coco_rider/common/utilities/utility_functions.dart';
import 'package:coco_rider/common/widgets/async_view.dart';
import 'package:coco_rider/constants/coco_colors.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:coco_rider/services/api/models.dart';
import 'package:coco_rider/services/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

/// Upload of the identity documents; each one is checked automatically after upload.
class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  int _version = 0;
  DocumentType? _uploading;

  Future<void> _upload(DocumentType type) async {
    final source = await Get.bottomSheet<ImageSource>(
      Container(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          child: Wrap(children: [
            ListTile(leading: const Icon(Icons.photo_camera), title: Text('documents.camera'.tr), onTap: () => Get.back(result: ImageSource.camera)),
            ListTile(leading: const Icon(Icons.photo_library), title: Text('documents.gallery'.tr), onTap: () => Get.back(result: ImageSource.gallery)),
          ]),
        ),
      ),
    );
    if (source == null) return;

    final photo = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2000,
      imageQuality: 85,
      preferredCameraDevice: type == DocumentType.selfie ? CameraDevice.front : CameraDevice.rear,
    );
    if (photo == null) return;

    DateTime? expiresOn;
    if (requiresExpiryDate(type)) {
      if (!mounted) return;
      expiresOn = await showDatePicker(
        context: context,
        helpText: 'documents.expiry'.tr,
        initialDate: DateTime.now().add(const Duration(days: 365)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365 * 15)),
      );
      if (expiresOn == null) return;
    }

    setState(() => _uploading = type);
    try {
      final bytes = await photo.readAsBytes();
      final contentType = photo.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      await Get.find<CocoApi>().uploadDocument(type: type, bytes: bytes, contentType: contentType, expiresOn: expiresOn);
      await Get.find<SessionController>().refreshProfile();
      Get.snackbar('documents.uploaded'.tr, 'doc.${type.name}'.tr,
          backgroundColor: CocoColors.keySuccess.withAlpha(230), colorText: CocoColors.keyWhite);
    } catch (e) {
      UtilityFunctions.showErrorSnackBar(Formatters.error(e));
    } finally {
      if (mounted) {
        setState(() {
          _uploading = null;
          _version++;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final CocoApi api = Get.find();

    return Scaffold(
      appBar: AppBar(title: Text('documents.title'.tr)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AsyncView<List<UserDocument>>(
              key: ValueKey(_version),
              load: api.getDocuments,
              builder: (context, documents, _) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('documents.intro'.tr),
                  const SizedBox(height: 12),
                  for (final type in DocumentType.values)
                    _DocumentTile(
                      type: type,
                      document: documents.where((d) => d.type == type).firstOrNull,
                      uploading: _uploading == type,
                      onUpload: _uploading == null ? () => _upload(type) : null,
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

class _DocumentTile extends StatelessWidget {
  final DocumentType type;
  final UserDocument? document;
  final bool uploading;
  final VoidCallback? onUpload;

  const _DocumentTile({required this.type, required this.document, required this.uploading, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final status = document?.status ?? DocumentStatus.awaitingUpload;
    final (color, icon) = switch (status) {
      DocumentStatus.accepted => (CocoColors.keySuccess, Icons.verified),
      DocumentStatus.rejected => (CocoColors.keyError, Icons.error_outline),
      DocumentStatus.submitted || DocumentStatus.needsReview => (const Color(0xFF9A5B00), Icons.hourglass_top),
      DocumentStatus.awaitingUpload => (CocoColors.keyGrey, Icons.upload_file),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text('doc.${type.name}'.tr),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            StatusChip(label: 'docStatus.${status.name}'.tr, color: color),
            if (document?.expiresOn != null) Text('${'documents.expiry'.tr} : ${Formatters.day(document!.expiresOn!)}'),
          ],
        ),
        trailing: uploading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : TextButton(
                onPressed: onUpload,
                child: Text(status == DocumentStatus.awaitingUpload ? 'documents.upload'.tr : 'documents.replace'.tr),
              ),
      ),
    );
  }
}
