import { InternalizationKeys } from "./internalizations_keys";
import { Locale } from "./internalizations";

export type InternalizedStrings = Record<string, Record<Locale, string>>;

export const internalizedStrings: InternalizedStrings = {
    welcomeNewUsers : {
        fr : 'Bienvenue dans la famille des drivers.',
        en : 'Welcome to the familly of drivers.'
    }
}