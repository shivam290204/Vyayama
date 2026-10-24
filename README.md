# Vyayama 🧘‍♂️

<div align="center">

> *"Every effort counts. A companion that celebrates your consistency."*

[![Flutter](https://img.shields.io/badge/Flutter-3.27+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.6+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android%20Target-API%2036%20(Android%2016)-3DDC84?logo=android&logoColor=white)](https://developer.android.com)
[![Backend](https://img.shields.io/badge/Backend-Supabase%20PostgreSQL-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Tests](https://img.shields.io/badge/Tests-471%20Passing%20(100%25)-brightgreen?logo=checkmarx&logoColor=white)](./test)
[![Static Analysis](https://img.shields.io/badge/Analysis-0%20Issues-brightgreen)](https://dart.dev/tools/analysis)
[![License](https://img.shields.io/badge/License-Proprietary-blue.svg)](#license)

**Vyayama** is a modern, cross-platform fitness and holistic wellness application built with Flutter and Supabase. Unlike conventional fitness trackers that induce guilt or overwhelm users with sterile spreadsheets of numbers, Vyayama celebrates consistency, habit-building, and effort through a dynamic emotional mascot, Snapchat-style exercise photo streaks, self-reported condition and sensitivity-aware workout suggestions, integrated BMI physical metrics, and a unified 24-hour daily rhythm.

</div>

---

## 🌟 Table of Contents
- [✨ Key Highlights & What Sets Vyayama Apart](#-key-highlights--what-sets-vyayama-apart)
- [🎨 Design System & Visual Identity](#-design-system--visual-identity)
- [📱 Deep Dive: Core Features & Modules](#-deep-dive-core-features--modules)
  - [1. Dynamic Mascot Companion & Mood Engine](#1-dynamic-mascot-companion--mood-engine)
  - [2. Tracking Dashboard & Activity Rings](#2-tracking-dashboard--activity-rings)
  - [3. Goal-Based & Custom Workout Engine](#3-goal-based--custom-workout-engine)
  - [4. Exercise Library & 3D Pose Animation Pipeline](#4-exercise-library--3d-pose-animation-pipeline)
  - [5. Friends, Snaps & Dual-Proof Snap Streaks](#5-friends-snaps--dual-proof-snap-streaks)
  - [6. Community Teams & Leaderboards](#6-community-teams--leaderboards)
  - [7. Health Profile & Self-Reported Condition Preferences](#7-health-profile--self-reported-condition-preferences)
  - [8. Body Mass Index (BMI) & Biometric Metrics Hub](#8-body-mass-index-bmi--biometric-metrics-hub)
  - [9. Daily Schedule & Time Blocking](#9-daily-schedule--time-blocking)
  - [10. Nutrition, Meal Guidance & Smart Hydration](#10-nutrition-meal-guidance--smart-hydration)
  - [11. Circadian Sleep Schedule & Wind-Down Routine](#11-circadian-sleep-schedule--wind-down-routine)
  - [12. Daily Boost: XP Progression, Quotes & Memes](#12-daily-boost-xp-progression-quotes--memes)
- [🛠️ Tech Stack & Architecture](#️-tech-stack--architecture)
- [📂 Project Directory Structure](#-project-directory-structure)
- [🗄️ Database Architecture & Migrations](#️-database-architecture--migrations)
- [🚀 Getting Started & Local Development](#-getting-started--local-development)
- [📦 Release & Production Builds](#-release--production-builds)
- [🧪 Testing & Quality Assurance](#-testing--quality-assurance)
- [🔒 Security, Privacy & Google Play Compliance](#-security-privacy--google-play-compliance)
- [📄 Medical Disclaimer](#-medical-disclaimer)

---

## ✨ Key Highlights & What Sets Vyayama Apart

- **Emotional Accountability**: A 3D companion character anchors the home dashboard, dynamically morphing across emotional states based on how much of your daily wellness checklist has been conquered.
- **Visual Proof Over Vanity Metrics**: Capture real exercise moments with an in-app camera, verify workout authenticity via on-device ML Kit image labeling and server-side vision AI, and build pair Snap Streaks with workout partners.
- **Rule-Based Sensitivity Filtering**: Automatically cross-references self-reported sensitivities (such as knee or lower back discomfort, hypertension, or asthma) against exercise tags and excludes contraindicated movements, suggesting lower-impact alternatives. (Note: Form guidance is general and unreviewed by a medical professional; does not diagnose, treat, or rehabilitate injuries.)
- **Streamlined Physical Metrics (BMI Hub)**: Profile metrics are centered around an integrated Body Mass Index (BMI) hub that brings Height and Weight together with WHO classifications, trend history, and actionable health guidance.
- **Unified 24-Hour Daily Rhythm**: Eliminates the need for 5 separate apps by coordinating training sessions, meals, medicine times, hydration intervals, and sleep wind-down blocks into a single agenda.
- **Offline-First Resilience**: Full operational support when offline via local caching and bundled asset databases, paired with automated cloud sync when network connectivity is restored.
- **Standard Security & Privacy**: Hardware-backed session encryption (Android KeyStore / iOS Keychain), PostgreSQL Row Level Security (RLS) on user tables, compile-time/environment-based credentials with zero committed secrets, and fully compliant two-tier account deletion.

---

## 🎨 Design System & Visual Identity

Vyayama utilizes a curated **Forest Green & Lime Green** color palette engineered to feel energizing, organic, fresh, and premium:

| Token | Hex | Semantic Role |
| :--- | :--- | :--- |
| **Forest Green** | `#14532D` | Primary brand surface, hero buttons, and primary app bar actions |
| **Deep Green** | `#2E7D32` | Secondary actions, interactive cards, and section subheadings |
| **Lime Green** | `#8BCF45` | Progress ring indicators, active streak counters, and success states |
| **Soft Lime** | `#DDF2B5` | Badge surfaces, chip backgrounds, and highlighted status pills |
| **Off White** | `#F7F8F2` | Light mode primary canvas and background |
| **Charcoal Dark** | `#121612` | Dark mode primary canvas and deep surface styling |
| **Elevated Dark** | `#1E251E` | Dark mode card containers and navigation bar styling |
| **Soft Coral** | `#FFB49F` | Rest day indicators, recovery warnings, and mascot accents |

### Visual Principles & Polish
- **Standardized Radiuses**: Consistent `16–24px` border corners across cards, buttons, dialogs, and image containers.
- **Adaptive Typography**: Google Fonts typography hierarchy (Inter / Outfit) optimized for readability, accessibility, and high contrast.
- **Responsive Layouts**: Fully responsive layouts scaling across compact phones, tall aspect ratios, foldable devices, tablets, and desktop/web viewports.
- **Dynamic Theming**: Seamless transitions between **Light**, **Dark**, and **System Default** themes.

---

## 📱 Deep Dive: Core Features & Modules

### 1. Dynamic Mascot Companion & Mood Engine
At the top of the home screen, Vyayama's mascot companion visually reflects daily accomplishments across 6 core pillars (Steps, Active Calories, Active Minutes, Workout Completed, Hydration Met, Daily Challenge):
- **Nothing Done (0 items)**: The mascot adopts a drooped, empathetic posture (`Sad_Drooped_Head.png`) offering gentle encouragement that every big journey begins with a single step.
- **Building Momentum (1 to 3 items)**: The mascot stands alert and energetic, urging you onward as you complete routine tasks.
- **Crushing It (4 to 5 items)**: The mascot flexes proudly (`flex_proud.png`) with enthusiastic, high-energy praise.
- **All Goals Conquered (6 / 6 Done - 100%)**: Surrounded by victorious flames (`Fire_Determined.png`), the mascot celebrates full completion as a daily champion.
- **Interactive Speech Bubbles**: Tap the mascot to cycle through personalized, context-aware motivational remarks addressed to the user.

### 2. Tracking Dashboard & Activity Rings
- **Concentric Activity Rings**: Smooth animated rings visualizing **Steps**, **Active Calories (kcal)**, and **Active Time (minutes)**.
- **Health Connect & Apple HealthKit**: Reads native steps and calories from on-device hardware sensors, Google Health Connect (Android 14–16), and Apple HealthKit (iOS).
- **Mifflin-St Jeor TDEE Engine**: Calculates personalized calorie and hydration baselines according to age, gender, height, weight, and fitness goal.

### 3. Goal-Based & Custom Workout Engine
- **Curated Multi-Week Programs**: Built-in workout splits designed for **Fat Loss**, **Hypertrophy**, **Endurance**, and **Mobility** across Beginner, Intermediate, and Advanced tiers.
- **Custom Routine Builder**: Assemble personalized workouts with exercise selection, drag-and-drop reordering, custom set/rep targets, and rest intervals.
- **Interactive Session Player**:
  - Live interval and exercise timers with visual countdown wheels.
  - Audio cues and milestone sound effects for set completion and rest periods.
  - Form guidance notes and "Common Mistakes to Avoid" checklist.
  - Post-workout summary dialog logging XP, duration, and calories burned.

### 4. Exercise Library & 3D Pose Animation Pipeline
- **Extensive Exercise Database**: Over 100+ exercises with primary/secondary muscle targets, equipment requirements, execution steps, and common mistakes.
- **Unreviewed General Form Guidance**: Form instructions and cues are general guidelines and have not yet been reviewed or approved by a licensed personal trainer or physiotherapist. The app displays visible notices reminding users until individual professional reviews are completed.
- **Multi-Format Visual Demonstrations**:
  - **High-Resolution 3D Poses**: Full-body anatomical renders illustrating general movement trajectory.
  - **Alternating SVG Animations**: Lightweight vector animations showing starting and contracted positions.
  - **Video Previews**: Video tutorial previews for dynamic exercises requiring continuous motion analysis.

### 5. Friends, Snaps & Dual-Proof Snap Streaks
- **In-App Exercise Camera**: Full-screen photo capture with flash toggle, front/back camera switching, and timer.
- **Dynamic Workout Watermarks**: Automatic on-canvas stamps embedding current steps, active minutes, timestamp, and activity category tags.
- **Dual-Proof Verification Pipeline**:
  - **On-Device ML**: Google ML Kit Image Labeling verifies exercise gear, athletic apparel, and workout contexts locally on-device.
  - **Cloud Vision Verification**: Supabase Edge Functions inspect exercise authenticity before advancing streak records.
- **Pair Snap Streaks**: Shared streak counters between fitness partners that advance only when **both** participants submit verified workout snaps within the 24-hour window.
- **24-Hour Ephemeral Privacy**: All snap photos automatically expire and are purged from storage after 24 hours.

### 6. Community Teams & Leaderboards
- **Team Workouts**: Join or create community teams to collaborate on weekly step targets and group workout volume.
- **Collaborative Leaderboards**: Track teammate contributions and cheer peer achievements.
- **Safe Team Ownership Transfer**: If a team creator deletes their account, team ownership automatically transfers to the longest-standing active member, preserving community records.

### 7. Health Profile & Self-Reported Condition Preferences
- **Self-Reported Sensitivity Profiles**: Configurable health preferences covering user-flagged joint sensitivities (knee, lower back, shoulder) and personal health notes (hypertension, asthma).
- **Rule-Based Movement Filtering**: Exercises tagged as contraindicated for user-flagged sensitivities are excluded from recommendations and replaced with lower-impact alternatives. (The app does not provide medical screening, injury diagnosis, physical therapy, or rehabilitation.)
- **Local Medication Alarms**: Schedule offline medication alarms using Android exact alarm channels (`SCHEDULE_EXACT_ALARM`) with battery-optimization diagnostics. (Reminders only; never dosage or medical advice.)

### 8. Body Mass Index (BMI) & Biometric Metrics Hub
- **Streamlined 2x2 Profile Grid**: Profile stats are organized into a clean 2x2 grid displaying **Goal**, **Fitness Level**, **Age**, and **Gender**.
- **Integrated BMI Card**:
  - Displays real-time **Height** and **Weight** with seamless Metric (`cm` / `kg`) and Imperial (`ft/in` / `lbs`) conversion.
  - Real-time WHO classification badge (Underweight, Normal, Overweight, Obesity, Pediatric) rendered with distinct semantic status colors.
  - Continuous BMI meter bar with personalized health guidance text.
  - Direct measurement logging and chronological BMI history tracking.

### 9. Daily Schedule & Time Blocking
- **24-Hour Visual Agenda**: Visual timeline organizing workouts, meal windows, hydration check-ins, medication times, and evening wind-down blocks.
- **Missed Block Detection**: Identifies overdue agenda items and nudges the user to stay on track.

### 10. Nutrition, Meal Guidance & Smart Hydration
- **Dynamic Water Intake Calculator**: Computes target hydration volume based on body weight, daily step count, and climate.
- **Interactive Glass Logger**: Tap-to-log water tracker visualizing remaining daily hydration targets.
- **Dietary Recommendations**: Curated "Eat More" and "Limit" food guidance filtered by dietary lifestyle (Vegetarian, Vegan, Non-Vegetarian) and medical conditions.

### 11. Circadian Sleep Schedule & Wind-Down Routine
- **Circadian Rhythm Planner**: Formulates target bedtime and wake-up times for the recommended 7–9 hour restorative sleep window.
- **Pre-Sleep Wind-Down Checklist**: Evening checklist promoting blue-light reduction, stretching, hydration cutoff, and room temperature optimization.

### 12. Daily Boost: XP Progression, Quotes & Memes
- **XP & Level Milestones**: Earn experience points for logging workouts, drinking water, hitting step goals, and keeping streaks alive.
- **Curated Motivational Content**: Daily rotating fitness quotes and wholesome health memes to keep morale high.

---

## 🛠️ Tech Stack & Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                       Flutter UI Layer                      │
│     Material 3  •  AppTheme  •  Google Fonts  •  Lottie     │
├─────────────────────────────────────────────────────────────┤
│                    State & Route Management                 │
│        flutter_riverpod (AsyncNotifier)  •  go_router       │
├─────────────────────────────────────────────────────────────┤
│                      Domain & Services                      │
│   Health Connect  •  Exact Alarms  •  Google ML Kit Vision  │
├─────────────────────────────────────────────────────────────┤
│                    Offline Caching & Security               │
│   SecureAuthStorage (KeyStore / AES) • SharedPreferences    │
├─────────────────────────────────────────────────────────────┤
│                     Cloud & Backend Layer                   │
│   Supabase (PostgreSQL 15, RLS, Storage, Edge Functions)    │
└─────────────────────────────────────────────────────────────┘
```

| Layer | Technology | Purpose |
| :--- | :--- | :--- |
| **Framework** | **Flutter 3.27+** (Dart 3.6+) | Cross-platform client application |
| **State Management** | **flutter_riverpod 2.6.1** | Declarative, reactive, testable state management |
| **Routing** | **go_router 14.6.2** | Declarative URL-based routing with auth state guards |
| **Backend & Database** | **Supabase** (PostgreSQL 15) | Relational database, Row Level Security, Storage & Auth |
| **Session Security** | **flutter_secure_storage 9.2.2** | Hardware-encrypted storage for auth tokens and keys |
| **Health & Sensors** | **health 13.3.1** | Health Connect (Android 14-16) & HealthKit (iOS) |
| **Notifications** | **flutter_local_notifications 18.0.1** | High-priority alarms, medication & hydration reminders |
| **On-Device Vision** | **google_mlkit_image_labeling 0.14.0** | On-device ML validation for exercise snap authenticity |
| **Target Platform** | **Android API 36 (Android 16)** | Full compliance with current Google Play store standards |

---

## 📂 Project Directory Structure

```text
vyayama/
├── android/                  # Native Android host configuration (Target API 36, Keystore)
├── assets/
│   ├── audio/                # Set completion chimes and countdown audio
│   ├── data/                 # Bundled JSON databases (exercises, diet tips, quotes, memes)
│   ├── exercises/            # 3D full-body exercise poses & video assets
│   ├── images/
│   │   ├── mascot/           # 3D mascot emotional states (Sad, Flex, Fire)
│   │   └── logo.png          # App brandmark
│   └── icons/                # High-contrast application icons
├── lib/
│   ├── core/
│   │   ├── router/           # go_router definitions, route paths & auth redirect logic
│   │   ├── services/         # HealthKit/HealthConnect, Exact Alarms, Workmanager
│   │   ├── theme/            # AppTheme, AppPalette, AppSpacing, Typography
│   │   ├── utils/            # UnitConversion (metric/imperial), TDEE formulas
│   │   └── widgets/          # Shared atomic components (cards, badges, buttons)
│   ├── features/
│   │   ├── auth/             # Sign-in, sign-up, password recovery & SecureAuthStorage
│   │   ├── challenges/       # XP progression, levels, daily challenges
│   │   ├── dashboard/        # Activity rings, daily stats & Mifflin-St Jeor TDEE
│   │   ├── friends/          # Friend list, friend request RPCs, QR code connect
│   │   ├── health_profile/   # Health conditions, contraindications, medicine alarms
│   │   ├── home/             # MascotSection, Today's workout & daily blocks
│   │   ├── mascot/           # MoodEngine, 6-stage emotional progression
│   │   ├── motivation/       # Daily boost quotes, wellness memes, audio feedback
│   │   ├── nutrition/        # Water tracker, meal notifications, diet recommendations
│   │   ├── onboarding/       # Multi-step onboarding questionnaire
│   │   ├── profile/          # Profile screen, 2x2 stats grid, BMI hub & account deletion
│   │   ├── schedule/         # 24-hour time blocks & missed block detection
│   │   ├── settings/         # Unit system, theme preferences, alarm diagnostics
│   │   ├── sleep/            # Circadian sleep schedule, smart wake, wind-down checklist
│   │   ├── snap_streaks/     # Pair streak calculations & grace periods
│   │   ├── snaps/            # In-app exercise camera, watermarks & vision verification
│   │   ├── teams/            # Workout teams, group challenges, leaderboards
│   │   └── workouts/         # Workout plans, custom builder & active session player
│   └── main.dart             # Application initialization & provider root
├── supabase/
│   ├── migrations/           # 16 SQL migrations with strict RLS policies & RPCs
│   └── functions/            # Edge functions (verify-snap vision model)
└── test/                     # 471 unit, widget, and integration tests
```

---

## 🗄️ Database Architecture & Migrations

Vyayama's backend runs on **Supabase PostgreSQL 15** with Row Level Security (RLS) enabled across every table:

| Migration File | Key Tables & Responsibilities |
| :--- | :--- |
| `001_profiles_and_auth_trigger.sql` | `profiles` table, automatic profile provisioning on auth signup |
| `002_exercises_and_plans.sql` | `exercises`, `workout_plans`, `workout_plan_exercises` |
| `003_logs_stats_schedule_streaks.sql` | `workout_logs`, `daily_stats`, `schedule_blocks`, `challenges` |
| `004_health.sql` | `health_conditions`, `medication_reminders` |
| `005_friendships.sql` | `friendships` table with mutual acceptance state machine |
| `006_snaps_streaks_devices_reports.sql` | `snaps` (ephemeral), `snap_streaks`, `device_tokens`, `reports` |
| `007_teams.sql` | `teams`, `team_memberships`, `team_challenges` |
| `008_account_deletion.sql` | Two-tier `delete_my_account()` RPC cascading through user data |
| `009_indexes.sql` | Performance composite indexes on user foreign keys and timestamps |
| `010_friend_qr_and_profile_lookup.sql` | Privacy-safe QR code scan and username lookup functions |
| `011_friend_requests_rpc.sql` | Atomic friend request dispatch, accept, and reject RPCs |
| `012_fix_friendships_and_profiles.sql` | Granular profile read policies restricted to accepted friends |
| `013_fix_snaps_verification_feed.sql` | Private storage policies and friend-only snap feed visibility |
| `014_bmi_records.sql` | `bmi_records` table tracking chronological height, weight & BMI history |
| `015_security_privacy_hardening.sql` | Revokes public RPC execution; restricts verification to `service_role` |
| `100_snap_streak_functions.sql` | Real-time pair streak calculation and timezone-aware midnight reset |

---

## 🚀 Getting Started & Local Development

### Prerequisites
- **Flutter SDK**: `>= 3.27.0` ([Installation Guide](https://docs.flutter.dev/get-started/install))
- **Dart SDK**: `>= 3.6.0`
- **Git**
- **Android Studio** (with Android 16 / API 36 SDK platform installed) or **Xcode** (for iOS builds)

### Step-by-Step Setup

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/shivam290204/Vyayama.git
   cd Vyayama
   ```

2. **Configure Environment Variables**:
   Configuration is read from compile-time `--dart-define` flags or a local `.env` file in the project root:
   ```bash
   cp .env.example .env
   ```
   Add your live project credentials to `.env`:
   ```env
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key-here
   ```
   *Behavior when configuration is omitted:*
   - **Debug Builds**: The app automatically runs in **Mock Mode** using built-in mock repositories and displays a visible warning banner (`MOCK MODE — Supabase Not Configured`). This allows immediate UI and feature testing without requiring backend credentials.
   - **Release Builds**: The app displays a dedicated **Application Not Configured** screen explaining the missing keys rather than crashing or hanging.

3. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

4. **Run Code Generation (if modifying models)**:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

5. **Launch the Application**:
   - **Chrome / Web**:
     ```bash
     flutter run -d chrome
     # Or using the helper script:
     run_web.bat
     ```
   - **Android Device / Emulator**:
     ```bash
     flutter run -d android
     ```
   - **iOS Simulator / Device**:
     ```bash
     flutter run -d ios
     ```

---

## 📦 Release & Production Builds

Vyayama is configured for **Android 16 (API Level 36)** compliance. For production release builds, provide credentials via compile-time `--dart-define` parameters or via `.env`:

### 1. Release Keystore Configuration
Ensure `android/key.properties` exists and points to your release upload keystore:
```properties
storePassword=your-keystore-password
keyPassword=your-key-password
keyAlias=upload
storeFile=../upload-keystore.jks
```

### 2. Build Standalone Release APK
```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key-here
```
- Output: `build/app/outputs/flutter-apk/app-release.apk`
- Ready for direct installation and internal testing.

### 3. Build Google Play Release App Bundle (AAB)
```bash
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key-here
```
- Output: `build/app/outputs/bundle/release/app-release.aab`
- Fully optimized with R8/ProGuard code shrinking and resource optimization.

---

## 🧪 Testing & Quality Assurance

Vyayama maintains a rigorous test suite spanning Unit tests, Mock Repository tests, Riverpod State Notifier tests, and Widget trees:

```bash
# Run all 471 automated tests
flutter test

# Run static analysis (0 warnings / lint-clean)
flutter analyze
```

### Test Coverage Highlights
- **Auth & Session Persistence**: Verifies `SecureAuthStorage`, encrypted token persistence, and recovery deep link parsing.
- **Mascot MoodEngine**: Verifies correct 6-tier mascot emotional state transitions across all milestone combinations.
- **BMI & Unit Calculations**: Validates Mifflin-St Jeor formulas, Metric/Imperial conversions, and WHO BMI classifications.
- **Pair Snap Streaks**: Verifies dual-submission logic, grace periods, and streak freeze rules.
- **Condition Filtering**: Verifies that exercises contraindicated for specific injuries are excluded from custom and curated plans.

---

## 🔒 Security, Privacy & Google Play Compliance

- **Hardware-Backed Session Security**: Supabase session tokens and refresh tokens are encrypted at rest via `SecureAuthStorage` using Android KeyStore (AES-256) and iOS Keychain. Plaintext caching is strictly eliminated.
- **Row Level Security (RLS)**: Every single table in the Supabase PostgreSQL database enforces strict RLS policies. Users can never query, update, or delete records belonging to other users.
- **Ephemeral Exercise Snaps**: Workout photos are stored in private storage buckets requiring short-lived signed URLs and automatically expire within 24 hours.
- **Two-Tier Account Deletion**: Fully compliant with Google Play Data Safety policies. Tapping **Delete Account** in Settings:
  1. Purges all uploaded photos from Supabase Storage via the client SDK.
  2. Executes an atomic database transaction (`delete_my_account()`) that safely reassigns team ownership, cascades record deletions across all personal tables, and removes the auth account.
- **No Third-Party Trackers**: Vyayama contains **zero advertising SDKs**, zero third-party telemetry brokers, and does not sell or monetize personal or health data.

---

## 📄 Medical Disclaimer

> **Important**: Vyayama is designed exclusively as a lifestyle, habit-building, and wellness companion. It is **not** a licensed medical device and does not provide medical diagnosis, treatment, or clinical prescriptions. Users with cardiovascular conditions, chronic joint injuries, pregnancy, or metabolic disorders must consult a qualified physician or healthcare provider before undertaking any new physical training program.

---

<div align="center">

Built with ❤️ for health, consistency, and daily progress.  
**Vyayama** — *Every effort counts.*

</div>
