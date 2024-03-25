import 'package:get/get.dart';

class CocoInternalization extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en_CM': {
          InternalizationKeys.enterPhoneNumberText: 'ENTER YOUR PHONE NUMBER',
          InternalizationKeys.enterOTPCodeText:
              'ENTER THE OTP CODE WHICH HAS BEEN SENT',
          InternalizationKeys.nextText: 'Next',
          InternalizationKeys.hintForDepartureTextField: 'Departure',
          InternalizationKeys.hintForArrivalTextField: 'Arrival',
          InternalizationKeys.hintForReservationDateTextField: 'Today',
          InternalizationKeys.errorNonDigitInNumber:
              'Should only contain digits',
          InternalizationKeys.errorFormatPhoneNumber:
              'Wrong phone number format',
          InternalizationKeys.errorAutoRetrievalTimeOut:
              'Impossible de récupérer automatiquement le code.',
          InternalizationKeys.errorOccurred: "Une erreur c'est produite.",
          InternalizationKeys.successText: 'Successful',
          InternalizationKeys.errorText: 'Error',
          InternalizationKeys.notYetImplementedText:
              'Feature not yet implemented',
          InternalizationKeys.searchTitle: 'Search',
          InternalizationKeys.postARideTitle: 'Post',
          InternalizationKeys.yourRidesHistoryTitle: 'Coco rides',
          InternalizationKeys.inboxTitle: 'Messages',
          InternalizationKeys.profileTitle: 'Profile',
        },
        'fr_CM': {
          InternalizationKeys.enterPhoneNumberText:
              'ENTRER VOTRE NUMERO DE TELEPHONE',
          InternalizationKeys.enterOTPCodeText: 'ENTRER LE CODE OTP ENVOYÉ',
          InternalizationKeys.nextText: 'Suivant',
          InternalizationKeys.hintForDepartureTextField: 'Départ',
          InternalizationKeys.hintForArrivalTextField: 'Destination',
          InternalizationKeys.hintForReservationDateTextField: "Aujourd'hui",
          InternalizationKeys.errorNonDigitInNumber:
              'Doit seulement contenir des chiffres',
          InternalizationKeys.errorFormatPhoneNumber:
              'Le format du numero de téléphone est incorrect',
          InternalizationKeys.errorAutoRetrievalTimeOut:
              "Couldn't automatically retrieve the code.",
          InternalizationKeys.errorOccurred: 'An error occurred.',
          InternalizationKeys.successText: 'Réussi',
          InternalizationKeys.errorText: 'Erreur',
          InternalizationKeys.notYetImplementedText:
              'Feature not yet implemented',
          InternalizationKeys.searchTitle: 'Rechercher',
          InternalizationKeys.postARideTitle: 'Publier',
          InternalizationKeys.yourRidesHistoryTitle: 'Coco trajets',
          InternalizationKeys.inboxTitle: 'Messages',
          InternalizationKeys.profileTitle: 'Profil',
        }
      };
}

class InternalizationKeys {
  static const enterPhoneNumberText = 'enterPhoneNumberText';
  static const enterOTPCodeText = 'enterOTPCodeText';
  static const nextText = 'nextText';
  static const countryCodeForPhoneNumberTextField = '+237';
  static const defaultTestPhoneNumber = '679001122';
  static const defaultTestVerificationId = 'ABC123XYZ';
  static const hintForPhoneNumberTextField = '000 000 000';
  static const hintForOTPDigitTextField = '0';
  static const hintForDepartureTextField = 'hintForDepartureTextField';
  static const hintForArrivalTextField = 'hintForReservationTextField';
  static const hintForReservationDateTextField =
      'hintForReservationDateTextField';
  static const hintForNumberOfReservationsTextField = '1';
  static const errorNonDigitInNumber = 'errorNonDigitInNumber';
  static const errorFormatPhoneNumber = 'errorFormatPhoneNumber';
  static const errorAutoRetrievalTimeOut = 'errorAutoRetrievalTimeOut';
  static const errorOccurred = 'errorOccurred';
  static const successText = 'successText';
  static const errorText = 'errorText';
  static const notYetImplementedText = 'notYetImplementedText';
  static const searchTitle = 'searchTitle';
  static const postARideTitle = 'postARideTitle';
  static const yourRidesHistoryTitle = 'yourRidesHistoryTitle';
  static const inboxTitle = 'inboxTitle';
  static const profileTitle = 'profileTitle';
}
