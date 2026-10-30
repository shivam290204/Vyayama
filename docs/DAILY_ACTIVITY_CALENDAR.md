# Vyayama – Monthly Daily Activity Calendar Documentation

> **Feature Module**: Daily Activity & Step Tracking (`lib/features/dashboard/`)  
> **Design Inspiration**: Samsung Health Daily Activity Calendar (adapted to Vyayama Forest & Lime Green design system)  
> **Date**: October 29, 2026  
> **Status**: COMPLETED & VERIFIED (100% Test Pass Rate, 0 Lint Issues)  

---

## 1. Overview & Objective

The **Monthly Daily Activity Calendar** brings a monthly fitness overview to Vyayama's Step Tracking and Daily Activity dashboard (`lib/features/dashboard/dashboard_screen.dart`). Inspired by Samsung Health's activity rings calendar, it visualizes daily consistency using three concentric circular progress rings around each date, aggregates monthly achievements, and displays detailed metrics for any selected date.

---

## 2. UI Architecture & Components

```
MonthlyActivityCalendar (Card container, rounded 24px)
├── MonthlySummaryHeader
│   ├── Navigation row (< October 2026 >)
│   ├── Target achieved status (Target achieved 18/29 days)
│   └── Monthly totals row (Steps • Active minutes • Calories)
├── WeekdayHeaderRow (S  M  T  W  T  F  S)
├── Calendar Grid (7 columns × 5 or 6 weeks)
│   └── CalendarDayCell (Concentric circular rings + date number)
│       ├── Outer Ring (Lime Green): Steps vs Daily Step Target
│       ├── Middle Ring (Cyan/Teal): Active Minutes vs Target
│       ├── Inner Ring (Purple): Calories vs Target
│       └── Highlight states (Selected date pill, Today dot, Dimmed adjacent month)
└── SelectedDateDetailsCard
    ├── Date header & weekday ("29 Oct", "Today" badge, or "Target reached")
    ├── Large concentric progress illustration (with fitness icon in center)
    └── Detailed numeric breakdown (Steps, Active minutes, Calories)
```

