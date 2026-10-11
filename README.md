# Vyayama 🧘‍♂️

<div align="center">

> *"Every effort counts."*

[![Flutter](https://img.shields.io/badge/Flutter-3.27+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.6+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Backend-Supabase-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Tests](https://img.shields.io/badge/Tests-314%20Passing-brightgreen?logo=checkmarx&logoColor=white)](./test)
[![License](https://img.shields.io/badge/License-Proprietary-blue.svg)](#license)

**Vyayama** is a modern, cross-platform fitness and wellness application built with Flutter. Unlike traditional fitness trackers that induce guilt or overwhelm users with complex metrics, Vyayama celebrates consistency, habit-building, and effort through a dynamic emotional mascot, Snapchat-style exercise photo streaks, condition-aware workout planning, and holistic wellness routines.

</div>

---

## 🌟 Table of Contents
- [✨ Key Highlights & What App Can Do](#-key-highlights--what-app-can-do)
- [🎨 Design System & Visual Identity](#-design-system--visual-identity)
- [📱 Core Features & Modules](#-core-features--modules)
  - [1. Dynamic Mascot Companion](#1-dynamic-mascot-companion)
  - [2. Tracking Dashboard & Daily Activity](#2-tracking-dashboard--daily-activity)
  - [3. Goal-Based & Custom Workout Engine](#3-goal-based--custom-workout-engine)
  - [4. Exercise Library & Animation Pipeline](#4-exercise-library--animation-pipeline)
  - [5. Friends, Snaps & Snap Streaks](#5-friends-snaps--snap-streaks)
  - [6. Health Profile & Adapted Workouts](#6-health-profile--adapted-workouts)
  - [7. Daily Schedule & Time Blocking](#7-daily-schedule--time-blocking)
  - [8. Nutrition & Water Tracking](#8-nutrition--water-tracking)
  - [9. Sleep, Wake & Wind-Down Routine](#9-sleep-wake--wind-down-routine)
  - [10. Daily Boost: Quotes, Memes & Challenges](#10-daily-boost-quotes-memes--challenges)
- [🛠️ Tech Stack & Architecture](#️-tech-stack--architecture)
- [📂 Project Directory Structure](#-project-directory-structure)
- [🚀 Getting Started](#-getting-started)
- [🧪 Testing & Quality Assurance](#-testing--quality-assurance)
- [🔒 Privacy & Medical Disclaimer](#-privacy--medical-disclaimer)

---

## ✨ Key Highlights & What App Can Do

- **Emotional Accountability**: A high-fidelity 3D mascot sits at the top of your home dashboard, dynamically reacting to how much you've accomplished today.
- **Visual Proof Over Vanity Metrics**: Capture real exercise moments with an in-app camera, verify workout authenticity with on-device ML / Cloud Vision, and keep pair Snap Streaks alive with friends.
- **Safety First & Medical Adaptation**: Automatically excludes exercises contraindicated by health conditions (e.g. knee pain, lower back issues, hypertension, asthma) and schedules exact offline medicine and meal reminders.
- **All-in-One Daily Rhythm**: Unifies your workouts, nutrition goals, hydration, sleep hygiene, and daily schedule into a single, cohesive daily timeline.
- **Offline-First & Cloud-Synced**: Operates fully offline with local caches and bundled content, while seamlessly synchronizing with Supabase when connected.

---

## 🎨 Design System & Visual Identity

Vyayama uses a curated **Forest Green & Lime Green** color palette designed to feel energizing, fresh, healthy, and premium:

| Token | Hex | Role |
| :--- | :--- | :--- |
| **Forest Green** | `#14532D` | Primary brand color, hero buttons, and primary actions |
| **Deep Green** | `#2E7D32` | Secondary actions, card accents, and subheadings |
| **Lime Green** | `#8BCF45` | Progress indicators, streak counters, active states, and highlights |
| **Soft Lime** | `#DDF2B5` | Badge surfaces, chip backgrounds, and soft highlights |
| **Off White** | `#F7F8F2` | Primary light mode background |
| **Charcoal Green** | `#202820` | Dark mode card surfaces and high-contrast text |
| **Soft Coral** | `#FFB49F` | Rest alerts, gentle warnings, and mascot accents |

### Visual Polish
- **Rounded Aesthetics**: Standardized border radiuses across all cards (`20–24px`) and images (`16–24px`).
- **Responsive Layout**: Fluid layouts that scale elegantly across mobile phones, tablets, and desktop browsers.
- **Full Theme Support**: Light Mode and Dark Mode with smooth transitions and glassmorphism accents.

---

## 📱 Core Features & Modules

### 1. Dynamic Mascot Companion
The top of the home screen features Vyayama's emotional character companion that visually reflects daily progress across 6 key accomplishments (Steps, Active Calories, Active Minutes, Workout, Hydration, Daily Challenge):
- **Nothing Done (0 items)**: Displays `Sad_Drooped_Head.png` with supportive, empathetic nudges reminding you that every journey starts with a single step.
- **In Progress (4 to 5 items)**: Displays `flex_proud.png` flexing proudly with high-energy motivational messages as you approach full completion.
- **All Goals Conquered (100%)**: Displays `Fire_Determined.png` surrounded by flames with celebratory champion messages.
- **Interactive Progress Badge**: Shows live progress (e.g., `4 / 6 Done`) with one-tap preview cycling for easy testing.
- **Speech Bubble**: Context-aware messages personalized with the user's name that cycle on tap.

### 2. Tracking Dashboard & Daily Activity
- **Activity Rings**: Animated concentric progress rings tracking **Steps**, **Active Calories (kcal)**, and **Active Time (minutes)**.
- **Health Integrations**: Connects with **Apple HealthKit** (iOS) and **Android Health Connect** (`health` package) with mock data fallback for Web/preview.
- **Custom Targets**: Goal-adjusted daily targets (weight loss, muscle gain, maintenance) using Mifflin-St Jeor TDEE formulas.

### 3. Goal-Based & Custom Workout Engine
- **System Curated Plans**: Built-in workout programs tailored for fat loss, hypertrophy, and general fitness across Beginner, Intermediate, and Advanced tiers.
- **Custom Plan Builder**: Create personalized routines by selecting exercises, reordering sets, configuring repetitions, and scheduling training days.
- **Active Workout Session Player**:
  - Live interval and exercise timers.
  - Form guidance notes and common mistakes checklist.
  - Rest countdowns with audio/visual feedback.
  - Post-workout completion summary logging XP and stats.

### 4. Exercise Library & Animation Pipeline
- **Extensive Exercise Database**: Detailed instructions, targeted muscle groups, equipment requirements, and injury contraindications.
- **Pluggable Visual Renderer**:
  - **3D Character Renders**: High-resolution studio poses.
  - **SVG Alternating Pose Renderer**: Lightweight, fluid start/finish animations.
  - **Lottie & Video Support**: Video demonstrations with rounded thumbnail previews.

### 5. Friends, Snaps & Snap Streaks
- **In-App Exercise Camera**: Full-screen photo capture with flash, timer, and front/back camera toggling.
- **Activity Tags & Overlays**: Tag workouts (Running, Yoga, Gym, Walking, Cycling) and stamp dynamic stickers (steps count, timestamp).
- **Pair Snap Streaks**: Shared streak between two friends that advances only when **both** send verified workout snaps within the streak window.
- **Verification Engine**: Dual verification via on-device **Google ML Kit Image Labeling** and server-side vision AI on Supabase Edge Functions.
- **Friends Hub**: Add friends via unique username, invite links, or QR code scanning. View friends feed and send instant emoji reactions (`🔥`, `💪`, `👏`).

### 6. Health Profile & Adapted Workouts
- **Injury & Condition Screening**: Select pre-existing conditions (e.g., knee pain, lower back pain, asthma, hypertension, diabetes).
- **Automatic Exercise Filtering**: Unsafe movements are automatically excluded and replaced with joint-friendly alternatives.
- **Medicine Reminders**: Schedule exact daily times for medications with offline local alarms.
- **Medical Disclaimers**: Transparent safety banners emphasizing that Vyayama provides wellness guidance, not medical diagnosis.

### 7. Daily Schedule & Time Blocking
- Interactive daily agenda mapping out training sessions, meals, medicine times, and wind-down blocks.
- Smart missed-block detection that prompts the mascot to provide gentle accountability when a routine is missed.

### 8. Nutrition & Water Tracking
- **Smart Water Tracker**: Interactive glass-by-glass hydration logger calculating daily water targets based on body weight.
- **Meal Reminders**: Timely notifications for breakfast, lunch, and dinner.
- **Personalized Food Recommendations**: Tailored "Eat More" and "Limit" lists filtered by dietary preferences (Vegetarian, Non-Veg, Vegan) and medical conditions.

### 9. Sleep, Wake & Wind-Down Routine
- Work-schedule-aware sleep and wake recommendations aiming for the optimal 7–9 hour recovery window.
- Pre-sleep wind-down checklist and guidance on evening nutrition (foods to avoid before bed).

### 10. Daily Boost: Quotes, Memes & Challenges
- **Daily Challenge**: Fresh daily fitness challenges awarding XP and level progression upon completion.
- **Morning Quotes & Evening Health Memes**: Curated daily motivation cards to keep morale high.

---

## 🛠️ Tech Stack & Architecture

| Layer | Technologies |
| :--- | :--- |
| **Frontend Framework** | **Flutter 3.27+** (Dart 3.6+) |
| **State Management** | **Riverpod** (`flutter_riverpod`, `AsyncNotifier`, `NotifierProvider`) |
| **Navigation & Routing** | **go_router** (declarative routing with auth redirect guards) |
| **Backend & Database** | **Supabase** (PostgreSQL, Row Level Security, Storage, Edge Functions) |
| **Local Storage** | `shared_preferences`, bundled JSON databases |
| **Device & Sensor APIs** | `health`, `camera`, `flutter_local_notifications`, `timezone`, `permission_handler` |
| **On-Device Vision** | `google_mlkit_image_labeling` |
| **UI & Styling** | Custom Material 3 Design System (`AppTheme`, `AppPalette`, Google Fonts) |

---

## 📂 Project Directory Structure

```text
FitBuddy/
├── assets/
│   ├── data/                 # exercises.json, quotes.json, memes.json, diet_tips.json
│   ├── exercises/            # 3D full-body exercise poses & demonstrations
│   ├── images/
│   │   ├── mascot/           # 3D mascot renders (Sad, Flex, Fire, etc.)
│   │   └── logo.png          # App brandmark
│   └── audio/                # Sound effects for workout milestones
├── lib/
│   ├── core/
│   │   ├── router/           # go_router configuration & route guards
│   │   ├── services/         # HealthKit/HealthConnect & Notification service
│   │   ├── theme/            # AppTheme, AppPalette, typography & spacing
│   │   └── widgets/          # Reusable design system cards, headers & buttons
│   ├── features/
│   │   ├── auth/             # Sign-in, sign-up, splash & password reset
│   │   ├── challenges/       # Daily challenges, streaks & XP system
│   │   ├── dashboard/        # Activity rings, daily stats & body metrics
│   │   ├── friends/          # Friends list, friend requests & QR connect
│   │   ├── health_profile/   # Health conditions & medicine reminders
│   │   ├── home/             # MascotSection, Today's workout & daily blocks
│   │   ├── mascot/           # MoodEngine, debug panel & fallback renderer
│   │   ├── motivation/       # Daily boost quotes & wellness memes
│   │   ├── nutrition/        # Water tracker, meal recommendations & diet tips
│   │   ├── onboarding/       # Multi-step profile & goal setup flow
│   │   ├── profile/          # User profile management & account lifecycle
│   │   ├── schedule/         # Daily time blocks & timeline actions
│   │   ├── sleep/            # Sleep schedule, smart wake & wind-down cards
│   │   ├── snap_streaks/     # Pair streak calculation & status panel
│   │   ├── snaps/            # In-app camera, sticker overlay & signed URLs
│   │   └── workouts/         # Plans, builder, active session & exercise details
│   └── main.dart             # App entry point & initialization
├── supabase/
│   ├── migrations/           # 100+ SQL migrations with strict RLS policies
│   └── functions/            # Edge functions (e.g., verify-snap vision model)
└── test/                     # 314 unit, widget & integration tests
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.27.0`)
- [Dart SDK](https://dart.dev/get-dart) (`>= 3.6.0`)
- Git

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/shivam290204/Vyayama.git
   cd Vyayama
   ```

2. **Configure environment variables**:
   Create a `.env` file in the project root:
   ```env
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key-here
   ```
   *(Note: The app runs with built-in mock fallbacks if Supabase is not configured, allowing complete UI and feature exploration.)*

3. **Install dependencies**:
   ```bash
   flutter pub get
   ```

4. **Run the application**:
   - **Chrome / Web**:
     ```bash
     flutter run -d chrome
     ```
   - **Android / iOS Device**:
     ```bash
     flutter run
     ```

---

## 🧪 Testing & Quality Assurance

Vyayama maintains high code quality and test coverage across state providers, repositories, and widget trees:

- **Run all automated tests** (314 tests):
  ```bash
  flutter test
  ```
- **Run static analysis** (0 warnings / lint-clean):
  ```bash
  flutter analyze
  ```
- **Build production web bundle**:
  ```bash
  flutter build web
  ```

---

## 🔒 Privacy & Medical Disclaimer

- **Privacy First**: Workout photos shared through Snaps are strictly private to accepted friends, signed with secure time-limited URLs, and expire automatically after 24 hours. No public photo feeds or gallery uploads are permitted.
- **Medical Disclaimer**: Vyayama provides general lifestyle, fitness, and wellness reminders. It is **not** a medical device and does not offer medical advice, diagnosis, or prescription dosages. Users with pre-existing cardiovascular, musculoskeletal, or metabolic conditions should consult a physician before starting any exercise regimen.

---

<div align="center">

Built with ❤️ for health, consistency, and daily progress.  
**Vyayama** — *Every effort counts.*

</div>
