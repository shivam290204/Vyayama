# Vyayama 🧘‍♀️

> **"Every effort counts."**

Vyayama is a premium, feature-rich fitness and consistency-tracking app built with Flutter. It's designed to not just track workouts, but to celebrate consistency and effort through an interactive, encouraging mascot companion.

## Features
- **Smart Workout Planner**: Build custom workout plans or use system templates.
- **Exercise Library**: A robust library of exercises featuring SVG-based alternating pose animations and detailed form checklists.
- **Mascot Companion**: An interactive mascot that reacts to your consistency and effort with different moods and supportive messages.
- **Social Snaps & Streaks**: Share quick workout snaps with friends, maintain streaks, and celebrate wins together.
- **Nutrition & Health**: Track meals, review dietary restrictions, and sync data seamlessly with Apple HealthKit and Android Health Connect.

## Tech Stack
- **Framework**: Flutter (Dart)
- **State Management**: Riverpod
- **Backend**: Supabase (Postgres & Auth)
- **Routing**: `go_router`
- **Animations**: `flutter_svg` (MVP poses), `lottie`, `rive`
- **Integrations**: `health`, `camera`, `google_mlkit_image_labeling`, `firebase_messaging`

## Getting Started

1. **Prerequisites**: Ensure you have Flutter (>=3.27.0) installed on your machine.
2. **Environment Variables**: Create a `.env` file at the root of the project to connect to your Supabase instance:
   ```env
   SUPABASE_URL=your_supabase_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   ```
3. **Install Dependencies**:
   ```bash
   flutter pub get
   ```
4. **Run the App**:
   ```bash
   flutter run
   ```

## Development & Safety
All new exercises added to the library must pass the internal form and safety check. Please refer to [REVIEW_CHECKLIST.md](./REVIEW_CHECKLIST.md) before submitting updates to `assets/data/exercises.json`.

---
*Developed with focus on accessibility, scalability, and premium dark-mode aesthetics.*
