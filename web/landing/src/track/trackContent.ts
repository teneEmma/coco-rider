import type { Locale } from '../content';

export const trackContent: Record<Locale, {
  title: (name: string) => string;
  waiting: string;
  live: string;
  lastSeen: (minutes: number) => string;
  over: string;
  cancelled: string;
  distance: (km: string, city: string) => string;
  departure: string;
  vehicle: string;
  plate: string;
  expired: string;
  error: string;
  loading: string;
  safety: string;
  download: string;
}> = {
  fr: {
    title: (name) => `Trajet avec ${name}`,
    waiting: "Le conducteur n'a pas encore commencé à partager sa position.",
    live: 'Position en direct',
    lastSeen: (m) => `Dernière position il y a ${m} min`,
    over: 'Ce trajet est terminé.',
    cancelled: 'Ce trajet a été annulé.',
    distance: (km, city) => `À ${km} km de ${city} (à vol d'oiseau)`,
    departure: 'Départ',
    vehicle: 'Véhicule',
    plate: 'Immatriculation',
    expired: "Ce lien de suivi a expiré ou n'existe pas.",
    error: 'Impossible de charger le trajet. Nouvel essai dans quelques secondes…',
    loading: 'Chargement…',
    safety: 'En cas de problème, appelez directement votre proche. Urgences : 117 (police), 118 (pompiers).',
    download: 'Découvrir on-go',
  },
  en: {
    title: (name) => `Trip with ${name}`,
    waiting: 'The driver has not started sharing their position yet.',
    live: 'Live position',
    lastSeen: (m) => `Last position ${m} min ago`,
    over: 'This trip is over.',
    cancelled: 'This trip was cancelled.',
    distance: (km, city) => `${km} km from ${city} (as the crow flies)`,
    departure: 'Departure',
    vehicle: 'Vehicle',
    plate: 'Plate',
    expired: 'This tracking link has expired or does not exist.',
    error: 'Could not load the trip. Retrying in a few seconds…',
    loading: 'Loading…',
    safety: 'If something is wrong, call your relative directly. Emergency: 117 (police), 118 (fire brigade).',
    download: 'Discover on-go',
  },
};
