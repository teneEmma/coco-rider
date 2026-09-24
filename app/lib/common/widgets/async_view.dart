import 'package:coco_rider/common/utilities/formatters.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Loads data once and shows a spinner, an error with a retry button, or the result.
class AsyncView<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback reload) builder;

  const AsyncView({super.key, required this.load, required this.builder});

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future = widget.load();

  void _reload() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(Formatters.error(snapshot.error!), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _reload, child: Text('common.retry'.tr)),
              ],
            ),
          );
        }
        return widget.builder(context, snapshot.data as T, _reload);
      },
    );
  }
}

/// A rounded status label; the colour is paired with text, never used alone.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
