import { createContext, useContext, useState, type ReactNode } from 'react';

export type Locale = 'fr' | 'en';

const fr = {
  appName: 'on-go · Admin',
  'nav.stats': 'Tableau de bord',
  'nav.documents': 'Documents à vérifier',
  'nav.users': 'Utilisateurs',
  'nav.signOut': 'Se déconnecter',
  'login.title': 'Connexion administrateur',
  'login.phone': 'Numéro de téléphone',
  'login.sendCode': 'Recevoir le code par SMS',
  'login.code': 'Code reçu par SMS',
  'login.confirm': 'Se connecter',
  'login.devHint': 'Mode développement : aucun SMS n\'est envoyé.',
  'login.notAdmin': 'Ce compte n\'a pas accès à l\'administration.',
  'login.failed': 'Connexion impossible',
  'stats.users': 'Utilisateurs',
  'stats.verifiedDrivers': 'Conducteurs vérifiés',
  'stats.verifiedPassengers': 'Passagers vérifiés',
  'stats.documentsToReview': 'Documents à vérifier',
  'stats.upcomingTrips': 'Trajets à venir',
  'stats.bookings30': 'Réservations (30 jours)',
  'stats.commission30': 'Commission due (30 jours)',
  'docs.empty': 'Aucun document à vérifier.',
  'docs.approve': 'Accepter',
  'docs.reject': 'Refuser',
  'docs.reason': 'Motif du refus (visible par l\'utilisateur)',
  'docs.confirmReject': 'Confirmer le refus',
  'docs.cancel': 'Annuler',
  'docs.expires': 'Expire le',
  'docs.note': 'Vérification automatique',
  'docs.submitted': 'Envoyé le',
  'users.search': 'Rechercher par nom ou téléphone',
  'users.name': 'Nom',
  'users.phone': 'Téléphone',
  'users.passenger': 'Passager',
  'users.driver': 'Conducteur',
  'users.strikes': 'Avertissements',
  'users.status': 'Compte',
  'users.active': 'Actif',
  'users.suspendedUntil': 'Suspendu jusqu\'au',
  'users.suspend': 'Suspendre',
  'users.unsuspend': 'Lever la suspension',
  'users.days': 'Jours',
  'users.reason': 'Motif',
  'users.empty': 'Aucun utilisateur trouvé.',
  'common.loading': 'Chargement…',
  'common.error': 'Une erreur est survenue',
  'common.retry': 'Réessayer',
  'doc.NationalId': 'CNI',
  'doc.Selfie': 'Selfie',
  'doc.DriverLicence': 'Permis de conduire',
  'doc.Insurance': 'Assurance',
  'doc.VehicleRegistration': 'Carte grise',
  'status.Incomplete': 'Incomplet',
  'status.ManualReview': 'En vérification',
  'status.Verified': 'Vérifié',
  'status.Rejected': 'Refusé',
};

type Key = keyof typeof fr;

const en: Record<Key, string> = {
  appName: 'on-go · Admin',
  'nav.stats': 'Dashboard',
  'nav.documents': 'Documents to review',
  'nav.users': 'Users',
  'nav.signOut': 'Sign out',
  'login.title': 'Administrator sign-in',
  'login.phone': 'Phone number',
  'login.sendCode': 'Send me a code by SMS',
  'login.code': 'Code received by SMS',
  'login.confirm': 'Sign in',
  'login.devHint': 'Development mode: no SMS is sent.',
  'login.notAdmin': 'This account has no access to the admin dashboard.',
  'login.failed': 'Sign-in failed',
  'stats.users': 'Users',
  'stats.verifiedDrivers': 'Verified drivers',
  'stats.verifiedPassengers': 'Verified passengers',
  'stats.documentsToReview': 'Documents to review',
  'stats.upcomingTrips': 'Upcoming trips',
  'stats.bookings30': 'Bookings (30 days)',
  'stats.commission30': 'Commission owed (30 days)',
  'docs.empty': 'No documents to review.',
  'docs.approve': 'Approve',
  'docs.reject': 'Reject',
  'docs.reason': 'Reason (shown to the user)',
  'docs.confirmReject': 'Confirm rejection',
  'docs.cancel': 'Cancel',
  'docs.expires': 'Expires on',
  'docs.note': 'Automatic check',
  'docs.submitted': 'Submitted on',
  'users.search': 'Search by name or phone',
  'users.name': 'Name',
  'users.phone': 'Phone',
  'users.passenger': 'Passenger',
  'users.driver': 'Driver',
  'users.strikes': 'Strikes',
  'users.status': 'Account',
  'users.active': 'Active',
  'users.suspendedUntil': 'Suspended until',
  'users.suspend': 'Suspend',
  'users.unsuspend': 'Lift suspension',
  'users.days': 'Days',
  'users.reason': 'Reason',
  'users.empty': 'No users found.',
  'common.loading': 'Loading…',
  'common.error': 'Something went wrong',
  'common.retry': 'Retry',
  'doc.NationalId': 'National ID (CNI)',
  'doc.Selfie': 'Selfie',
  'doc.DriverLicence': 'Driving licence',
  'doc.Insurance': 'Insurance',
  'doc.VehicleRegistration': 'Vehicle registration',
  'status.Incomplete': 'Incomplete',
  'status.ManualReview': 'Under review',
  'status.Verified': 'Verified',
  'status.Rejected': 'Rejected',
};

const dictionaries: Record<Locale, Record<Key, string>> = { fr, en };

interface I18nValue {
  locale: Locale;
  setLocale: (locale: Locale) => void;
  t: (key: Key) => string;
  formatDate: (iso: string) => string;
  formatXaf: (amount: number) => string;
}

const I18nContext = createContext<I18nValue | null>(null);

function initialLocale(): Locale {
  try {
    const stored = localStorage.getItem('coco-admin-locale');
    if (stored === 'fr' || stored === 'en') return stored;
  } catch {
    // Storage unavailable: fall back to the browser language.
  }
  return navigator.language.startsWith('en') ? 'en' : 'fr';
}

export function I18nProvider({ children }: { children: ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>(initialLocale);

  const setLocale = (next: Locale) => {
    setLocaleState(next);
    try {
      localStorage.setItem('coco-admin-locale', next);
    } catch {
      // Not persisted; fine.
    }
  };

  const tag = locale === 'fr' ? 'fr-CM' : 'en-CM';
  const value: I18nValue = {
    locale,
    setLocale,
    t: (key) => dictionaries[locale][key],
    formatDate: (iso) => new Date(iso).toLocaleDateString(tag, { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'Africa/Douala' }),
    formatXaf: (amount) => `${new Intl.NumberFormat(tag).format(amount)} FCFA`,
  };

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n(): I18nValue {
  const context = useContext(I18nContext);
  if (!context) throw new Error('useI18n must be used inside I18nProvider');
  return context;
}

export type TranslationKey = Key;
