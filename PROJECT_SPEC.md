# PROJECT_SPEC.md — Fitness Companion App (working name: "Vyayama")

> **For the AI agent:** This is the single source of truth for the project. Read it fully before every task. Build **one milestone at a time** (see Section 14). Do not build features from later milestones unless asked. After each milestone, update Section 15 (Progress Log).

---

## 1. What We Are Building

A cross-platform **fitness mobile app** (Android + iOS) that combines:

- Daily activity tracking (steps, calories burned, active time)
- Goal-based workout plans (system-made or custom) with animated exercise guides
- Diet, sleep, and health-routine support, including reminders for meals and medicine
- Daily challenges and friend teams
- Daily motivation (quotes and light health memes)
- **Friends and Snap Streaks:** a Snapchat-style layer where friends connect, take in-app photos of their exercise (workout, running, yoga, walking, and so on), and send them to each other. When two friends both send a verified exercise photo each day, their shared **Snap Streak** grows
- An **animated emotional mascot** (Duolingo-style) that reacts to whether the user does or skips workouts. It is the core differentiator of the app.

**One-line pitch:** *A fitness app with a mascot who is proud when you show up, and sad or angry when you skip.*

### 1.1 Goals
- Ship a small, lovable MVP first (Milestones 1–7), then expand.
- Make the mascot feedback loop the heart of the experience.
- Keep the app safe: reminders and general guidance only, never medical diagnosis.

### 1.2 Non-Goals (for now)
- No AI chatbot or AI-generated plans in the MVP (rule-based only).
- No payments or subscriptions in the MVP.
- No wearable-specific apps (Apple Watch / Wear OS) in the MVP.
- No user-generated meme uploads in the MVP.
- No free-text chat between users in the first version of the friends feature (only emoji reactions and preset replies).
- No gallery uploads for snaps (in-app camera only).
- No public posting. Photos are visible to accepted friends only.
- No medicine dosage advice, ever.

### 1.3 Target Users
Adults 18+ who want to lose weight, gain weight, or stay fit, including beginners who need motivation and structure. Consider Indian users (multi-language and Indian food support planned).

---

## 2. Tech Stack

| Layer | Choice | Notes |
|---|---|---|
| Mobile framework | **Flutter** (Dart, stable channel) | Single codebase for Android and iOS |
| State management | **Riverpod** (`flutter_riverpod`) | Use `AsyncNotifier` / providers |
| Navigation | **go_router** | Declarative routes, auth redirect |
| Backend | **Supabase** | Auth, Postgres, Storage, Realtime, Edge Functions |
| Auth | Supabase Auth | Email and password, Google sign-in (Apple sign-in required later for iOS release) |
| Database | Supabase Postgres | Row Level Security on every user table |
| Mascot animation | **Rive** (`rive` package) | One character with a state machine: moods as inputs |
| Exercise animations | **Lottie** (`lottie`) or short looping video | Use licensed or free assets, not scraped |
| Health data | `health` package | Apple HealthKit and Android Health Connect |
| Local notifications and alarms | `flutter_local_notifications` + `timezone` | Reminders must work offline |
| Push notifications | Firebase Cloud Messaging (`firebase_messaging`) | Needed from Milestone 12 for friend requests, snaps, and streak alerts |
| Local storage | `shared_preferences` (settings), bundled JSON assets (exercises, quotes) | |
| Camera and photos | `camera`, `flutter_image_compress`, `permission_handler` | Camera-only capture for snaps (no gallery picker) |
| On-device photo check | `google_mlkit_image_labeling` | Fast hint only, not authoritative |
| Photo verification and streak logic (server) | Supabase Edge Functions (TypeScript) + a vision-capable AI model API | API key stored as a Supabase secret, never in the app |
| Friend invites | `mobile_scanner`, `qr_flutter`, `share_plus`, `app_links` | QR codes, invite links, deep links |
| Scheduled jobs | Supabase `pg_cron` or scheduled Edge Functions | Streak expiry, snap cleanup, at-risk alerts |
| Env/config | `flutter_dotenv` or `--dart-define` | Never hardcode keys |
| Models | `freezed` + `json_serializable` (optional) | Keep models immutable |
| Testing | `flutter_test`, `integration_test` | Unit tests for logic, widget tests for key screens |
| Version control | Git | Commit after each working feature |
| Later | RevenueCat (subscriptions), Claude API (AI coach), Firebase Analytics or PostHog | Not in MVP |

---

## 3. Development Rules (Agent Must Follow)

1. **One milestone at a time.** Plan first, then implement, then verify.
2. **Architecture:** feature-first folders (Section 4). No business logic inside widgets. Put it in providers, services, or repositories.
3. **Small files.** Split widgets over ~200 lines.
4. **Null safety and lint clean.** Run `flutter analyze` and fix warnings before finishing a task.
5. **Security:**
   - Never commit secrets. Use env files and add them to `.gitignore`.
   - Never use the Supabase service-role key in the app.
   - Every user-owned table has RLS policies (Section 8).
