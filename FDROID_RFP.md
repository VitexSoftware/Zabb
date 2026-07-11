# F-Droid Submission Status - Zabb

Zabb has been submitted for inclusion in F-Droid. This document tracks status;
it previously held a pre-submission issue template, which is no longer needed
now that the submission is in progress.

## Tracking links

- **RFP issue** (request for packaging): https://gitlab.com/fdroid/rfp/-/issues/3445
- **Merge request** (actual build recipe): https://gitlab.com/fdroid/fdroiddata/-/merge_requests/37096
- **Metadata source**: `metadata/com.vitexsoftware.zabb.yml` in the
  [fdroiddata](https://gitlab.com/fdroid/fdroiddata) repository (maintained in a fork,
  not in this repository)

## Status

Submitted, reviewed, and iterated on with F-Droid maintainer feedback. The merge
request currently builds cleanly against the tagged `v0.6.3` release and passes all
automated checks (build, lint, rewritemeta, checkupdates, schema validation). Awaiting
a maintainer to merge.

## Requirements this repo maintains for F-Droid compatibility

- Fastlane-structured metadata in `metadata/en-US/` (description, changelogs, screenshots)
  is pulled directly into the F-Droid listing — do not duplicate it in the fdroiddata YAML.
- Every release is tagged (`vX.Y.Z`) and `pubspec.yaml`'s `version:` field uses a `+N`
  build-number suffix that increments with each release — F-Droid's `versionCode` is
  derived from it (see `UpdateCheckData` in the fdroiddata metadata).
- `pubspec.lock` must stay in sync with `pubspec.yaml` — F-Droid's build recipe runs
  `flutter pub get --enforce-lockfile`, which fails hard on any drift (unlike a plain
  `pub get`, which would silently just update the lock).
- The Flutter version used for the build is extracted at build time from
  `.github/workflows/build.yml`'s `flutter-version` field — keep that field current.
