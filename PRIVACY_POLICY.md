# Privacy Policy for Vyayama

**Last Updated:** October 23, 2026  
**Effective Date:** October 23, 2026  

Welcome to **Vyayama** ("we", "our", or "us"). Your privacy is fundamental to how we build our application. This Privacy Policy explains clearly and transparently how we collect, store, protect, process, and delete your personal, fitness, and health information when you use the Vyayama mobile application.

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

### C. Workout Snaps & Social Interactions
- **Workout Photographs ("Snaps"):** Real-time exercise photos captured through the in-app camera to verify workout completion and maintain social streaks. Photo EXIF metadata (such as GPS location) is stripped prior to upload.
- **Social Connections:** Friend lists, friend request statuses, team memberships, and mutual workout streaks.

### D. Device & Technical Information
- **Device Sensors:** Hardware step counter sensor (`SENSOR_TYPE_STEP_COUNTER`) and step detector sensor readings processed locally on your device.
- **Notification Identifiers:** Native local notification channel identifiers for wake-up alarms, bedtime prompts, and hydration reminders.

---

## 2. Why We Collect This Information (Purposes)

We collect and use your data strictly for legitimate health and fitness features:
1. **Personalized Workout Experience:** Adapting exercise recommendations based on fitness level, equipment availability, and user-specified physical limitations.
2. **Activity & Habit Tracking:** Tracking daily steps, calories burned, water intake, and rest schedules to help you maintain consistent healthy habits.
3. **Workout Verification & Accountability:** Validating workout authenticity through privacy-conscious server-side verification to compute snap streaks and social challenges.
4. **Reminders & Alarms:** Providing exact alarms and notifications for wake-up times, bedtime routines, and hydration intervals.

**We never sell, rent, monetize, or trade your personal or health data to advertisers, data brokers, or third parties.**

---

## 3. Storage, Transmission & Security Practices

- **Storage at Rest:**
  - Sensitive authentication credentials and tokens are secured on-device using hardware-backed encryption (Android KeyStore / EncryptedSharedPreferences and iOS Keychain).
  - Cloud data is stored in isolated PostgreSQL tables protected by Row Level Security (RLS) policies where each user can only read and modify their own records.
  - Workout photographs are stored in private storage buckets requiring short-lived signed URLs accessible only by the sender and designated recipients.
- **Transmission Security:**
  - All communication between Vyayama and our backend infrastructure is encrypted in transit using Transport Layer Security (TLS / HTTPS). Cleartext network traffic is prohibited.
- **Automatic Ephemeral Storage:**
  - Workout snaps and images are automatically deleted from Vyayama servers within 24 hours of posting via an automated hourly cleanup job.

---

## 4. Third-Party Services, Processors & AI Verification

Vyayama utilizes trusted infrastructure providers under strict confidentiality agreements:
- **Supabase (Backend Infrastructure):** Cloud PostgreSQL database, Row Level Security, authentication, and secure private object storage.
- **Google Play Services / Android Health APIs:** On-device hardware sensor access (`SensorManager`) and optional Google Health Connect / Google Sign-In integration.
- **AI Exercise Verification Service:**
  - **Nature of Verification:** Photo verification is strictly an automated "looks like exercise" classification designed to encourage workout consistency and social accountability. It does NOT constitute proof of physical exertion, athletic effort, or biometric identification.
  - **Provider Terms & Retention:** Images are processed via encrypted API calls by our vision model provider (e.g. Anthropic Claude API or Google Gemini API). Per the providers' commercial API terms, customer inputs and outputs are **never used to train generalized AI models**. Commercial API requests may be retained by the model provider for up to 30 days solely for trust, safety, and abuse-prevention purposes before deletion.
  - **On-Device Label Hint:** On-device image labeling (via Google ML Kit) is processed locally on your phone as an advisory hint. Labels evaluated on-device are never logged or shared externally.

---

## 5. Community Standards, User-Generated Content & Moderation

