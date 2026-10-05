import 'package:coco_rider/constants/internalization.dart';
import 'package:coco_rider/services/api/coco_api.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Display helpers shared by the carpooling screens.
class Formatters {
  /// Cameroon is on UTC+1 all year; trips are shown in Cameroon time whatever the phone says.
  static const cameroonOffset = Duration(hours: 1);

  static String get _locale => Get.locale?.languageCode == 'en' ? 'en' : 'fr';

  static DateTime toCameroonTime(DateTime utc) => utc.toUtc().add(cameroonOffset);

  /// "5 000 FCFA", with non-breaking spaces so the amount never wraps.
  static String price(int xaf) {
    final digits = NumberFormat.decimalPattern(_locale).format(xaf).replaceAll(RegExp(r'[,\s\u202F]'), '\u00A0');
    return '$digits\u00A0FCFA';
  }

  /// "lun. 12 oct. · 07:30"
  static String departure(DateTime utc) =>
      DateFormat('EEE d MMM · HH:mm', _locale).format(toCameroonTime(utc));

  static String day(DateTime date) => DateFormat('EEE d MMM y', _locale).format(date);

  /// "lun. 12 oct.", for compact pickers.
  static String shortDay(DateTime date) => DateFormat('EEE d MMM', _locale).format(date);

  static String time(DateTime utc) => DateFormat('HH:mm', _locale).format(toCameroonTime(utc));

  /// Translates an error for a snackbar: API codes have their own message, the rest is generic.
  static String error(Object error) {
    if (error is ApiException) {
      final key = 'error.${error.code}';
      final translated = key.tr;
      return translated == key ? error.message : translated;
    }
    if (error.toString().contains('SocketException') ||
        error.toString().contains('ClientException')) {
      return 'error.network'.tr;
    }
    return InternalizationKeys.errorOccurred.tr;
  }
}
