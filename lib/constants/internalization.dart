import 'package:get/get.dart';

class CocoInternalization extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en_CM': {
          InternalizationKeys.enterPhoneNumberText: 'ENTER YOUR PHONE NUMBER',
          InternalizationKeys.nextText: 'Next',
        },
        'fr_CM': {
          InternalizationKeys.enterPhoneNumberText:
              'ENTRER VOTRE NUMERO DE TELEPHONE',
          InternalizationKeys.nextText: 'Suivant',
        }
      };
}

class InternalizationKeys {
  static const enterPhoneNumberText = 'enterPhoneNumberText';
  static const nextText = 'nextText';
}
