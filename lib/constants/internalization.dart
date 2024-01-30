import 'package:get/get.dart';

class CocoInternalization extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en_CM': {
          InternalizationKeys.enterPhoneNumberText: 'ENTER YOUR PHONE NUMBER',
          InternalizationKeys.enterOTPCodeText:
              'ENTER THE OTP CODE WHICH HAS BEEN SENT',
          InternalizationKeys.nextText: 'Next',
          InternalizationKeys.errorNonDigitInNumber:
              'Should only contain digits',
          InternalizationKeys.errorFormatPhoneNumber:
              'Wrong phone number format',
          InternalizationKeys.successText: 'Successful',
          InternalizationKeys.errorText: 'Error',
        },
        'fr_CM': {
          InternalizationKeys.enterPhoneNumberText:
              'ENTRER VOTRE NUMERO DE TELEPHONE',
          InternalizationKeys.enterOTPCodeText: 'ENTRER LE CODE OTP ENVOYÉ',
          InternalizationKeys.nextText: 'Suivant',
          InternalizationKeys.errorNonDigitInNumber:
              'Doit seulement contenir des chiffres',
          InternalizationKeys.errorFormatPhoneNumber:
              'Le format du numero de téléphone est incorrect',
          InternalizationKeys.successText: 'Réussi',
          InternalizationKeys.errorText: 'Erreur',
        }
      };
}

class InternalizationKeys {
  static const enterPhoneNumberText = 'enterPhoneNumberText';
  static const enterOTPCodeText = 'enterOTPCodeText';
  static const nextText = 'nextText';
  static const prefixForPhoneNumberTextField = '+237';
  static const defaultTestPhoneNumber = '679001122';
  static const defaultTestVerificationId = 'ABC123XYZ';
  static const hintForPhoneNumberTextField = '000 000 000';
  static const hintForOTPDigitTextField = '0';
  static const errorNonDigitInNumber = 'errorNonDigitInNumber';
  static const errorFormatPhoneNumber = 'errorFormatPhoneNumber';
  static const successText = 'successText';
  static const errorText = 'errorText';
}
