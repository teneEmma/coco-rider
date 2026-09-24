export type Locale = 'fr' | 'en';

export interface Content {
  nav: { how: string; drivers: string; safety: string; faq: string };
  hero: { title: string; subtitle: string; soon: string };
  stores: { play: string; apple: string };
  how: { title: string; steps: { title: string; text: string }[] };
  routes: { title: string; subtitle: string };
  drivers: { title: string; text: string; points: string[] };
  safety: { title: string; points: { title: string; text: string }[] };
  faq: { title: string; items: { q: string; a: string }[] };
  footer: string;
}

export const routes = [
  ['Douala', 'Yaoundé'],
  ['Yaoundé', 'Bafoussam'],
  ['Douala', 'Buea'],
  ['Douala', 'Limbé'],
  ['Douala', 'Kribi'],
  ['Yaoundé', 'Ebolowa'],
] as const;

export const content: Record<Locale, Content> = {
  fr: {
    nav: { how: 'Comment ça marche', drivers: 'Conducteurs', safety: 'Sécurité', faq: 'Questions' },
    hero: {
      title: 'Voyagez ensemble, partagez les frais.',
      subtitle: 'Coco Rider met en relation conducteurs et passagers pour les trajets entre villes et les déplacements quotidiens au Cameroun.',
      soon: 'Bientôt disponible',
    },
    stores: { play: 'Télécharger sur Google Play', apple: 'Télécharger sur l\'App Store' },
    how: {
      title: 'Comment ça marche',
      steps: [
        { title: 'Inscrivez-vous', text: 'Avec votre numéro de téléphone, puis envoyez votre CNI et un selfie depuis l\'application.' },
        { title: 'Trouvez un trajet', text: 'Cherchez par ville ou autour de vous, comparez les prix, les horaires et les avis.' },
        { title: 'Réservez et voyagez', text: 'Payez le conducteur en espèces, MTN Mobile Money ou Orange Money.' },
      ],
    },
    routes: { title: 'Trajets populaires', subtitle: 'Et aussi vos trajets quotidiens à Douala et Yaoundé.' },
    drivers: {
      title: 'Vous avez une voiture ?',
      text: 'Publiez vos trajets et rentabilisez vos places libres. Particuliers et clandos sont les bienvenus.',
      points: [
        'Vous fixez votre prix par place',
        'Vous acceptez les passagers automatiquement ou un par un',
        'Inscription gratuite pendant le lancement',
      ],
    },
    safety: {
      title: 'La confiance avant tout',
      points: [
        { title: 'Profils vérifiés', text: 'CNI et selfie pour tous ; permis, assurance et carte grise pour les conducteurs.' },
        { title: 'Avis après chaque trajet', text: 'Conducteurs et passagers se notent mutuellement.' },
        { title: 'Trajets entre femmes', text: 'Les conductrices peuvent réserver leurs trajets aux passagères.' },
        { title: 'Règles claires', text: 'Les retards d\'annulation et les absences sont sanctionnés.' },
      ],
    },
    faq: {
      title: 'Questions fréquentes',
      items: [
        { q: 'Comment je paie ?', a: 'Directement au conducteur : espèces, MTN Mobile Money ou Orange Money.' },
        { q: 'Puis-je annuler ma réservation ?', a: 'Oui, gratuitement jusqu\'à 24 heures avant le départ. Après, la réservation ne peut plus être annulée.' },
        { q: 'Pourquoi envoyer ma CNI ?', a: 'Pour que chacun sache avec qui il voyage. Vos documents ne sont jamais montrés aux autres utilisateurs.' },
        { q: 'Combien ça coûte ?', a: 'L\'application est gratuite pendant le lancement. Vous ne payez que le prix du trajet au conducteur.' },
      ],
    },
    footer: 'Coco Rider – covoiturage au Cameroun',
  },
  en: {
    nav: { how: 'How it works', drivers: 'Drivers', safety: 'Safety', faq: 'FAQ' },
    hero: {
      title: 'Travel together, share the cost.',
      subtitle: 'Coco Rider connects drivers and passengers for trips between cities and daily commutes in Cameroon.',
      soon: 'Coming soon',
    },
    stores: { play: 'Get it on Google Play', apple: 'Download on the App Store' },
    how: {
      title: 'How it works',
      steps: [
        { title: 'Sign up', text: 'With your phone number, then send your national ID card and a selfie from the app.' },
        { title: 'Find a trip', text: 'Search by city or around you, compare prices, times and reviews.' },
        { title: 'Book and travel', text: 'Pay the driver in cash, MTN Mobile Money or Orange Money.' },
      ],
    },
    routes: { title: 'Popular routes', subtitle: 'And your daily commutes in Douala and Yaoundé.' },
    drivers: {
      title: 'Do you have a car?',
      text: 'Publish your trips and make the most of your empty seats. Private drivers and clandos are welcome.',
      points: [
        'You set your price per seat',
        'Accept passengers automatically or one by one',
        'Free to join during the launch',
      ],
    },
    safety: {
      title: 'Trust comes first',
      points: [
        { title: 'Verified profiles', text: 'National ID and selfie for everyone; licence, insurance and registration for drivers.' },
        { title: 'Reviews after every trip', text: 'Drivers and passengers rate each other.' },
        { title: 'Women-only trips', text: 'Female drivers can reserve their trips for female passengers.' },
        { title: 'Clear rules', text: 'Late cancellations and no-shows are penalized.' },
      ],
    },
    faq: {
      title: 'Frequently asked questions',
      items: [
        { q: 'How do I pay?', a: 'Directly to the driver: cash, MTN Mobile Money or Orange Money.' },
        { q: 'Can I cancel my booking?', a: 'Yes, for free until 24 hours before departure. After that, the booking cannot be cancelled.' },
        { q: 'Why send my ID card?', a: 'So everyone knows who they travel with. Your documents are never shown to other users.' },
        { q: 'How much does it cost?', a: 'The app is free during the launch. You only pay the trip price to the driver.' },
      ],
    },
    footer: 'Coco Rider – carpooling in Cameroon',
  },
};