6. **Data-driven content.** Exercises, quotes, diet tips, and condition rules live in JSON or DB tables, not hardcoded in widgets.
7. **Theming:** use `ThemeData` with a `ColorScheme`. No hardcoded colors in widgets. Support light and dark.
8. **Accessibility:** minimum 48dp tap targets, readable font sizes, sufficient contrast, semantic labels.
9. **Health safety:** the app gives reminders and general wellness info only. Show disclaimers where specified (Section 12).
10. **Verification:** after each milestone, run the app and show evidence (screenshot or recording). Web build in the built-in browser can verify UI. Android emulator or real device is required to verify steps, notifications, alarms, and health data.
11. **Ask before large decisions** such as changing the stack, adding a paid service, or changing the schema in a breaking way.
12. **Keep a running summary** of what exists and what's missing in Section 15.

---

## 4. Project Structure

```
fitbuddy/
├── PROJECT_SPEC.md
├── pubspec.yaml
├── .env.example
├── .gitignore
├── assets/
│   ├── rive/              # mascot.riv
│   ├── lottie/            # exercise animations
│   ├── data/
│   │   ├── exercises.json
│   │   ├── quotes.json
│   │   ├── memes.json     # original or licensed only
│   │   ├── conditions.json
│   │   └── diet_tips.json
│   └── images/
├── supabase/
│   ├── migrations/        # SQL files, one per change
│   └── seed.sql
├── test/
├── integration_test/
└── lib/
    ├── main.dart
    ├── app.dart                 # MaterialApp.router, theme, providers
    ├── core/
    │   ├── theme/               # light/dark ColorSchemes, text styles
    │   ├── router/              # go_router config, auth redirect
    │   ├── constants/
    │   ├── utils/               # calorie math, date helpers
    │   └── services/            # notification_service, health_service, supabase_service
    ├── data/
    │   ├── models/
    │   └── repositories/        # profile_repo, workout_repo, stats_repo, schedule_repo ...
    ├── features/
    │   ├── auth/
    │   ├── onboarding/
    │   ├── home/                # mascot + time blocks + dashboard summary
    │   ├── dashboard/           # steps, calories, active time
    │   ├── workouts/            # plans, plan builder, exercise detail
    │   ├── mascot/              # rive widget, mood engine
    │   ├── schedule/            # time blocks, reminders
    │   ├── challenges/
    │   ├── nutrition/
    │   ├── health_profile/      # conditions, medicines
    │   ├── sleep/               # sleep/wake plan, alarm
    │   ├── friends/             # connect, requests, friend list, QR/invite
    │   ├── snaps/               # camera, preview, send, inbox, viewer, verification UI
    │   ├── snap_streaks/        # pair streak state and UI
    │   ├── teams/
    │   ├── motivation/          # quotes and memes
    │   └── settings/            # theme toggle, profile, notifications, delete account
    └── shared/
        └── widgets/
```

---

## 5. Product Modules and Features

Each feature lists: **What**, **How to implement**, and **Milestone**.

### 5.1 Account and Settings *(Milestones 1–2)*
- **What:** Sign up, log in, log out, forgot password, dark/light/system theme toggle, edit profile, delete account.
- **How:** Supabase Auth (email/password + Google). `go_router` redirects unauthenticated users to `/login`. Theme mode stored in `shared_preferences` and exposed by a Riverpod `themeModeProvider`. Account deletion removes the user's data (Edge Function or RPC) and shows a confirmation dialog.

### 5.2 Onboarding *(Milestone 2)*
- **What:** On first launch after sign-up, ask: **Name, Age, Gender, Weight, Height**, then **Goal** (lose weight / gain weight / maintain). Later milestones add: fitness level, work schedule (for sleep plan), health conditions, and medicines.
- **How:** Multi-step `PageView` with validation (age 13–100, sensible weight and height ranges, kg/cm with optional lb/ft toggle). Save to `profiles`. Set `onboarding_completed = true`. Redirect logic: if not completed, go to `/onboarding`.
- **Gender options:** male, female, other or prefer not to say. Use the average of male and female Mifflin-St Jeor results for "other".

### 5.3 Tracking Dashboard *(Milestone 3)*
- **What:** Daily **steps**, **calories burned**, **active time (minutes)** with progress rings and a daily target (default 8,000 steps, adjusted by goal).
- **How:** `health_service` reads steps and active energy from Health Connect (Android) and HealthKit (iOS). Ask for permission with a friendly explanation screen. Cache the day's values in `daily_stats`. Refresh on app resume and pull-to-refresh. On web, use mock data behind a `kIsWeb` check.
- **Calories:** see Section 9.1.

### 5.4 Goals *(Milestone 2)*
- **What:** Goals: lose, gain, maintain. Goal changes the step target, the suggested plan, and diet suggestions.
- **How:** `goal` enum on `profiles`. Optional target weight and pace added later.

### 5.5 Workout Plans: System and Custom *(Milestone 4, custom in Milestone 8)*
- **What:** System-made plans by goal and level (beginner, intermediate). Users can also build a **custom plan** by picking exercises, sets, reps, and days.
- **How:**
  - Seed `workout_plans`, `plan_days`, `plan_exercises` from `exercises.json` and `seed.sql`.
  - Plan screen shows the weekly schedule. Tapping a day shows exercises. "Start workout" runs a guided session (timer, sets and reps, rest countdown) and logs completion to `workout_logs`.
  - Custom builder (Milestone 8): create plan, add days, search and add exercises, reorder, save with `is_system = false`.

### 5.6 Exercise Library with Animated Guides *(Milestones 4 and 10)*
- **What:** Each exercise has name, muscle group, equipment, instructions, common mistakes, and an **animated demo**.
- **How:** `exercises.json` includes `animation_asset` (Lottie path) or `video_url`. Start with 25–30 exercises. Detail screen loops the animation. Assets must be licensed or free for commercial use. Record the source and license in `assets/ATTRIBUTIONS.md`.

### 5.7 Daily Challenges *(Milestone 7)*
- **What:** One challenge per day (e.g., "Walk 6,000 steps", "Do 20 squats", "Drink 8 glasses of water"). Completing gives XP and keeps the streak.
- **How:** A `challenges` table with a rotation rule (pick by date). `challenge_completions` table for user progress. Streak logic in Section 9.4.

### 5.8 Teams *(Milestone 15)*
- **What:** Create or join a team with friends for running, workouts, or walking. Team leaderboard and shared weekly goal.
- **How:** Tables `teams`, `team_members` with an invite code. Leaderboard is computed from `daily_stats` or `workout_logs` for members. Use Supabase Realtime for live updates. RLS ensures members see only their own teams' data.

### 5.9 Diet Suggestions *(Milestone 11)*
- **What:** Suggested meals, foods to eat and avoid, and daily calorie target based on goal.
- **How:**
  - Calorie target = TDEE ± adjustment (lose: −15%, gain: +10%, maintain: 0, with safe minimums; see Section 9.2).
  - Suggestions come from `diet_tips.json` and a small meal library tagged by goal, diet type (veg, non-veg, vegan), and conditions.
  - Show "eat more of / limit" lists.
  - All diet content is **general wellness guidance** with the disclaimer in Section 12.

### 5.10 Health Conditions and Medicine Reminders *(Milestone 11)*
- **What:** Onboarding asks about body problems (e.g., knee pain, back pain, diabetes, high blood pressure, asthma). If the user has a condition, the plan is adapted (avoid or replace unsafe exercises). Users can add **medicine name and time**, and the app reminds them. It also reminds them when to eat.
- **How:**
  - `conditions.json` maps condition → `avoid_exercise_tags`, `safe_alternatives`, `notes`. Each exercise has `contraindications` tags. When generating or displaying a plan, filter out exercises matching the user's condition tags.
  - Show "Please consult your doctor before starting a program" when any condition is selected.
  - Medicines table stores **name and reminder time(s) only**. No dosage advice, no interaction checking, no "you should take X".
  - Reminders use `flutter_local_notifications` with exact scheduling. Handle Android exact-alarm permission and battery-optimization guidance.
  - Meal reminders are scheduled from the user's meal times.

### 5.11 Sleep, Wake, and Smart Alarm *(Milestone 11)*
- **What:** Suggested sleep and wake times based on the user's work schedule and goal, plus an alarm-like wake-up reminder and a bedtime reminder. Also lists food to eat or avoid near sleep.
- **How:** Ask work start and end times. Suggest 7–9 hours of sleep. Schedule daily bedtime and wake notifications (full-screen alarm-style where the platform permits). Be clear in-app that OS limits may affect alarm reliability, and guide the user through permissions.

### 5.12 Motivation: Quotes and Memes *(Milestone 7)*
- **What:** A motivational quote every morning and a light, funny health-related meme every evening.
- **How:** Bundled `quotes.json` and `memes.json` (original or properly licensed only). Two daily local notifications (default 8:00 and 20:00, user-adjustable). Tapping opens the item on a "Daily Boost" card on the home screen. Later: remote content via Supabase so it can be updated without an app release.

### 5.13 Mascot and Emotional Engagement *(Milestones 5 and 6)*
- **What:** An animated **original** mascot on the home screen that shows different expressions and messages:
  - **Happy / Proud:** user completed today's workout
  - **Sad:** user skipped, or a scheduled block was missed
  - **Angry / Disappointed:** several days skipped in a row
  - **Sleepy:** late night or sleep-time
  - **Celebrating:** streak milestone or challenge done
