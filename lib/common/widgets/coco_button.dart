import 'package:coco_rider/constants/coco_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CocoButton extends StatelessWidget {
  const CocoButton({
    super.key,
    required this.buttonState,
    required this.onValidate,
    required this.normalStateText,
    this.errorStateText,
    this.successStateText,
    this.disabledStateText,
    this.height,
    this.width,
    this.textColor,
  });

  final Rx<CocoButtonState> buttonState;
  final String? errorStateText;
  final String? successStateText;
  final String? disabledStateText;
  final String normalStateText;
  final double? height;
  final double? width;
  final Color? textColor;
  final Future Function() onValidate;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        Widget child = switch (buttonState.value) {
          CocoButtonState.initialState => _ButtonContent(
              color: CocoColors.keyPrimary,
              textToShow: normalStateText,
              onValidate: () async => onValidate(),
              textToShowColor: textColor,
            ),
          CocoButtonState.onLoading => const Center(
              child: CircularProgressIndicator(
                color: CocoColors.keyPrimary,
              ),
            ),
          CocoButtonState.onSuccess => _ButtonContent(
              color: CocoColors.keySuccess,
              textToShow: successStateText ?? 'Success',
              onValidate: () => {},
              textToShowColor: textColor,
            ),
          CocoButtonState.onError => _ButtonContent(
              color: CocoColors.keyError,
              textToShow: errorStateText ?? 'Error',
              onValidate: () => null,
              textToShowColor: textColor,
            ),
          _ => _ButtonContent(
              color: CocoColors.keyGrey,
              onValidate: null,
              textToShow: disabledStateText ?? normalStateText,
              textToShowColor: textColor,
            ),
        };

        return SizedBox(
          width: width ?? double.infinity,
          height: height ?? 50,
          child: child,
        );
      },
    );
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.color,
    required this.onValidate,
    required this.textToShow,
    this.textToShowColor,
  }) : super();
  final Color color;
  final Function()? onValidate;
  final String textToShow;
  final Color? textToShowColor;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onValidate,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20.0)),
        ),
      ),
      child: Text(
        textToShow,
        textScaleFactor: 1,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: textToShowColor ?? CocoColors.keyWhite,
            ),
      ),
    );
  }
}

enum CocoButtonState {
  /// States which represents the inactive state of a button.
  disabled,

  /// When there is an error after the onPressed button has been called.
  onError,

  /// Successful state after the onPressed button has been called.
  onSuccess,

  /// The loading state after the onPressed button has been called.
  onLoading,

  /// The normal state of the button.
  initialState,
}
