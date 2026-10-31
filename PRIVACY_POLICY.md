# Privacy Policy for Vyayama

**Last Updated:** October 31, 2026  
**Effective Date:** October 31, 2026  

Welcome to **Vyayama** ("we", "our", or "us"). Your privacy is fundamental to how we build our application. This Privacy Policy explains clearly, transparently, and accurately how we collect, store, protect, process, synchronize, and delete your personal, fitness, health, and location information when you use the Vyayama mobile application.

---

## 1. Information We Collect

### A. Account & Profile Information
- **Account Details:** Email address, user ID, and display name provided during registration or authentication (email login, email OTP, or Google OAuth).
- **Profile Preferences:** Username, profile avatar, country/locale preferences, time zone, and app interface settings.

### B. Health, Fitness & Physical Activity Data
- **Physical Metrics:** Height, weight, Body Mass Index (BMI), and historical BMI progress records.
- **Physical Activity:** Daily step counts, step detection events, active calories burned, workout session logs (duration, exercises completed, sets, repetitions, and rest intervals).
- **Health Conditions & Medications (Optional):** User-volunteered health tags (e.g. knee sensitivity, asthma) and medicine reminder schedules used exclusively for workout adaptation and on-device schedule management.
- **Sleep & Rest Schedules:** Target sleep schedules, bedtime reminders, and wake-up alarm times.

### C. Precise GPS Location & Outdoor Route Data
- **Live GPS Coordinates:** High-precision latitude, longitude, altitude, bearing, and speed fixes collected during active user-initiated outdoor tracking sessions (walking, running, hiking).
- **GPS Fix Timestamps:** Exact UTC timestamps corresponding to each geographic fix, used to compute pacing, speed, and track duration.
- **Derived Outdoor Metrics:** Accumulated geodesic distance, elevation gain, average speed (km/h), and average pace (seconds/km).
- **Route Coordinates & Polylines:** Geographic waypoints and vector tracks recorded during workouts or saved to your personal route library.
- **Viewport Search Centers:** Geographic coordinates and bounding boxes centered on your current position or explicitly selected map locations during nearby route discovery.

### D. Workout Snaps & Social Interactions
- **Workout Photographs ("Snaps"):** Real-time exercise photos captured through the in-app camera to verify workout completion and maintain social streaks. Photo EXIF metadata (such as GPS location) is stripped prior to upload.
- **Social Connections:** Friend lists, friend request statuses, team memberships, and mutual workout streaks.

### E. Device & Technical Information
- **Device Sensors:** Hardware step counter sensor (`SENSOR_TYPE_STEP_COUNTER`) and step detector sensor readings processed locally on your device.
- **Notification Identifiers:** Native local notification channel identifiers for wake-up alarms, bedtime prompts, hydration reminders, and ongoing outdoor tracking status.

---

## 2. Why We Collect This Information (Purposes)

We collect and process your data strictly for legitimate health, fitness, and navigation features:
1. **Outdoor Workout Tracking & Navigation:** Recording your real-time path, distance, elevation, pace, and speed during outdoor runs, walks, and hikes.
2. **Local Route Discovery:** Locating pedestrian footways, paved paths, and hiking trails in the geographic area you are viewing.
3. **Crash & Battery Loss Recovery:** Maintaining local crash recovery checkpoints so unfinished workouts can be safely resumed if the device shuts down or the app process is terminated.
4. **Personalized Workout Adaptation:** Adapting exercise recommendations based on fitness level, equipment availability, and user-specified physical limitations.
5. **Activity & Habit Consistency:** Tracking daily steps, active calories burned, and hydration intervals.
6. **Workout Accountability:** Validating workout authenticity through privacy-conscious server-side verification to compute snap streaks and social challenges.

**We never sell, rent, monetize, or trade your personal, health, or location data to advertisers, data brokers, or third parties.**

---

## 3. Storage, Encryption & Local Data Realities

