# Samsung Real Device Testing Checklist (Vyayama)

This checklist is tailored specifically for **Samsung Galaxy devices running One UI (One UI 5.x / 6.x / 7.x on Android 13, 14, and 15)**. Due to Samsung's aggressive background app suspension policies ("App Power Management") and Android's strict exact alarm policies, execute this checklist on a physical device to verify real-world alarm accuracy and notification delivery.

---

## 1. Samsung One UI Pre-Flight System Settings

Before executing test cases, verify that the following system settings are explicitly configured on the Samsung test device:

| Setting Area | Exact Samsung One UI Path | Target Value | Verified? |
|---|---|---|---|
| **Alarms & Reminders (Exact Alarm)** | `Settings` → `Apps` → `⋮ (Top Right Menu)` → `Special access` → `Alarms & reminders` → `Vyayama` | **Allowed (Toggle ON)** | [ ] |
| **App Battery Mode** | `Settings` → `Apps` → `Vyayama` → `Battery` | **Unrestricted** (Do NOT choose *Optimised* or *Restricted*) | [ ] |
| **Background Usage Limits** | `Settings` → `Battery` → `Background usage limits` → `Never auto-sleeping apps` → `+` | **Add Vyayama** (Verify it is NOT in *Sleeping* or *Deep sleeping apps*) | [ ] |
| **Notification Permission** | `Settings` → `Apps` → `Vyayama` → `Notifications` | **Allow notifications** (Toggle ON) | [ ] |
| **Notification Categories (One UI 6.1+)** | `Settings` → `Notifications` → `Advanced settings` → `Manage notification categories for each app` | **Toggle ON** | [ ] |
| **Wake Alarms Category** | `Settings` → `Apps` → `Vyayama` → `Notifications` → `Notification categories` → `Wake Alarms` | **Alert**, **Show as pop-up: ON**, Sound: `wakeup_alarm` | [ ] |
| **Medicine Reminders Category** | `Settings` → `Apps` → `Vyayama` → `Notifications` → `Notification categories` → `Medicine Reminders` | **Alert**, **Show as pop-up: ON**, Sound: `warning_alarm` | [ ] |
| **Meal Reminders Category** | `Settings` → `Apps` → `Vyayama` → `Notifications` → `Notification categories` → `Meal Reminders` | **Alert**, Sound: Default | [ ] |
| **Bedtime Guidance Category** | `Settings` → `Apps` → `Vyayama` → `Notifications` → `Notification categories` → `Bedtime Guidance` | **Alert / Silent** | [ ] |
| **Do Not Disturb (DND) Alarms** | `Settings` → `Notifications` → `Do Not Disturb` → `Alarms and sounds` | **Alarms: ON** | [ ] |

---

## 2. In-App Notification Diagnostics Baseline

1. Open **Vyayama** → Navigate to **Profile** → **Settings** (`/settings`) → Tap **Notification Diagnostics** (`/settings/diagnostics`).
2. Verify system permission indicators:
   - `Notification Permission`: Green Check `[Active]`
   - `Exact Alarms Permission`: Green Check `[Active]`
   - `Battery Optimization`: Green Check `[Unrestricted]`
   - `Audio Permission`: Green Check `[Active]`
   - `Picture-in-Picture`: Green Check `[Active]`
3. Run **Alarm Reconciliation** (`Run Alarm Reconciliation` button) and confirm green banner:
   *"Reconciliation completed successfully! Alarms synced."*

---

## 3. Real Device Execution Matrix

Test each reminder type across 5 device power states:
- **Foreground**: App open on screen.
- **Background / Locked Screen**: App minimized, screen locked for 10+ minutes.
- **App Killed**: App swiped away from Samsung Recent Apps carousel.
- **Phone Reboot**: Device restarted via Samsung power menu.
- **Airplane Mode**: Wi-Fi and Mobile Data disabled.

