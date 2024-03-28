import { database } from "firebase-functions/v1/firestore";
import { Internalizations, Locale } from "./internalizations/internalizations";
import { internalizedStrings } from "./internalizations/internalizations_strings";
import * as functions from 'firebase-functions';

/**
 * An enumeration of Google Cloud Compute regions.
 */
export enum GCPRegion {
    /**
     * The europe-west2 region (London).
     */
    eurWest2 = 'europe-west2',
}

/**
 * Gets the default region where our services are being hosted.
 * @return {GCPRegion[]} The default regions.
 */
function getDefaultRegion(): GCPRegion[] => GCPRegion.eurWest2;
getDefaultRegion
export const backend = {
    localization: new Internalizations(internalizedStrings, Locale.fr),
    function: functions.region(...getDefaultRegion())
    .runWith({
        timeoutSeconds: 90,
    }).https,
};

