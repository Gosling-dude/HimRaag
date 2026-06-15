/**
 * Canonical content taxonomy for the bulk-import pipeline.
 *
 * This is the JS mirror of `lib/core/constants/content_constants.dart` and
 * `lib/core/constants/app_constants.dart`. KEEP THE TWO IN SYNC when editing —
 * the Flutter admin app and these scripts must agree on allowed values.
 */

'use strict';

// License → whether rights are cleared and whether attribution is mandatory.
const LICENSES = {
  DEMO_ONLY: { cleared: false, requiresAttribution: false },
  PUBLIC_DOMAIN: { cleared: true, requiresAttribution: false },
  CC0: { cleared: true, requiresAttribution: false },
  'CC-BY': { cleared: true, requiresAttribution: true },
  'CC-BY-SA': { cleared: true, requiresAttribution: true },
  PROVIDED: { cleared: true, requiresAttribution: false },
  PERMISSION_GRANTED: { cleared: true, requiresAttribution: true },
  LICENSED: { cleared: true, requiresAttribution: false },
};

const APPROVAL_STATUSES = ['demo', 'pending', 'approved', 'rejected'];

const REGIONS = [
  'Garhwali',
  'Kumaoni',
  'Jaunsari',
  'Himachali',
  'Kinnauri',
  'Sirmauri',
];

// The four regions a complete catalog must cover (task requirement).
const MANDATORY_REGIONS = ['Garhwali', 'Kumaoni', 'Jaunsari', 'Himachali'];

const LANGUAGES = [...REGIONS, 'Pahadi'];

const GENRES = [
  'Folk',
  'Devotional',
  'Festival',
  'Wedding',
  'Seasonal',
  'Instrumental',
  'Contemporary Folk',
];

const COLLECTIONS = {
  songs: 'songs',
  albums: 'albums',
  artists: 'artists',
  categories: 'categories',
  submissions: 'submissions',
  auditLogs: 'auditLogs',
};

const PROJECT_ID = 'himraag-prod';

module.exports = {
  LICENSES,
  APPROVAL_STATUSES,
  REGIONS,
  MANDATORY_REGIONS,
  LANGUAGES,
  GENRES,
  COLLECTIONS,
  PROJECT_ID,
};
