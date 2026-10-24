# AGENTS.md — Agent & Developer Guidelines for Vyayama

Welcome to **Vyayama** (formerly internal working title "FitBuddy"). This document contains essential architecture rules, naming policies, and guidelines that all AI agents and developers working on this repository MUST follow.

---

## 1. Project Identity & Naming Policy (Option 1 Architecture)

To ensure stability across Google Play, Apple App Store, Google Cloud OAuth, and Supabase Authentication, the codebase uses a strictly separated naming architecture:

| Asset / Surface | Identifier / Value | Rule & Usage |
|---|---|---|
| **User-Facing Product Name** | **Vyayama** | Used in Play Store listing, App Store, launcher icons, UI headers, dialogs, notification diagnostics, web title/manifest, Windows metadata, and all user documentation. |
| **Android Application ID** | `com.vyayama.fitbuddy` | **Permanently locked**. Do NOT change. Google Play Console, Google OAuth client credentials (SHA-1 fingerprint), and Supabase redirect URLs are strictly bound to this ID. |
| **Android Namespace** | `com.vyayama.fitbuddy` | Kept aligned with `applicationId` in `android/app/build.gradle.kts`. |
| **iOS Bundle Identifier** | `com.vyayama.fitbuddy` | Kept aligned with Android `applicationId` in Xcode project settings. |
| **Deep Link Scheme** | `io.vyayama.fitbuddy` | Used for OAuth callbacks, password reset redirects, and native intent filters. |
| **Internal Dart Package** | `fitbuddy` | Compiler tooling identifier (`package:fitbuddy/...`). Invisible to end users. Must NOT be renamed to prevent massive refactoring friction and import breakages. |

> [!IMPORTANT]
> **Application ID Lock:**
> The `applicationId` `com.vyayama.fitbuddy` must **never be changed** after the first Google Play Console or Apple App Store upload. Changing the application ID creates a completely separate application on the store, breaking user update paths and invalidating all release signing and OAuth registrations.

---

## 2. Configuration & External Services

1. **Authentication & OAuth:**
   - Google Sign-In and Supabase Auth rely on client credentials bound to package `com.vyayama.fitbuddy` and deep link scheme `io.vyayama.fitbuddy://`.
   - Do NOT modify Google sign-in OAuth scopes, package names, or redirect configurations without explicit coordination.
2. **Invite & Profile Links:**
   - Link generation is centralized in [`lib/features/friends/data/invite_link.dart`](file:///e:/FitBuddy/lib/features/friends/data/invite_link.dart).
   - Driven by `kInviteBaseUrl` and `kProfileBaseUrl` config constants (with `--dart-define` support: `INVITE_BASE_URL` and `PROFILE_BASE_URL`).
   - Default fallback points to placeholder `https://invite.vyayama.example/`.
   - **Pre-launch requirement:** The production domain must be registered, owned, and configured with `/.well-known/assetlinks.json` (Android) and `apple-app-site-association` (iOS) before public link distribution.
3. **Demo Accounts:**
   - Primary mock authentication demo account is `demo@vyayama.app` / `vyayama123`.
   - Legacy alias `demo@fitbuddy.app` is maintained in in-memory test mocks for backward compatibility.

---

## 3. Engineering Guidelines & Verification

1. **Single Source of Truth:**
   - Refer to [`PROJECT_SPEC.md`](file:///e:/FitBuddy/PROJECT_SPEC.md) for milestone specifications, feature requirements, and technical constraints.
2. **Static Analysis & Tests:**
   - Before committing any changes, always execute:
     ```bash
     flutter analyze
     flutter test
     ```
   - All tests must pass (100%) and static analysis must report 0 issues.
3. **User-Facing Strings:**
   - Ensure all new strings, notifications, dialogs, titles, and tooltips display "Vyayama".
