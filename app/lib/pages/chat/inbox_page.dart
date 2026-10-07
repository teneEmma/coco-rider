import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/common/utilities/formatters.dart';
import 'package:coco_rider/common/widgets/async_view.dart';
import 'package:coco_rider/common/widgets/coco_ui.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:coco_rider/services/api/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// "Messages" (opened from the header): one line per booking conversation, unread ones in bold.
class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  int _version = 0;

  @override
  Widget build(BuildContext context) {
    final CocoApi api = Get.find();

    return Scaffold(
      appBar: AppBar(title: Text('inbox.title'.tr)),
      body: ContentWidth(
        child: AsyncView<List<ConversationSummary>>(
          key: ValueKey(_version),
          load: api.getConversations,
          builder: (context, conversations, _) {
            if (conversations.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Column(children: [
                  const Icon(Icons.forum_outlined, size: 48),
                  const SizedBox(height: 12),
                  Text('inbox.empty'.tr, textAlign: TextAlign.center),
                ]),
              );
            }
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final c in conversations)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: CocoAvatar(name: c.withUser.firstName),
                    title: Text(
                      '${c.withUser.firstName} · ${c.from} – ${c.to}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: c.unread > 0 ? FontWeight.w700 : FontWeight.w500,
                          ),
                    ),
                    subtitle: Text(
                      '${c.lastMessage.fromMe ? '✓ ' : ''}${c.lastMessage.body}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(Formatters.time(c.lastMessage.sentAt), style: Theme.of(context).textTheme.labelSmall),
                        if (c.unread > 0) Badge(label: Text('${c.unread}')),
                      ],
                    ),
                    onTap: () async {
                      await Get.toNamed(CocoRoutes.keyChatPage, arguments: c.bookingId);
                      setState(() => _version++);
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
