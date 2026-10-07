import 'package:coco_rider/constants/coco_colors.dart';
import 'package:coco_rider/constants/image_keys.dart';
import 'package:flutter/material.dart';

/// The on-go symbol: a loop with two wheels. Drawn from a white mask, so it takes any color
/// (on-go blue on white, white on blue or navy; never blue on navy).
class BrandMark extends StatelessWidget {
  final double height;
  final Color? color;

  const BrandMark({super.key, required this.height, this.color});

  @override
  Widget build(BuildContext context) => Image.asset(
        ImageKeys.brandMark,
        height: height,
        color: color ?? CocoColors.keyPrimary,
        colorBlendMode: BlendMode.srcIn,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      );
}

/// Horizontal lockup: symbol + "on-go" in Inter Bold, lowercase, tight tracking (brand guide).
class BrandLogo extends StatelessWidget {
  /// Height of the symbol; the wordmark is sized from it.
  final double height;

  /// White version, for blue or navy backgrounds.
  final bool reversed;

  const BrandLogo({super.key, this.height = 36, this.reversed = false});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'on-go',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(height: height, color: reversed ? CocoColors.keyWhite : CocoColors.keyPrimary),
            SizedBox(width: height * 0.28),
            Text(
              'on-go',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: height * 0.95,
                height: 1,
                letterSpacing: -0.04 * height * 0.95,
                color: reversed ? CocoColors.keyWhite : CocoColors.keyInk,
              ),
            ),
          ],
        ),
      );
}