### A. Local Storage Architecture & Realities
- **Active Workout Checkpoints:**
  - During an ongoing outdoor workout, state is checkpointed to an isolated file: `vyayama_outdoor_checkpoint_v1.json` located in the app's private documents directory (`/data/user/0/com.vyayama.fitbuddy/app_flutter/` on Android, `~/Documents` on iOS).
  - **Storage Format:** Checkpoint files and local activity histories are stored as **plaintext UTF-8 JSON** within the app's operating-system sandbox. They are **not encrypted with application-level AES encryption at rest**. Access is protected by OS-level sandbox UID isolation; however, if a device is rooted, jailbroken, or subjected to forensic physical extraction, plaintext coordinates can be read.
  - **Integrity Verification:** Checkpoints are enveloped with a 32-bit CRC-32 checksum (`payload_crc32`). **CRC-32 is strictly an integrity check for accidental I/O corruption or torn writes; it is NOT encryption, authentication, or tamper-resistance.**
- **Saved Workout & Route History:**
  - Stored in app-private `SharedPreferences` on your device.
  - Supports full offline review without internet connectivity.
- **Authentication Credentials:**
  - Sensitive authentication tokens and session refresh keys are stored using hardware-backed secure storage (`FlutterSecureStorage` via Android KeyStore / EncryptedSharedPreferences and iOS Keychain).

### B. Transmission Security
- All network communication between Vyayama and remote servers is encrypted in transit using Transport Layer Security (TLS 1.2 / TLS 1.3 / HTTPS). Cleartext network traffic is strictly prohibited.

---

## 4. Third-Party Mapping, Routing & Infrastructure Services

When you use the Maps and Route Discovery features in Vyayama, location-related HTTP requests are transmitted to external services under the explicit application User-Agent: `Vyayama/1.0 (com.vyayama.fitbuddy)`. These third-party services receive specific data necessary to deliver mapping capabilities:

| External Service | Provider / Endpoint | Data Transmitted | Purpose |
|---|---|---|---|
| **OpenStreetMap Tile CDN** | `tile.openstreetmap.org` | Viewport bounding tile coordinates (X, Y, Zoom), Client IP | Fetching standard cartographic map tiles for display. |
| **Overpass API Mirrors** | `overpass-api.de`, `kumi.systems`, `private.coffee` | Geographic bounding box (South, West, North, East), Client IP | Querying mapped pedestrian ways, footways, and paths. |
| **Nominatim Geocoding** | `nominatim.openstreetmap.org` | Latitude and Longitude coordinate pair, Client IP | Reverse-geocoding coordinates into human-readable neighborhood/city names. |
| **Valhalla Routing Engine** | `valhalla1.openstreetmap.de` | Candidate start and waypoint coordinate pairs, Client IP | Calculating pedestrian routes, elevation profiles, turns, and distances. |
| **Supabase Cloud Infrastructure** | Supabase Inc. (AWS / PostgreSQL) | Completed activity JSON, user ID, route points | Cloud synchronization and cross-device persistence for authenticated accounts. |

---

## 5. Supabase Synchronization, Offline Deletion & Account Isolation

### A. Synchronization Behavior & Triggers
- **Local-First Guarantee:** Completed workouts and saved routes are always committed to your device's local storage first before any remote synchronization is attempted.
- **Automatic Cloud Sync Triggers:** For signed-in users, cloud synchronization occurs automatically upon:
  1. Application launch/startup.
  2. Successful user sign-in or session renewal.
  3. Completion and local saving of any outdoor workout.
  4. Creation and local saving of any route.
  5. Automatic detection of restored network connectivity (when switching from offline to online).
- **Exact Data Uploaded to Cloud:**
  - *Outdoor Activities:* Activity UUID, owner user ID, activity sport type (walk, run, hike), start and end timestamps, active duration (seconds), total distance (meters), elevation gain (meters), average speed (km/h), average pace (sec/km), and full GPS route points (latitude, longitude, altitude, fix timestamp, speed, bearing).
  - *Saved Routes:* Route UUID, owner user ID, route title, description, distance (meters), estimated duration (seconds), elevation gain (meters), polyline coordinate sequence, waypoints, surface type, and elevation profile.
- **No In-App Cloud Sync Opt-Out Toggle (Important Disclosure):**
  - Vyayama currently **does not feature an in-app toggle or setting to disable cloud synchronization while signed in to an authenticated account**.
  - All workouts completed and routes saved while authenticated will automatically synchronize to Supabase when an internet connection is detected.
  - If you require strict, 100% local-only tracking with zero cloud synchronization, you must record your workouts in **Unauthenticated Guest Mode** or sign out of your account before starting an outdoor session.