Vyayama fosters a supportive, positive community for fitness and wellness:
- **Prohibited Content:** Photos containing nudity, sexually suggestive imagery, violence, weapons, hate speech, harassment, minors in unsafe situations, or copyrighted/non-exercise material are strictly prohibited under our Community Standards.
- **User Reporting & Blocking:** Every snap and user profile includes tools to report objectionable content and immediately block abusive users. Blocking a user immediately prevents them from sending snaps, seeing stories, or interacting with your profile.
- **Moderation Process:** Reports are reviewed by human moderators in accordance with our community standards. While we strive to process reports in a timely manner, we do not promise an instantaneous response time. Blocked users are sequestered immediately upon your action.

---

## 6. Permissions, On-Device Step Counting & How to Revoke

Vyayama requests minimal runtime permissions strictly when corresponding features are actively utilized, with comprehensive fallback handling:
- **Physical Activity Recognition (`android.permission.ACTIVITY_RECOGNITION`):**
  - **On-Device Sensor Processing:** Used to count daily steps using your phone's low-power hardware step sensor (`Sensor.TYPE_STEP_COUNTER`).
  - **Local Real-Time Tracking:** Step detection is processed entirely on-device. Vyayama does not access GPS or location data for step tracking.
  - **Graceful Fallback:** If permission is denied or declined, Vyayama never crashes; live tracking pauses calmly, and you can freely enter steps manually or link Google Health Connect.
  - **Zero Commercial Sharing:** Sensor readings are never sold, rented, or shared with third parties or data brokers.
- **Exact Alarms (`android.permission.SCHEDULE_EXACT_ALARM`):**
  - Used to schedule precise wake-up alarms and time-critical medicine reminders.
  - If exact alarm scheduling is not granted by the system, Vyayama automatically falls back to standard inexact notifications (`AndroidScheduleMode.inexactAllowWhileIdle`) so you never miss an alert and the app never crashes. Vyayama does not use restricted automatic exact alarm permissions (`USE_EXACT_ALARM`).
- **Notifications (`android.permission.POST_NOTIFICATIONS`):**
  - Used to deliver heads-up alarm alerts with quick Dismiss and Snooze actions, as well as optional habit reminders.
- **Camera (`android.permission.CAMERA`):**
  - Used exclusively when you choose to take workout verification snaps or scan QR codes.
- **Zero Storage Permissions:**
  - Vyayama does not request or require `READ_EXTERNAL_STORAGE` or `READ_MEDIA_AUDIO`. All alarm tones, chimes, and exercise media are bundled directly within the app binary.

You can grant or revoke any optional permission at any time via: **Settings → Apps → Vyayama → Permissions** or **Settings → Apps → Special app access → Alarms & reminders**.

---

## 7. Data Retention & Your Rights (Account Deletion)

You have full ownership of your data at all times:
- **Access & Correction:** You can view and edit your profile details, BMI records, and health conditions at any time directly in the app.
- **Complete Account & Data Deletion:**
  - You can permanently delete your account and all associated records directly inside the app: **Settings → Account → Delete Account**.
  - When you confirm deletion, all your profile data, workout history, BMI records, friend connections, teams, and uploaded snap photographs are immediately and permanently erased from our databases and storage servers.
  - Web Deletion Request: If you cannot access the app, you may request deletion by contacting us at the email below.

---

## 8. Children's Privacy

Vyayama is designed for general audiences and does not knowingly collect personal information from children under 13 years of age (or under 16 in certain jurisdictions). If you become aware that a child has provided us with personal information without parental consent, please contact us and we will promptly delete the data.

---

## 9. Updates to This Policy

We may update this Privacy Policy from time to time to reflect improvements or regulatory changes. When updates occur, the "Last Updated" date at the top will be revised. Significant changes will be announced within the application.

---

## 10. Contact Us

If you have questions, concerns, or requests regarding this Privacy Policy or your personal information, please contact our privacy team at:

- **Email:** `privacy@vyayama.app`
- **Application:** Vyayama Fitness
