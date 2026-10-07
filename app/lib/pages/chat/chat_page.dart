import 'dart:async';

import 'package:coco_rider/common/utilities/formatters.dart';
import 'package:coco_rider/common/utilities/utility_functions.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:coco_rider/services/api/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Chat about one booking. New messages are fetched every few seconds while the page is open.
class ChatPage extends StatefulWidget {
  /// Polling interval; shorter in tests.
  final Duration refreshEvery;

  const ChatPage({super.key, this.refreshEvery = const Duration(seconds: 5)});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final CocoApi _api = Get.find();
  final String _bookingId = Get.arguments as String;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  Participant? _with;
  bool _canWrite = false;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(widget.refreshEvery, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final after = _messages.isEmpty ? null : _messages.last.sentAt;
      final conversation = await _api.getConversation(_bookingId, after: after);
      if (!mounted) return;
      final known = _messages.map((m) => m.id).toSet();
      final fresh = conversation.messages.where((m) => !known.contains(m.id)).toList();
      setState(() {
        _with = conversation.withUser;
        _canWrite = conversation.canWrite;
        _messages.addAll(fresh);
        _loading = false;
        _error = null;
      });
      if (fresh.isNotEmpty) _scrollToEnd();
    } catch (e) {
      if (mounted && _loading) setState(() => _error = Formatters.error(e));
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final message = await _api.sendMessage(_bookingId, text);
      _input.clear();
      setState(() => _messages.add(message));
      _scrollToEnd();
    } catch (e) {
      UtilityFunctions.showErrorSnackBar(Formatters.error(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_with?.firstName ?? '')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _body(context)),
            if (!_loading && _error == null) _composer(context),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null) return Center(child: Text(_error!, textAlign: TextAlign.center));
    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.all(12),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('chat.privacy'.tr, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ),
        for (final message in _messages) _Bubble(message: message),
      ],
    );
  }

  Widget _composer(BuildContext context) {
    if (!_canWrite) {
      return Padding(padding: const EdgeInsets.all(16), child: Text('chat.closed'.tr));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: 'chat.hint'.tr, counterText: ''),
            ),
          ),
          IconButton(
            tooltip: 'chat.send'.tr,
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  static const _mineBackground = Color(0xFF1F7A0F);

  final ChatMessage message;

  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mine = message.fromMe;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            // Dark brand green: white text stays readable (the bright brand green is too light).
            color: mine ? _mineBackground : (dark ? const Color(0xFF2A2D2A) : const Color(0xFFEFEDED)),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 4),
              bottomRight: Radius.circular(mine ? 4 : 14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(message.body, style: TextStyle(color: mine ? Colors.white : scheme.onSurface)),
              const SizedBox(height: 2),
              Text(
                '${Formatters.time(message.sentAt)}${mine && message.readAt != null ? ' · ${'chat.read'.tr}' : ''}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: mine ? Colors.white70 : null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
