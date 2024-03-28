import { InternalizationKeys } from "./internalizations_keys";

/**
 * Locales which are going to be used in the app.
 */
export enum Locale {
    fr = 'fr',
    en = 'en',
}

/**
 * The localizations helper class.
 */
export class Internalizations {
    /**
     * Constructs {Internalizations} object.
     */
    constructor(
        private rawStrings: InternalizedRawStrings,
        private defaultLocal: Locale
    ) {}

    /**
     * Returns the locale of the given localeString if it exists
     * or the default locale if not.
     * @param {string} localeString
     * @return {Locale}
     */
    getLocale(localeString?: string): Locale {
        switch (localeString) {
        case Locale.en:
            return Locale.en;
        case Locale.fr:
            return Locale.fr;
        default:
            return this.defaultLocal;
        }
    }

    /**
     * Returns the localized string from a given config.
     * @param {string} locale
     * @param {string} key
     * @param {string[]} args
     * @return {string}
     */
    private localize(locale: string, key: string, ...args: string[]): string {
        let localizedString = this.rawStrings[key][this.getLocale(locale)];

        for (let i = 0; i < args.length; i++) {
            const arg = args[i];
            localizedString = localizedString.replace(
              new RegExp(`\\{${i}\\}`, 'ig'),
              arg
            );
        }
        return localizedString;
    }

    /**
     * Returns the localized string to use to welcome new users.
     * @param {Locale} locale 
     * @param {string} message The welcome message to send to the newly created user.
     * @return {string}
     */
    welcomeNewUsers(
        locale: Locale,
        message: string,
    ): string => this.localize(locale, InternalizationKeys.welcomeNewUsers, message);
}