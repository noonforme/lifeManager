/// The schema history was reset before the first release (2026-10-01):
/// version 1 is the first released schema. Version 2 was only ever written
/// by development builds before the reset and is never reused; schedules
/// (2026-10-02) are version 3.
const currentSchemaVersion = 3;

const releasedMigrationFingerprints = <int, String>{
  1: '573e0c481060d530f055a826876ea5fab6bb73d95d9a87acb2b996993bd169a0',
  3: '32da07e23e04e5fde1035f76d5c9b5a6acffd2f16e10bad740b5ff31545ea4cb',
};