- **Home-screen time blocks:** the day is shown as blocks (workout, meals, medicine, sleep). When a block's time passes without completion, the mascot changes to a sad or angry face and shows a message such as *"You missed your workout. I was waiting for you!"*
- **How:**
  - Rive file `mascot.riv` with a State Machine and a numeric or enum input `mood`. Flutter sets this input from a `moodProvider`.
  - `MoodEngine` (pure Dart, unit-tested) decides the mood (Section 9.3).
  - Message templates per mood live in JSON (multiple variants, chosen randomly, with the user's name).
  - **Logo/app icon:** use the mascot in-app and in home-screen widgets. Note that iOS and Android do not allow the app icon to change automatically by mood. Offer **manual alternate icons** as a later feature.
- **Originality:** the mascot and logo must be original (not a copy of Duolingo's owl).

### 5.14 Friends and Snap Streaks (Exercise Photo Sharing) *(Milestones 12–14)*

A Snapchat-style social layer built around exercise.

**What the user can do**
1. **Connect with friends:** add by unique username, QR code, or invite link. Send, accept, or decline requests. Remove, block, and report friends. The friends list shows each friend's current streak with you and today's status.
2. **Capture and share:** a full-screen **in-app camera** (front/back, flash, timer). Flow: take photo → preview → choose activity tag (workout, running, yoga, walking, cycling, gym, stretching, sports) → optional short caption (max 140 characters) and overlay stickers (steps, time, activity) → send to one or more friends, or post to the **Friends Feed** (visible to accepted friends for 24 hours). Friends can view the snap and react with emoji (🔥 💪 👏) or quick preset replies. There is no free-text chat.
3. **Snap Streak (pair streak):** a streak between exactly two friends. It grows when **both** friends send a verified exercise photo to each other on the same streak day.

**Snap Streak rules**
- Friend A takes a photo and sends it directly to Friend B. A's status becomes "Waiting for B".
- Friend B receives a push notification: *"Alex finished a run! Send yours to keep the 🔥 streak."*
- Friend B takes their own photo and sends it to A. Now both have sent a verified photo that day, so the streak increases by 1 and both mascots celebrate.
- If either friend misses the day, the streak resets to 0 once the day has passed. An ⏳ warning shows 4 hours before the day ends if the streak is not yet complete.
- Each person must send their **own** photo. A Friends Feed post does not count toward a pair streak. Gallery images are not allowed, and rejected photos do not count.
- A streak day is a calendar day in the pair's timezone (the timezone of the person who started the streak, stored on the pair).
- Milestones at 3, 7, 14, 30, 50, and 100 days give a celebration, XP, and a badge.
- **The photo must be exercise-related:** workout, running, yoga, walking, or any exercise (gym, cycling, stretching, sports).
  - Accepted: a person exercising, a post-workout selfie with exercise context, exercise equipment or settings (track, mat, trail, gym), a workout screen.
  - Rejected: food, memes, screenshots, pets, random selfies with no exercise context, and anything unsafe.

**How to implement**

- **Friends:** `friendships` table (pending, accepted, declined, blocked). Add `username` (unique), `avatar_url`, and `timezone` to `profiles`. Search by exact username only (no browsing all users). Invite link and QR code carry the user's username or a short invite token, handled with deep links.
- **Capture:** use the `camera` package. **Do not use a gallery picker for snaps.** Compress to a max of 1280px and about 500 KB, and strip EXIF and location data. Upload to the private Supabase Storage bucket `snaps` at `{sender_id}/{snap_id}.jpg`. Insert a `snaps` row (status `pending`) and `snap_recipients` rows.
- **Verification (layered):**
  1. Live in-app capture only, which reduces fake uploads.
  2. Optional on-device ML Kit image labeling as a fast hint. If no exercise-related label is found, show "This doesn't look like exercise. Try again?" This is not authoritative.
  3. **Authoritative server check:** a Supabase Edge Function `verify-snap` downloads the image and sends it to a vision-capable AI model (for example Claude or Gemini via API) with a strict prompt, expecting JSON like `{"is_exercise": true, "activity": "running", "confidence": 0.9, "unsafe": false, "reason": "..."}`. Mark the snap `verified` if `is_exercise` is true, confidence is at least 0.6, and `unsafe` is false. Otherwise mark it `rejected` with a friendly reason, and let the user retake.
  4. Rate limits: max 10 snaps per user per day, and verify each image once.
  5. Optional later: cross-check with Health data (steps or active minutes) for an extra "verified by activity" badge.
  - Only **verified** snaps are delivered to recipients and counted toward streaks.
- **Streak updates:** done **only on the server** (Edge Function or `security definer` database function). The app cannot write to streak tables. An hourly scheduled job resets expired streaks and sends "streak at risk" alerts.
- **Delivery and expiry:** recipients view snaps through short-lived signed URLs. Snaps and their image files are deleted 24 hours after sending by a scheduled cleanup. Only metadata (dates, counts) is kept for streaks.
- **Notifications:** FCM push for friend request, request accepted, "friend sent you a snap", "your turn" nudge, streak at risk, and milestone. Store device tokens in `device_tokens`.
- **Mascot link:** add a `worried` mood for "friend already sent, you haven't". Use `celebrating` when the streak completes. Example message: *"Sam already sent theirs. Don't break the streak!"*
- **UI hints:** friend list shows 🔥 and the streak count beside each name, ⏳ when at risk, and a "Your turn" label when a friend has sent first.

**Known limitations (accepted for now)**
- The AI check confirms a photo *looks* like exercise, not that the person really exercised (for example, a photo of a gym could pass). Camera-only capture and rate limits reduce cheating. Screenshot detection is not reliable.
- Abuse is handled with report and block on every snap and friend.

---

## 6. Screens and Navigation

Bottom navigation (after onboarding): **Home · Workouts · Camera (center button) · Friends · Profile**. Nutrition, Health, Sleep, Challenges, and Teams are reached from cards on Home and from the Profile screen.

| Route | Screen |
|---|---|
| `/login`, `/signup`, `/forgot` | Auth |
| `/onboarding` | Multi-step profile and goal setup |
| `/home` | Mascot, today's time blocks, steps/calories/active time summary, daily challenge, daily boost card |
| `/workouts` | My plan, browse plans, exercise library |
| `/workouts/plan/:id` | Plan detail |
| `/workouts/session/:dayId` | Guided workout session |
| `/workouts/exercise/:id` | Exercise detail with animation |
| `/workouts/builder` | Custom plan builder |
| `/nutrition` | Calorie target, meal suggestions, eat/avoid lists |
| `/health` | Conditions, medicines, meal and medicine reminders |
| `/sleep` | Sleep/wake plan and alarm |
| `/challenges` | Daily challenge, streak, XP |
| `/teams`, `/teams/:id` | Team list, detail, leaderboard |
| `/friends` | Friend list with streak counts and today's status |
| `/friends/add` | Add by username, scan QR, share invite link |
| `/friends/requests` | Incoming and outgoing requests |
| `/friends/:id` | Friend detail and Snap Streak status |
| `/snaps/camera` | In-app camera |
| `/snaps/preview` | Preview, activity tag, caption, choose recipients |
| `/snaps/inbox` | Received snaps |
| `/snaps/view/:id` | View a snap, react |
| `/feed` | Friends Feed (24h posts) |
| `/settings` | Theme, notifications, units, account, delete account, disclaimer |

---

## 7. Design System

- Material 3 with custom `ColorScheme.fromSeed`, light and dark.
- Friendly, rounded, playful look. The mascot leads the personality.
- Typography: one clean sans-serif (e.g., Poppins or Nunito via `google_fonts`, or bundled fonts).
- Spacing scale: 4, 8, 12, 16, 24, 32.
- Reusable widgets: `AppButton`, `StatRing`, `TimeBlockCard`, `MascotView`, `SectionHeader`, `EmptyState`.
- Motion: subtle transitions, mascot animations, and confetti on milestones. Respect the reduced-motion setting.

---

## 8. Database Schema (Supabase / Postgres)

Put these in `supabase/migrations/`. Enable RLS on **every** table.

```sql
-- Profiles
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text,
  age int check (age between 13 and 100),
  gender text check (gender in ('male','female','other')),
  weight_kg numeric(5,2),
  height_cm numeric(5,1),
  goal text check (goal in ('lose','gain','maintain')),
  fitness_level text default 'beginner',
  wake_time time,
  sleep_time time,
  work_start time,
  work_end time,
  onboarding_completed boolean default false,
  created_at timestamptz default now()
);

-- Exercises (system data, readable by all signed-in users)
create table exercises (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  muscle_group text,
  equipment text,
  instructions text,
  animation_asset text,
  contraindications text[] default '{}',
  created_at timestamptz default now()
);

-- Workout plans
create table workout_plans (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  goal text,
  level text,
  is_system boolean default false,
  owner_id uuid references profiles(id) on delete cascade,
  created_at timestamptz default now()
);

create table plan_days (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid references workout_plans(id) on delete cascade,
  day_number int not null,
  name text
);

create table plan_exercises (
  id uuid primary key default gen_random_uuid(),
  plan_day_id uuid references plan_days(id) on delete cascade,
  exercise_id uuid references exercises(id),
  sort_order int default 0,
  sets int, reps int, duration_sec int, rest_sec int default 45
);

-- Logs and stats
create table workout_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  plan_day_id uuid references plan_days(id),
  completed_at timestamptz default now(),
  duration_min int,
  calories_burned int
);

create table daily_stats (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  date date not null,
  steps int default 0,
  calories int default 0,
  active_minutes int default 0,
  unique (user_id, date)
);

-- Schedule / time blocks
create table schedule_blocks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  type text check (type in ('workout','meal','medicine','sleep','wake','custom')),
  title text,
  start_time time not null,
  days_of_week int[] default '{1,2,3,4,5,6,7}',
  is_active boolean default true
);

create table block_completions (
  id uuid primary key default gen_random_uuid(),
  block_id uuid references schedule_blocks(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  date date not null,
  status text check (status in ('done','missed','skipped')),
  unique (block_id, date)
);

-- Streaks and challenges
create table streaks (
  user_id uuid primary key references profiles(id) on delete cascade,
  current int default 0,
  longest int default 0,
  last_active_date date,
  xp int default 0
);

create table challenges (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  type text, target_value int, xp int default 10
);

create table challenge_completions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  challenge_id uuid references challenges(id),
  date date not null,
  unique (user_id, date)
);

-- Health (Milestone 11)
create table user_conditions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  condition_key text not null
);

create table medicines (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  name text not null,
  reminder_times time[] not null,
  is_active boolean default true
  -- NOTE: no dosage or medical advice fields by design
);

-- Friends and snaps (Milestones 12-14)
alter table profiles
  add column username text unique,
  add column avatar_url text,
  add column timezone text default 'UTC';

create table friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid references profiles(id) on delete cascade,
  addressee_id uuid references profiles(id) on delete cascade,
  status text default 'pending' check (status in ('pending','accepted','declined','blocked')),
  created_at timestamptz default now(),
  unique (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);

create table snaps (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid references profiles(id) on delete cascade,
  image_path text not null,                -- path in private 'snaps' bucket
  activity_type text check (activity_type in
    ('workout','running','yoga','walking','cycling','gym','stretching','sports','other_exercise')),
  caption text check (char_length(caption) <= 140),
  is_story boolean default false,          -- true = Friends Feed post (does not count for streaks)
  verification_status text default 'pending'
    check (verification_status in ('pending','verified','rejected')),
  verification_label text,
  verification_confidence numeric(3,2),
  rejection_reason text,
  created_at timestamptz default now(),
  expires_at timestamptz default (now() + interval '24 hours')
);

create table snap_recipients (
  snap_id uuid references snaps(id) on delete cascade,
  recipient_id uuid references profiles(id) on delete cascade,
  viewed_at timestamptz,
  reaction text,
  primary key (snap_id, recipient_id)
);

-- One row per friend pair. user_a < user_b keeps the pair unique.
create table snap_streaks (
  id uuid primary key default gen_random_uuid(),
  user_a uuid references profiles(id) on delete cascade,
  user_b uuid references profiles(id) on delete cascade,
  current int default 0,
  longest int default 0,
  last_a_snap_date date,                   -- last day A sent a verified snap to B
  last_b_snap_date date,                   -- last day B sent a verified snap to A
  last_completed_date date,                -- last day both had sent
  timezone text default 'UTC',             -- pair timezone that defines "a day"
  created_at timestamptz default now(),
  unique (user_a, user_b),
  check (user_a < user_b)
);

create table device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  token text not null,
  platform text,
  updated_at timestamptz default now(),
  unique (user_id, token)
);

create table reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references profiles(id) on delete set null,
  snap_id uuid references snaps(id) on delete set null,
  reported_user_id uuid references profiles(id) on delete set null,
  reason text,
  status text default 'open',
  created_at timestamptz default now()
);

-- Teams (Milestone 15)
create table teams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text check (type in ('running','workout','walking')),
  invite_code text unique not null,
  owner_id uuid references profiles(id),
  created_at timestamptz default now()
);

create table team_members (
  team_id uuid references teams(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  joined_at timestamptz default now(),
  primary key (team_id, user_id)
);
```

**RLS policy pattern** (apply to each user-owned table):

```sql
alter table profiles enable row level security;
create policy "own profile" on profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

-- For tables with user_id:
alter table daily_stats enable row level security;
create policy "own rows" on daily_stats
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- System data (exercises, challenges): read-only for signed-in users
alter table exercises enable row level security;
create policy "read exercises" on exercises
  for select using (auth.role() = 'authenticated');
```

- `workout_plans`: users can read where `is_system = true` or `owner_id = auth.uid()`, and write only their own.
- `plan_days` / `plan_exercises`: access follows the parent plan's rules.
- `teams` / `team_members`: members can read their team and its members. Only the owner can update or delete the team. Joining is done via a secure RPC that checks the invite code.
- Create a `profiles` row automatically on sign-up (trigger on `auth.users`) or on first onboarding step.
- `friendships`: users can see rows they are part of. Only the addressee can accept or decline. A blocked user cannot send requests or snaps.
- `snaps`: the sender can insert and read their own. Recipients can read only snaps listed for them in `snap_recipients` that are `verified` and not expired. Story snaps are readable by accepted friends only. **No public access.** Clients can never update `verification_status`.
- `snap_streaks`: read-only for the two members. Written only by server functions (service role inside Edge Functions).
- Storage bucket `snaps` is **private**. Uploads are allowed only into the `{auth.uid()}/` folder. Reads happen through short-lived signed URLs.

---

## 9. Core Logic

### 9.1 Calories burned
- **BMR (Mifflin-St Jeor):**
  - Male: `10·kg + 6.25·cm − 5·age + 5`
  - Female: `10·kg + 6.25·cm − 5·age − 161`
  - Other: average of the two
- **Active calories:** prefer active-energy values from HealthKit or Health Connect. If unavailable, estimate from steps: `steps × weight_kg × 0.0005` (approximate) plus workout calories: `MET × weight_kg × hours`.
- Display "calories burned today" as active calories, with total (BMR + active) available in details.

### 9.2 Daily calorie target (Nutrition)
- `TDEE = BMR × activity_factor` (sedentary 1.2, light 1.375, moderate 1.55, active 1.725).
- Lose: −15% (never below a safe floor, e.g., 1,200 kcal for women and 1,500 kcal for men). Gain: +10%. Maintain: 0%.
- Show as a **range and estimate**, never as medical advice.

### 9.3 Mascot mood engine (pure Dart, unit-tested)

```
Inputs: workoutDoneToday, missedBlockNow, daysSkippedInARow, currentTime,
        streakMilestoneHit, challengeJustCompleted

if streakMilestoneHit or challengeJustCompleted -> celebrating
else if workoutDoneToday                        -> proud (or happy)
else if daysSkippedInARow >= 3                  -> angry / disappointed
else if missedBlockNow                          -> sad + "you missed it" message
else if isSleepTime                             -> sleepy
else                                            -> happy (greeting by time of day)
```

Messages are chosen from per-mood JSON templates and use the user's name. Add unit tests for every branch.

### 9.4 Streaks
- Activity day = completed a workout or the daily challenge.
- If `last_active_date == yesterday`: increment. If `== today`: no change. Otherwise: reset to 1.
- Update `longest` when `current > longest`. Award XP on completion.
- Use the user's local date, and handle time zones.

### 9.5 Condition-based plan adaptation
- Each exercise has `contraindications` tags (e.g., `knee`, `lower_back`, `high_impact`).
- User conditions map to tags in `conditions.json`.
- When building or displaying a plan, replace excluded exercises with a safe alternative from the same muscle group, or remove them and note why.

### 9.6 Snap Streak logic (server-side, unit-tested)

Runs when a snap becomes `verified`:

```
for each recipient R of snap S sent by A (S.is_story = false):
  if friendship(A, R) is accepted:
    pair  = ordered(A, R)                      # user_a < user_b
    today = current date in pair.timezone
    set A's side: last_X_snap_date = today     # X = a or b depending on A
    if last_a_snap_date == today AND last_b_snap_date == today
       AND last_completed_date != today:
         if last_completed_date == today - 1 day:  current = current + 1
         else:                                     current = 1   # new or restarted
         longest = max(longest, current)
         last_completed_date = today
         -> push "Streak is now N!" to both, mascot celebrates
         -> if N in (3, 7, 14, 30, 50, 100): milestone reward (XP + badge)
    else:
         -> push "Your turn" to R
```

Hourly job:

```
for each pair with current > 0:
  today = current date in pair.timezone
  if today - last_completed_date >= 2 days:  current = 0      # a full day was missed
  else if last_completed_date != today AND hours_left_today <= 4:
       send "streak at risk" push to the friend(s) who haven't sent yet
```

Mascot: pass `snapStreakAtRisk` into `MoodEngine`. If true (friend sent, you haven't), mood = `worried` (above `sad`, below `celebrating`). Add `worried` to the Rive state machine.

Unit tests must cover: first snap, both snaps same day, one-sided day, day rollover, timezone edge cases, reset after a missed day, milestone days, and rejected snaps not counting.

---

## 10. Notifications and Reminders

| Type | Mechanism | Notes |
|---|---|---|
| Morning quote (default 8:00) | Local, daily repeating | User can change the time |
| Evening meme (default 20:00) | Local, daily repeating | User can change the time |
| Workout reminder | Local, per schedule block | Missed-block message triggers mascot mood on next open |
| Meal reminder | Local | From user meal times |
| Medicine reminder | Local, exact scheduling | Name and time only, no advice |
| Bedtime and wake alarm | Local, exact | Guide the user through exact-alarm permission and battery optimization |
| Friend request / accepted | FCM push | Milestone 12 |
| Friend sent you a snap, "your turn" nudge | FCM push | Milestone 14 |
| Snap Streak at risk (4h before day ends) | FCM push from hourly server job | Milestone 14 |
| Snap Streak milestone | FCM push | Milestone 14 |
| Team activity (later) | FCM push | Milestone 15 |

Requirements: request permission with a clear explanation, re-schedule after device reboot and timezone change, and let users mute categories in Settings.

---

## 11. Testing Plan

- **Unit tests:** calorie math, mood engine (all branches), streak logic, condition filtering, Snap Streak pair logic (all states, timezone and day rollover), and verification result handling.
- **Verification test set:** keep a small set of test images (clearly exercise, clearly not exercise, borderline). Check that `verify-snap` accepts and rejects them correctly, and tune the prompt and threshold.
- **Widget tests:** onboarding validation, time-block card states, mascot view given each mood.
- **Manual device tests (required):** step counting, permissions, notifications after app is closed, alarm behavior with battery saver, dark and light theme, small and large screens.
- **Per milestone:** run `flutter analyze` and tests, then show a screenshot or recording as evidence.

---

## 12. Safety, Privacy, and Legal

- **Medical disclaimer** (show at onboarding, in Health screens, and in Settings): *"This app provides general wellness information and reminders. It is not medical advice and does not diagnose, treat, or prevent any condition. Consult a qualified doctor before starting any exercise or diet program, especially if you have a health condition or take medication."*
- **Medicine feature:** reminders only. No dosage suggestions, interaction checks, or "you should take" language.
- **Data sensitivity:** health, weight, condition, and medicine data is sensitive.
  - Collect only what's needed. Ask for consent. Encrypt in transit (Supabase TLS).
  - Provide **export and delete account** options.
  - Publish a Privacy Policy and Terms before any public release (have them reviewed). Consider GDPR and India's DPDP Act as applicable.
- **Content licensing:** exercise animations, quotes, and memes must be original or licensed. Keep `ATTRIBUTIONS.md`.
- **Originality:** original mascot and logo. Do not copy trademarked characters.
- **Age:** 18+ recommended. Handle age input carefully, and do not show weight-loss content to users under 18.
- **Safe defaults:** avoid extreme calorie deficits, and avoid language that shames the user about weight or body. The mascot's "sad/angry" tone should be playful and encouraging, never insulting.
- **App icon limitation:** automatic mood-based icon changes are not supported by iOS or Android. Use in-app mascot, widgets, and manual alternate icons.
- **Snap privacy and safety:**
  - Photos of people are personal data. Show a clear explanation and get consent at first camera use. Say what is stored and for how long in the Privacy Policy.
  - Snaps are private (friends only), stored in a private bucket, and auto-deleted after 24 hours. Account deletion also deletes all snaps.
  - Strip EXIF and location data before upload.
  - Report and block on every snap and friend. Reported content goes to a review queue.
  - The AI check also flags unsafe content (nudity, violence, minors in unsafe situations) and rejects it.
  - Users cannot browse other users. Search is by exact username only. Users can choose to be added only by invite link or QR code. Users under 18 (if allowed at all) must only connect by invite link or QR, never by search.
  - No body-shaming stickers, overlays, or captions in preset content.
  - Do not claim the verification is proof of exercise. Describe it as a "looks like exercise" check.

---

## 13. Environment and Configuration

`.env.example`:

```
SUPABASE_URL=your-project-url
SUPABASE_ANON_KEY=your-anon-key
```

- Copy to `.env` (git-ignored). Never commit real keys.
- Do not put the service-role key in the app.
- The vision API key for `verify-snap` is stored as a Supabase Edge Function secret (`supabase secrets set VISION_API_KEY=...`). Never put it in the Flutter app or `.env`.
- Push notifications need a Firebase project plus `google-services.json` (Android) and `GoogleService-Info.plist` (iOS). The user must create these manually.
- Google sign-in requires OAuth client IDs, and the user must set these up manually in Google Cloud and Supabase.

---

## 14. Milestones (Build in This Order)

For each milestone: **Plan → Implement → Test → Show evidence → Update Progress Log → Commit.**

| # | Milestone | Acceptance criteria |
|---|---|---|
| 1 | **Skeleton and theme:** Flutter project, folder structure, Riverpod, go_router, light/dark/system theme with a settings toggle | App runs on Chrome and Android emulator, theme toggle persists |
| 2 | **Auth and onboarding:** Supabase email and Google sign-in, onboarding (name, age, gender, weight, height, goal), `profiles` with RLS | New user can sign up, complete onboarding, log out and back in, and data appears in Supabase |
| 3 | **Dashboard:** steps, calories, active time using the `health` package, progress rings, permission flow, `daily_stats` | Real numbers on Android device. Mock data on web |
| 4 | **Workouts:** `exercises.json` (25+), three system plans (lose, gain, maintain), plan and exercise screens, guided session, `workout_logs` | User can start a workout, finish it, and see it logged |
| 5 | **Mascot:** Rive mascot with moods (happy, proud, sad, angry), `MoodEngine`, debug panel to force moods, unit tests | Completing or skipping a workout visibly changes the mascot. All engine tests pass |
| 6 | **Time-block home and reminders:** `schedule_blocks`, home time-block cards, missed-block detection, "you missed it" messages, local notifications | A missed block changes mascot mood and message. Notification fires with the app closed |
| 7 | **Engagement:** streaks, XP, daily challenge, morning quote and evening meme notifications, Daily Boost card | Streak increments and resets correctly. Both notifications arrive daily |
| 8 | **Custom plan builder** | User can create, edit, and delete a custom plan and run it |
| 9 | **Polish and beta:** bug fixes, empty and error states, onboarding disclaimer, privacy policy, testing on 2–3 real phones, Play Store internal testing or TestFlight | Beta build installed by testers and used for one week |
| 10 | **Animated exercise demos** for the full library | Every exercise has a demo with licensed assets and attribution |
| 11 | **Health and nutrition:** conditions, condition-adapted plans, medicine and meal reminders, diet suggestions with eat/avoid lists, sleep/wake plan and alarm | Conditions filter exercises. Medicine reminder fires on time. Disclaimers shown |
| 12 | **Friends and connections:** username on profile, friend requests by username, QR code, or invite link, accept/decline/remove/block/report, FCM push setup, friend list | Two accounts can connect, and a push notification arrives when a request is sent |
| 13 | **Snap camera and sharing:** in-app camera, preview, activity tag, caption, send to friends, Friends Feed (24h), inbox, viewer, emoji reactions, private storage with signed URLs, auto-expiry | Friend A sends a photo and Friend B views it. Images are private and deleted after 24 hours |
| 14 | **Snap Streaks and exercise verification:** `verify-snap` Edge Function with a vision model, ML Kit pre-check, server-side pair streak logic, at-risk and "your turn" pushes, mascot reactions, milestones | A non-exercise photo is rejected. Both friends sending verified exercise photos on the same day increases the streak. Missing a day resets it. Streak tests pass |
| 15 | **Teams:** create and join by invite code, team leaderboard, realtime updates | Two accounts can join one team and see each other's progress |
| 16 | **Growth (optional):** AI coach (Claude API with safety rules), subscriptions (RevenueCat), home-screen widgets, alternate app icons, multi-language, wearable sync, analytics | Decide based on beta feedback |

---

## 15. Progress Log (Agent: update after each milestone)

```
Current milestone: 1 (not started)

Completed:
- (none yet)

Known issues / TODO:
- (none yet)

Decisions made:
- (none yet)
```

---

## 16. Definition of Done (for any task)

- Feature works on the target platform and evidence is shown
- `flutter analyze` is clean and relevant tests pass
- No secrets committed, and RLS is in place for new tables
- Theme (light and dark) verified
- Progress Log updated and changes committed to Git
