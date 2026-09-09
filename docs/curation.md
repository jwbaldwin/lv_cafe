# Feedback and admin curation

These pages are part of the existing Phoenix app and use its existing Postgres database. There is no Python tool, separate HTTP server, or browser-local storage dependency.

## Admin flow

Open `/admin` from any browser or device using the deployed site, then sign in. The admin page lets James:

- Browse the ten themes and preview videos through the YouTube IFrame API.
- Save verified title, live status, and recording duration after the preview actually plays and advances.
- Add, remove, reorder, and edit video settings. Saves update Postgres immediately; no deploy is needed.
- Leave private notes attached to a video, including notes about videos later removed.
- Review, dismiss, or reopen submissions and save private review notes.
- Add a submitted video to a chosen playlist and mark the submission reviewed in one database transaction.
- Copy the current inbox view as text for Codex (latest 200 matching submissions).

New theme suggestions are inbox items. Creating a new playable theme still requires its visuals/effects and keyboard mapping to be implemented.

Playlist changes use optimistic locking, so an older browser cannot overwrite newer edits. Changes are broadcast to connected listeners: reordering preserves playback; removing the current video loads another entry. At least one video must remain in each theme. Admin actions are immediate; take care with removal since there is no undo UI in this version. Notes and submissions are not deleted when videos are removed.

## Authentication and deployment

Set `ADMIN_PASSWORD` in the Phoenix process environment. It must be at least 16 bytes, and should be a unique password stored in your password manager. There is no default password or development bypass. Missing/short configuration leaves sign-in unavailable and admin routes inaccessible. Do not commit a password.

For production, set the secret on the existing `vibes-cafe` Fly app before using the admin page. `config/runtime.exs` reads it on boot. Fly's existing release command runs the migration automatically during deployment.

Sign-in creates a signed, twelve-hour session tied to the configured credential using a server-keyed digest. Changing the password invalidates old sessions, including future actions in connected admin LiveViews. Authentication is checked for HTTP access, LiveView mounting, navigation, and every admin event. Production cookies are Secure and SameSite=Lax; form posts use Phoenix CSRF protection. Sign-out clears this browser's session. Login attempts have a per-instance IP limit. This is a single-admin password flow, not a multi-user account system.

For local development, configure the environment, run `mix ecto.migrate`, then run the usual Phoenix server. The editor and player share the same port. No second editor process is needed.

## Database and migration

The app already starts `Cafe.Repo` with the Postgres adapter. Production requires `DATABASE_URL`. Migration `20260909040000_add_curation.exs` adds:

- `playlists`: theme, name, an embedded JSON video list, and an edit version.
- `feedback`: message, kind, theme/video context, visitor/admin source, review status, and admin note.

The migration imports `priv/playlists.json` once. Subsequent deployments do not reseed or overwrite admin edits. Runtime playback now reads Postgres; the JSON file is only the initial catalog for new databases. The older, previously unused `stations` table remains untouched.

## Playback settings

Live streams use YouTube's broadcast position. Recordings can use an intro offset and an optional shared clock position (“join in progress”). The latter needs a known duration and avoids the final ten seconds; it is not an actual live broadcast and cannot eliminate YouTube buffering. Paused/muted intent still carries across station changes.

## James's curation direction

- No animated animal characters or cute cat scenes in replacements.
- Blade Runner means synthwave, neon, cyberpunk; avoid literal film ambience, bleak isolation, and lonely kiosks.
- Cozy means coffee, hoodie, warm wood, comfortable rooms and desks; avoid the previous cute/pastel reading-fort direction.
- Locked In should show computer/tech/office work. Keep its first two accepted videos.
- Morning Coffee needs stronger cafe scenes and good music.
- Expand Christmas while preserving its existing three choices.
- Keep anything not called out. Prefer actually live streams and music already underway.