### Component Breakdown
1. **`ConcentricRingsPainter` ([`concentric_rings_painter.dart`](file:///e:/FitBuddy/lib/features/dashboard/widgets/concentric_rings_painter.dart))**:
   - Custom painter drawing three concentric circular arcs starting at -90° (top) and sweeping clockwise.
   - Outer Ring: **Steps** (Lime Green `#8BCF45`).
   - Middle Ring: **Active Time** (Cyan/Teal `#06B6D4`).
   - Inner Ring: **Active Calories** (Purple `#A855F7`).
   - Low-opacity background circular tracks render for empty or partially complete rings.
   - Rounded stroke caps (`StrokeCap.round`).
2. **`CalendarDayCell` ([`calendar_day_cell.dart`](file:///e:/FitBuddy/lib/features/dashboard/widgets/calendar_day_cell.dart))**:
   - Interactive calendar cell with semantic labels for accessibility.
   - Renders concentric rings surrounding the date number.
   - Selected date is highlighted with a smooth Lime Green outline and subtle translucent background.
   - Today's date features a green indicator dot beneath the date number.
   - Adjacent month days are softly dimmed.
3. **`MonthlySummaryHeader` ([`monthly_summary_header.dart`](file:///e:/FitBuddy/lib/features/dashboard/widgets/monthly_summary_header.dart))**:
   - Month and year navigation header with previous/next chevrons.
   - Prominently displays `Target achieved X/Y days` (where step goal was achieved).
   - Summarizes total steps, active minutes, and calories formatted with thousands commas.
4. **`SelectedDateDetailsCard` ([`selected_date_details_card.dart`](file:///e:/FitBuddy/lib/features/dashboard/widgets/selected_date_details_card.dart))**:
   - Displays selected date, day of the week, and achievement badge ("Today", "Target reached", or "All targets met").
   - Large 96px concentric 3-ring circular progress display on the left.
   - Numeric metrics on the right: Steps, Active minutes, and Calories.
5. **`MonthlyActivityCalendar` ([`monthly_activity_calendar.dart`](file:///e:/FitBuddy/lib/features/dashboard/widgets/monthly_activity_calendar.dart))**:
   - Orchestrates the monthly calendar, watches Riverpod providers, handles month navigation and date selection.
6. **Clean Single Entry Navigation ([`monthly_activity_screen.dart`](file:///e:/FitBuddy/lib/features/dashboard/monthly_activity_screen.dart))**:
   - The Today dashboard retains its clean, focused layout without duplicate tabs or segments.
   - The top-right calendar icon in the AppBar serves as the single, direct entry point to the Monthly Activity screen.
   - `MonthlyActivityScreen` provides a dedicated AppBar with a back button returning directly to the dashboard, and a pull-to-refresh container embedding `MonthlyActivityCalendar`.
   - Deep linked route registered as `AppRoutes.monthlyActivity` (`/dashboard/monthly-activity`).

---

## 3. Data Sources & Integration

### Existing Infrastructure Reused
- **`DailyStats` Model**: Stores `steps`, `activeMinutes`, `calories`, and local calendar `date` (`YYYY-MM-DD`).
- **`LocalDailyStatsStorage`**: Offline-first storage in `SharedPreferences` (`local_daily_stats_YYYY-MM-DD`).
- **`SupabaseDailyStatsRepository`**: Queries `daily_stats` table with range filter `.gte('date', fromStr).lte('date', toStr)` and merges bidirectionally.
- **`DailyTargets`**: Computes user targets based on profile goals (`steps: 8000/10000/6000`, `activeMinutes: 30/45`, `activeCalories: 400/450/250`).
- **`StepTrackingService`**: Live hardware pedometer counts are merged into today's stats in real-time.

### Metrics Supported by Real Data
- **Steps**: 100% real data from device hardware step counter (`TYPE_STEP_COUNTER` / `TYPE_STEP_DETECTOR`), Google Health Connect, or manual entries.
- **Active Minutes**: 100% real data from pedometer sensor pace or Health Connect.
- **Calories**: 100% real active calories burned stored in `DailyStats` (from Health Connect or calibrated metabolic step burn). Zero fake or invented statistics.

---

## 4. Calendar Logic & Offline Implementation

### Pure Logic Layer ([`monthly_activity_logic.dart`](file:///e:/FitBuddy/lib/features/dashboard/logic/monthly_activity_logic.dart))
- **Month Length & Leap Years**: Handled natively using Dart `DateTime(year, month + 1, 0).day` (e.g. Feb 2024 = 29 days, Feb 2025 = 28 days, Oct 2026 = 31 days).
- **Weekday Alignment**: Sunday-first alignment calculated via `(firstOfMonth.weekday - DateTime.sunday + 7) % 7`.
- **Target Achieved Rule**: Day is considered achieved when `steps >= targets.steps`.
- **Progress Clamping**: Progress is visually capped at `1.0` (100% ring fill) while preserving full numeric totals (e.g., 16,000 / 8,000 steps shows 100% full ring and true `16,000` text).
- **Future Dates**: Automatically identified; rings remain empty with zero progress, and future days are excluded from the evaluated days count.
- **Offline Reliability**: Calls `DailyStatsRepository.fetchRange(from, to)`. If device is offline or in Airplane mode, `LocalDailyStatsStorage.getRange(from, to)` serves all cached records instantly with zero network delay.

---

## 5. Verification & Test Results

### 1. `flutter analyze`
- **Result**: `No issues found!` (0 errors, 0 warnings, 0 lints).

### 2. `flutter test`
- **Unit Tests (`test/dashboard/monthly_activity_logic_test.dart`)**: 7/7 tests passed:
  - Leap year calculation (Feb 2024 29 days, Feb 2025 28 days, Apr 30 days, Oct 31 days).
  - Month navigation across year boundaries (Dec -> Jan, Jan -> Dec).
  - Weekday alignment and 7-column grid layout starting Sunday.
  - Monthly aggregation sums and target achieved counting.
  - Missing and zero activity handling.
  - Future dates handling.
  - Target exceeded clamping.
- **Navigation Tests (`test/dashboard/dashboard_calendar_navigation_test.dart`)**: 1/1 test passed:
  - Clean dashboard layout verification (no duplicate tabs).
  - Tapping calendar icon opens `MonthlyActivityScreen`.
  - Back button returns directly to Dashboard.
- **Widget Tests (`test/dashboard/monthly_activity_calendar_widget_test.dart`)**: 3/3 tests passed:
  - Rendering month header, target achieved text, and weekday row.
  - Date cell tapping and updating `SelectedDateDetailsCard`.
  - Previous and next month chevron navigation.
- **Full Suite**: 100% pass rate across the entire test suite.

