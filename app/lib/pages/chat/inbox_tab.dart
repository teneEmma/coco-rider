import 'package:coco_rider/common/navigation/routes.dart';
import 'package:coco_rider/common/utilities/formatters.dart';
import 'package:coco_rider/common/widgets/async_view.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:coco_rider/services/api/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// "Messages": one line per booking conversation, unread ones first in bold.
class InboxTab extends StatefulWidget {
  const InboxTab({super.key});

  @override
  State<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<InboxTab> {
  int _version = 0;

  @override
  Widget build(BuildContext context) {
    final CocoApi api = Get.find();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
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
            return Column(
              children: [
                for (final c in conversations)
                  ListTile(
                    leading: CircleAvatar(child: Text(c.withUser.firstName.characters.first.toUpperCase())),
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
