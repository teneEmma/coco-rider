import 'package:get/get.dart';

class CocoInternalization extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en_CM': {
          InternalizationKeys.enterPhoneNumberText: 'ENTER YOUR PHONE NUMBER',
          InternalizationKeys.nextText: 'Next',
          InternalizationKeys.errorNonDigitInNumber:
              'Should only contain digits',
          InternalizationKeys.errorFormatPhoneNumber:
              'Wrong phone number format',
        },
        'fr_CM': {
          InternalizationKeys.enterPhoneNumberText:
              'ENTRER VOTRE NUMERO DE TELEPHONE',
          InternalizationKeys.nextText: 'Suivant',
          InternalizationKeys.errorNonDigitInNumber:
              'Doit seulement contenir des chiffres',
          InternalizationKeys.errorFormatPhoneNumber:
              'Le format du numero de téléphone est incorrect',
        }
      };
}

class InternalizationKeys {
  static const enterPhoneNumberText = 'enterPhoneNumberText';
  static const nextText = 'nextText';
  static const prefixForPhoneNumberTextField = '+237';
  static const hintForPhoneNumberTextField = '000 000 000';
  static const errorNonDigitInNumber = 'errorNonDigitInNumber';
  static const errorFormatPhoneNumber = 'errorFormatPhoneNumber';
}
