# verify-snap

Edge Function that checks a snap "looks like exercise", updates pair streaks and sends pushes. It also runs the hourly jobs.

## Deploy

```bash
supabase link --project-ref <PROJECT_REF>
supabase db push                              # applies 100_snap_streak_functions.sql
supabase secrets set VISION_API_KEY=<your key>
supabase secrets set VISION_MODEL=<vision model name>
supabase secrets set CRON_SECRET=<long random string>
supabase secrets set FCM_SERVICE_ACCOUNT="$(cat firebase-service-account.json)"   # optional, enables pushes
supabase functions deploy verify-snap
```

The key and model are read only from secrets. Never put them in the Flutter app or `.env`.

## Schedule the jobs

Enable `pg_cron` and `pg_net`, then run the `cron.schedule` examples at the bottom of the migration. Use `streak_maintenance` hourly and `cleanup` hourly.

## Request shapes

| Body | Auth | What it does |
|---|---|---|
| `{"snap_id":"<uuid>"}` | User JWT | Verifies one pending snap, then updates streaks and sends pushes |
| `{"job":"streak_maintenance"}` | `x-cron-secret` | Resets missed streaks, pushes "streak at risk" |
| `{"job":"cleanup"}` | `x-cron-secret` | Deletes snaps older than 24h and their files |

Response for a snap: `{"status":"verified"|"rejected","reason":"...","activity":"running"}`. A snap is verified when `is_exercise` is true, `confidence >= 0.6` and `unsafe` is false. Vendor errors return 502 and leave the snap `pending` so the app can retry.

## Test with sample images

1. Create a test user, sign in, and note the access token.
2. Upload an image to the `snaps` bucket at `<user_id>/<snap_id>.jpg` and insert a `snaps` row with that `id` and `image_path` (status `pending`) plus a `snap_recipients` row for an accepted friend.
3. Call it:

```bash
curl -i -X POST "https://<PROJECT_REF>.supabase.co/functions/v1/verify-snap" \
  -H "Authorization: Bearer <USER_ACCESS_TOKEN>" \
  -H "apikey: <ANON_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"snap_id":"<snap_id>"}'
```

Keep a small test set and tune the prompt and threshold:

- clearly exercise (runner on a trail, yoga mat, gym) -> `verified`
- clearly not (pizza, meme, screenshot, pet) -> `rejected`
- borderline (empty gym, running shoes on a shelf) -> check the confidence

Test the jobs:

```bash
curl -X POST "https://<PROJECT_REF>.supabase.co/functions/v1/verify-snap" \
  -H "x-cron-secret: <CRON_SECRET>" -H "Content-Type: application/json" \
  -d '{"job":"streak_maintenance"}'
```

Check logs with `supabase functions logs verify-snap`.

## Notes

- The check says a photo *looks like* exercise. It is not proof that someone exercised.
- To change vendor, replace the `vision` adapter in `index.ts`. Keep the `Verdict` JSON shape.
- The daily limit is a rolling 24 hours.
- Feed posts (`is_story`) are verified but never touch streaks.