- **Idempotency & Deduplication:** Remote synchronization uses idempotent record upserts bound to stable client-generated UUIDs. Retrying synchronization across unstable network conditions will never create duplicate workout entries.

### B. Offline Deletion & Crash-Resistant Tombstone Queue
- **Four-Step Atomic Deletion Guarantee:** When you delete a workout or saved route:
  1. A persistent deletion tombstone containing the entity type (`activity` or `route`), record UUID, owner user ID, and timestamp is persisted to disk **first**.
  2. The record is unlinked and hidden from all visible local listings immediately.
  3. A remote deletion request is dispatched to Supabase with bounded exponential backoff.
  4. The persistent tombstone is purged from disk **only after** the remote server confirms deletion.
- **Crash & Power-Loss Safety:** Because the tombstone is written *before* any remote deletion is attempted, an unexpected crash, power loss, or network termination at any point during deletion leaves the system in a consistent state: the item remains hidden locally, and pending tombstones are retried automatically upon app restart or reconnect.
- **Resurrection Prevention:** Tombstoned records are strictly barred from being resurrected or re-saved by concurrent or subsequent cloud synchronization cycles.

### C. Account Isolation & Row Level Security (RLS)
- All cloud database tables enforce PostgreSQL Row Level Security (RLS) policies (`auth.uid() = user_id`).
- **User A cannot read, insert, update, or delete User B's activities or saved routes.**
- On shared devices, local activity histories are partitioned by user ID. Signing out does not expose your workout history to subsequent users.

---

## 6. Permissions, Android Foreground Service & Google Play Compliance

Vyayama requests location and device permissions strictly to deliver active outdoor tracking:

### A. Location Permissions (`ACCESS_FINE_LOCATION` & `ACCESS_COARSE_LOCATION`)
- **Prominent Disclosure:** A clear in-app disclosure banner is displayed before requesting OS location permissions, explaining that coordinates are collected only to track active workouts and show your position on the map.
- **When Collected:** Location data is collected only while viewing the map screen or while an outdoor workout recording session is actively running.
- **Why Background Location (`ACCESS_BACKGROUND_LOCATION`) is Not Requested:** Vyayama does not perform passive "all the time" tracking. Location tracking in background states occurs strictly during an active workout session backed by an Android Foreground Service.

### B. Android Foreground Service (`FOREGROUND_SERVICE_LOCATION`)
- On Android 10+ (and specifically Android 14+ / API 34+), outdoor tracking runs via a dedicated foreground service (`com.baseflow.geolocator.GeolocatorLocationService`).
- **Ongoing Notification:** A persistent, non-dismissible notification ("Vyayama — Outdoor Tracking") is displayed in the system notification drawer for the entire duration of the active workout.
- **User-Initiated Start & Immediate Stop:** The foreground service is initiated strictly when you tap "Start" in the visible app. When you tap "Pause", "Finish", or "Discard", tracking stops immediately.
- **Google Play Declaration:** An official Foreground Service Location declaration and demonstration video are maintained in Google Play Console justifying user-facing fitness tracking.

---

## 7. Data Retention & Account Deletion

You retain full ownership and control over your data:
- **Individual Activity Deletion:** You can delete any recorded workout or saved route at any time. Local records and cloud database records are deleted permanently.
- **Account Deletion:**
  - You can permanently delete your account directly inside the app: **Settings → Account → Delete Account**.
  - Deleting your account triggers an automatic cascading deletion (`on delete cascade`) across all database tables, permanently erasing your profile, workout logs, GPS route points, saved routes, and social connections from our servers.
- **Sign-Out:** Signing out halts active synchronization and clears active authentication tokens from secure storage.

---

## 8. Updates to This Policy

We may update this Privacy Policy from time to time to reflect functional improvements, new integrations, or regulatory updates. Significant changes will be highlighted within the application.

---

## 9. Contact Us

If you have questions, concerns, or requests regarding this Privacy Policy, please contact our privacy team at:

- **Email:** `privacy@vyayama.app`
- **Application:** Vyayama Fitness
