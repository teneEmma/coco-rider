import 'package:coco_rider/constants/coco_colors.dart';
import 'package:flutter/material.dart';

/// Building blocks of the Figma design: the white sheet with a drag handle, pill-shaped
/// fields and buttons, steppers, status labels and the route header of a trip.

/// Content width on tablets and the web; phones use the full width.
const double kContentMaxWidth = 560;

/// Centers [child] and limits its width on large screens.
class ContentWidth extends StatelessWidget {
  final Widget child;

  const ContentWidth({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: kContentMaxWidth), child: child),
      );
}

/// The white sheet with rounded top corners and a handle, as in every Figma screen.
class CocoSheet extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const CocoSheet({super.key, this.title, required this.child, this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 24)});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ContentWidth(
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 14),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(color: scheme.outline.withAlpha(110), borderRadius: BorderRadius.circular(3)),
                ),
              ),
              if (title != null) ...[
                Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: scheme.primary),
                ),
                const SizedBox(height: 18),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// A grey pill showing a value, that opens a picker when tapped (date, time, seats, city…).
class PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? background;
  final Widget? trailing;

  const PillButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.iconColor,
    this.background,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: background ?? scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor ?? scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyLarge),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// The square grey button next to a field (e.g. "use my location").
class SquareIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool busy;

  const SquareIconButton({super.key, required this.icon, required this.tooltip, this.onPressed, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: busy ? null : onPressed,
          child: SizedBox(
            width: 54,
            height: 54,
            child: Center(
              child: busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(icon, color: scheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

/// "−  2  +" in a grey pill.
class QuantityStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String? semanticLabel;

  const QuantityStepper({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 4, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel,
      value: '$value',
      child: Container(
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '−',
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 28,
              child: Text('$value', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            ),
            IconButton(
              tooltip: '+',
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small solid label: "Completed", "Ongoing", "Scheduled", "Cancelled"…
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const StatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final onColor = color.computeLuminance() > 0.5 ? CocoColors.keyInk : CocoColors.keyWhite;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: onColor)),
    );
  }
}

/// Numbered steps joined by a dashed line, the current one in blue with its label.
class StepIndicator extends StatelessWidget {
  final List<IconData> icons;
  final List<String> labels;
  final int current;

  const StepIndicator({super.key, required this.icons, required this.labels, required this.current});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final children = <Widget>[];
    for (var i = 0; i < icons.length; i++) {
      final active = i == current;
      final done = i < current;
      children.add(Semantics(
        label: labels[i],
        selected: active,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: active || done ? scheme.primary : scheme.surfaceContainerHighest,
              foregroundColor: active || done ? scheme.onPrimary : scheme.onSurface,
              child: Icon(done ? Icons.check : icons[i], size: 20),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 16,
              child: active
                  ? Text(labels[i], style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700))
                  : null,
            ),
          ],
        ),
      ));
      if (i < icons.length - 1) {
        children.add(const Expanded(child: Padding(padding: EdgeInsets.only(bottom: 22), child: DashedLine())));
      }
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: children);
  }
}

/// A horizontal dashed line.
class DashedLine extends StatelessWidget {
  final Color? color;

  const DashedLine({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final lineColor = color ?? Theme.of(context).colorScheme.outline;
    return LayoutBuilder(builder: (context, constraints) {
      final count = (constraints.maxWidth / 7).floor();
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(count, (_) => SizedBox(width: 3.5, height: 1.2, child: ColoredBox(color: lineColor))),
      );
    });
  }
}

/// Circle with the person's initial; a green check when [verified].
class CocoAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final bool verified;

  const CocoAvatar({super.key, required this.name, this.radius = 22, this.verified = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.primary,
          child: Text(initial, style: TextStyle(fontSize: radius * 0.85, fontWeight: FontWeight.w800)),
        ),
        if (verified)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle),
              padding: const EdgeInsets.all(1.5),
              child: const Icon(Icons.check_circle, size: 16, color: CocoColors.keySuccess),
            ),
          ),
      ],
    );
  }
}

/// A round colored action button (chat, call).
class RoundAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;

  const RoundAction({super.key, required this.icon, required this.color, required this.tooltip, this.onPressed});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: onPressed == null ? color.withAlpha(90) : color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(width: 46, height: 46, child: Icon(icon, color: CocoColors.keyWhite, size: 22)),
          ),
        ),
      );
}

/// A label above a value, as in the trip tickets ("DÉPART / ven. 12 mai · 13:30").
class LabeledValue extends StatelessWidget {
  final String label;
  final String value;
  final CrossAxisAlignment alignment;

  const LabeledValue({super.key, required this.label, required this.value, this.alignment = CrossAxisAlignment.start});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(label.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.4)),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: alignment == CrossAxisAlignment.end ? TextAlign.end : TextAlign.start,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// Section title used inside sheets ("Informations du véhicule").
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Row(children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
          if (trailing != null) trailing!,
        ]),
      );
}

/// A row with a label on the left and a widget on the right (switches, steppers).
class SettingRow extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Widget trailing;

  const SettingRow({super.key, this.icon, required this.label, required this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          if (icon != null) ...[
            Icon(icon, size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
          ],
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
          trailing,
        ]),
      );
}

/// Tab layout: optional [hero] on the dark background, then a [CocoSheet] that fills the
/// rest of the screen and scrolls with its content.
class SheetScrollView extends StatelessWidget {
  final Widget? hero;
  final String? title;
  final Widget child;
  final Future<void> Function()? onRefresh;

  const SheetScrollView({super.key, this.hero, this.title, required this.child, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (hero != null) SliverToBoxAdapter(child: hero!),
        SliverToBoxAdapter(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CocoSheet(title: title, child: child),
              // Covers the sheet's bottom edge and the top of the filler: their anti-aliased
              // edges would otherwise let a thin line of the dark background through.
              Positioned(left: 0, right: 0, bottom: -4, height: 8, child: ColoredBox(color: Theme.of(context).colorScheme.surface)),
            ],
          ),
        ),
        // The sheet continues to the bottom of the screen when its content is short.
        SliverFillRemaining(
          hasScrollBody: false,
          child: ColoredBox(color: Theme.of(context).colorScheme.surface),
        ),
      ],
    );
    return onRefresh == null ? scroll : RefreshIndicator(onRefresh: onRefresh!, child: scroll);
  }
}