| Test ID | Reminder / Feature | Power / Network State | Scheduled Time | Test Action & Steps | Expected Result | Actual Result | Delay (Seconds) | Pass/Fail |
|---|---|---|---|---|---|---|---|---|
| **REM-01** | **Diagnostic 5s Clock Alarm** | Screen Locked | +5s from tap | In Diagnostics screen, tap `Test 5s Medicine Alarm (Clock Style)`. Immediately lock screen. | Phone wakes screen with heads-up alarm popup & rings `warning_alarm` audio. | | | [ ] |
| **REM-02** | **Diagnostic 2m Exact Wake Alarm** | App Killed | +2 min from tap | Tap `2m Wake Alarm`, swipe Vyayama away from Recents, lock device for 2 minutes. | Exact alarm rings at target minute, breaks through lock screen. | | | [ ] |
| **REM-03** | **Diagnostic 2m Bedtime Nudge** | Background | +2 min from tap | Tap `2m Bedtime Nudge`, minimize app to home screen. | Standard notification appears in notification shade. | | | [ ] |
| **REM-04** | **Medicine Reminder (Morning)** | App Killed | e.g. 08:30 AM | Add medicine in Health Profile at current time +3 min. Kill app. | Native heads-up alarm with 'Dismiss' & 'Snooze (5m)' buttons rings on time. | | | [ ] |
| **REM-05** | **Medicine Snooze (5m)** | Screen Locked | +5 min from snooze | When REM-04 fires, tap `Snooze (5m)`. Lock device. | Rescheduled 5-minute snooze alarm triggers exactly 5 minutes later. | | | [ ] |
| **REM-06** | **Wake Alarm (Exact)** | Screen Locked / DND Active | Next Morning or +3 min | Configure Wake Alarm in Sleep tab. Enable Samsung Do Not Disturb (DND). Lock screen. | Alarm rings at target minute, bypasses DND due to Alarm clock attributes. | | | [ ] |
| **REM-07** | **Bedtime Reminder** | Screen Off / Idle | Target wind-down time | Set Bedtime reminder in Sleep tab. Leave device idling on table for 30 min. | Notification appears; note if delayed by OS Doze mode (inexact scheduling). | | | [ ] |
| **REM-08** | **Breakfast Reminder** | Screen Locked | e.g. 08:00 AM | Set Breakfast reminder in Health Profile. | Friendly meal banner appears in shade. Measure delay due to inexact mode. | | | [ ] |
| **REM-09** | **Lunch Reminder** | Screen Locked | e.g. 01:00 PM | Set Lunch reminder in Health Profile. | Friendly meal banner appears. Measure delay in seconds. | | | [ ] |
| **REM-10** | **Snack Reminder** | Background | e.g. 04:30 PM | Set Snack reminder in Health Profile. | Friendly meal banner appears. | | | [ ] |
| **REM-11** | **Dinner Reminder** | App Killed | e.g. 08:00 PM | Set Dinner reminder in Health Profile. Kill app. | Friendly meal banner appears. Measure delay in seconds. | | | [ ] |
| **REM-12** | **Device Reboot Persistence** | Phone Rebooted | Post-reboot +5 min | Schedule medicine alarm for 10 min in future. Restart Samsung phone (`Restart`). Do NOT open Vyayama after boot. | `ScheduledNotificationBootReceiver` re-registers alarm; alarm fires on schedule. | | | [ ] |
| **REM-13** | **Airplane Mode (Reminders)** | Airplane Mode ON | Target time | Turn on Airplane mode. Wait for scheduled Medicine or Wake alarm. | Alarm fires 100% offline without network dependency. | | | [ ] |
| **REM-14** | **Timezone Change** | App in Background | Immediate | Change system timezone in `Settings` → `General management` → `Date and time`. | Alarms adjust to match new local clock without firing at old UTC offset. | | | [ ] |

---

## 4. Picture-in-Picture (PiP) Real Device Test

| Test ID | Feature | State | Action | Expected Result | Actual Result | Pass/Fail |
|---|---|---|---|---|---|---|
| **PIP-01** | **Guided Session PiP** | In active workout session | Tap PiP button in AppBar or press Android Home gesture | App shrinks into floating Samsung PiP window displaying timer, exercise name, and pause/done controls. | | [ ] |
| **PIP-02** | **PiP Controls** | Floating window | Tap Done Set or Pause inside floating PiP window | Set count increments and timer pauses without expanding app. | | [ ] |

---

## 5. Physical Step Counting Verification (Samsung Pedometer)

| Test ID | Feature | Scenario | Steps Counted (Pedestrian) | App Steps Displayed | Deviation | Pass/Fail |
|---|---|---|---|---|---|---|
| **STP-01** | **Walking 100 Steps** | App open | Walk 100 paces | Real-time counter updates within 10–15 seconds (hardware batch latency). | | [ ] |
| **STP-02** | **Walking 500 Steps (Locked)** | Screen locked, phone in pocket | Walk 500 paces, unlock phone | `flushSensor()` flushes hardware FIFO; counter increases by ~500 steps. | | [ ] |
| **STP-03** | **Midnight Rollover** | Physical midnight crossing | Phone running past 00:00 | Step counter archives yesterday's total and resets today's count to 0 + overnight delta. | | [ ] |
| **STP-04** | **Phone Restart** | Phone rebooted | Restart phone, check steps | Previous daily steps preserved; delta continues from new boot baseline. | | [ ] |

---

## 6. Social & Snaps Real Device Test (Two Devices / Accounts)

Requires **Device A** (logged into Account A) and **Device B** (logged into Account B).

| Test ID | Feature | Sender (Device A) | Recipient (Device B) | Expected Result | Actual Result | Pass/Fail |
|---|---|---|---|---|---|---|
| **SNP-01** | **Camera Permission** | Open Camera tab (`/snaps/camera`) | — | Native Samsung camera dialog displays. Allowing camera opens live viewfinder. | | [ ] |
| **SNP-02** | **Direct Snap Send** | Snap photo, select Device B recipient, tap Send | Inbox (`/snaps/inbox`) | Photo uploads to Supabase private bucket; Device B inbox displays new unread snap. | | [ ] |
| **SNP-03** | **Snap Viewing & Streak** | View sent status | Open snap viewer (`/snaps/view/:id`) | Photo displays with countdown timer; streak counter increments by +1 on both devices. | | [ ] |
| **SNP-04** | **Offline Snap Send** | Airplane Mode ON, tap Send | — | UI displays error message with 'Retry' button; photo is NOT lost while screen remains open. | | [ ] |
| **SNP-05** | **Friend Request via QR** | Show QR code on Device A (`/profile`) | Scan QR with camera on Device B (`/friends/add`) | Profile resolves instantly; Send Friend Request connects both accounts. | | [ ] |
| **SNP-06** | **Push Notification (FCM)** | Send snap to Device B | Device B in background | **Note**: FCM push is NOT implemented. Device B will NOT receive a push banner until app is opened or polled. | | [ ] |

---

## 7. Tester Notes & Observation Summary

- **Device Model**: Samsung Galaxy _____________________
- **Android Version / One UI**: Android _____ / One UI _____
- **Kernel / Build Number**: _____________________
- **Tester Name**: _____________________
- **Date Tested**: _____________________
- **General Notes**:
