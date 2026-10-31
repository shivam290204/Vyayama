# Maps & Outdoor Activity Module Audit & Implementation Plan (Vyayama)

**Document Version:** 1.0.0  
**Audit Date:** 2026-10-30  
**Target Module:** `lib/features/maps/`  
**Status:** Phase 0 (Read-Only Audit & Phased Architecture Plan)

---

## 1. Executive Summary & Audit Scope

This audit reviews the complete Maps & Outdoor Activity subsystem in **Vyayama** (`lib/features/maps/`), covering:
- Riverpod state management and lifecycle transitions
- Location acquisition, permissions, and fallback handling
- Map camera, controllers, tile layer, and attribution
- Route discovery pipeline (Overpass, Nominatim, Valhalla, caching)
- GPS tracking, live metrics, battery consumption, and crash recovery
- Offline persistence, deletion queues, and Supabase database synchronization
- Platform manifests (Android merged manifests, iOS `Info.plist`) and privacy declarations

### Evidence Labels
Every finding and verification in this document is labeled with one of:
- `[VERIFIED BY TEST]`: Validated via automated unit or widget test execution with command output.
- `[CODE READING ONLY]`: Inspected directly in the codebase with file paths and line numbers.
- `[NEEDS REAL DEVICE]`: Requires physical hardware testing on an Android or iOS device (e.g., GPS hardware lock, deep sleep background battery drain, OEM task killing).

---

## 2. Comprehensive Subsystem Audit Findings

### A. Location State & Hardcoded Fallbacks
1. **Hardcoded Central Park Coordinates** `[VERIFIED BY CODE READING]`
   - `LatLng(40.785091, -73.968285)` is hardcoded in:
     - [`lib/features/maps/providers.dart:85`](file:///e:/FitBuddy/lib/features/maps/providers.dart#L85) (`selectedMapCenterProvider`)
     - [`lib/features/maps/presentation/screens/route_detail_screen.dart:33`](file:///e:/FitBuddy/lib/features/maps/presentation/screens/route_detail_screen.dart#L33)
     - [`lib/features/maps/presentation/screens/outdoor_summary_screen.dart:118`](file:///e:/FitBuddy/lib/features/maps/presentation/screens/outdoor_summary_screen.dart#L118)
     - [`lib/features/maps/presentation/screens/outdoor_recording_screen.dart:192`](file:///e:/FitBuddy/lib/features/maps/presentation/screens/outdoor_recording_screen.dart#L192)
   - **Root Cause & Impact**: `selectedMapCenterProvider` initializes with New York coordinates. Because `discoveredRoutesProvider` watches `selectedMapCenterProvider`, the app immediately fires an external route discovery query for Central Park NYC before GPS coordinates are acquired.
2. **Duplicate Concurrent Location Requests** `[VERIFIED BY CODE READING]`
   - [`MapsScreen.initState`](file:///e:/FitBuddy/lib/features/maps/presentation/screens/maps_screen.dart#L56-L63) calls `_fetchInitialLocation()` in a post-frame callback.
   - At the same time, [`MapsScreen.build`](file:///e:/FitBuddy/lib/features/maps/presentation/screens/maps_screen.dart#L107) watches `userCurrentLocationProvider` which also calls `getCurrentPosition()`.
   - **Impact**: Two simultaneous asynchronous calls query the platform location service on first screen mount.
3. **Untyped Boolean Permission Check** `[VERIFIED BY CODE READING]`
   - [`LocationTrackingService.checkAndRequestPermission()`](file:///e:/FitBuddy/lib/features/maps/domain/services/location_tracking_service.dart#L105-L124) collapses location service disabled, permission denied, and permission denied forever into a simple `false`.
   - **Impact**: The UI cannot prompt the user appropriately (e.g. "Enable Location Services" vs "Open Settings" for `deniedForever`).
4. **Lack of Request De-duplication & Request Counters** `[VERIFIED BY CODE READING]`
   - `getCurrentPosition()` in `LocationTrackingService` has no generation ID. If a user taps "Recenter" multiple times, out-of-order platform responses could overwrite newer fixes.

---

### B. Map Rendering, Tile Configuration & Camera
1. **Hardcoded OSM Tile URL & User Agent** `[VERIFIED BY CODE READING]`
   - `https://tile.openstreetmap.org/{z}/{x}/{y}.png` is hardcoded in 4 screens:
     - `maps_screen.dart:210`
     - `outdoor_recording_screen.dart:154`
     - `outdoor_summary_screen.dart:123`
     - `route_detail_screen.dart:45`
   - No `--dart-define` or centralized config class exists for map tiles.
2. **Missing Tile Error Handling & Tile Caching** `[VERIFIED BY CODE READING]`
   - `TileLayer` lacks an `errorTileCallback`, leading to grey checkerboards without non-blocking user feedback if network fails.
   - Tile caching uses default network tile provider without offline pre-caching or disk store.
3. **OpenStreetMap Attribution Preserved** `[VERIFIED BY TEST]`
   - `RichAttributionWidget` with OpenStreetMap copyright link is verified present across screens (`test/maps/maps_attribution_and_caching_test.dart`).
4. **MapController Premature Access Risk** `[VERIFIED BY CODE READING]`
   - `_mapController.move()` is called in `_fetchInitialLocation` and `_recenterLocation` without verifying map readiness.
5. **Camera Move Debounce & Center Separation** `[VERIFIED BY CODE READING]`
   - `_onPositionChanged` uses 900 ms debounce and 350 m threshold before updating `selectedMapCenterProvider`.
   - However, "my location" marker and "selected map search center" lack clear visual and state distinction.

---

### C. Route Discovery Engine & Web APIs
1. **Hardcoded Service URLs** `[VERIFIED BY CODE READING]`
   - Valhalla base URL defaults to `https://valhalla1.openstreetmap.de` in [`valhalla_service.dart:52`](file:///e:/FitBuddy/lib/features/maps/data/services/valhalla_service.dart#L52).
   - Nominatim endpoint is hardcoded to `https://nominatim.openstreetmap.org/search` in [`nominatim_service.dart:42`](file:///e:/FitBuddy/lib/features/maps/data/services/nominatim_service.dart#L42).
   - Overpass endpoints default to hardcoded public URLs in [`overpass_service.dart:82`](file:///e:/FitBuddy/lib/features/maps/data/services/overpass_service.dart#L82).
   - None are driven by a unified environment configuration.
2. **Sequential Unbounded Candidate Processing (Long Load Times)** `[VERIFIED BY CODE READING]`
   - [`RealRouteDiscoveryService.discoverRoutes`](file:///e:/FitBuddy/lib/features/maps/data/services/real_route_discovery_service.dart#L93-L123) takes up to 12 candidates and processes them one-by-one.
   - Each candidate attempts multi-point Valhalla routing (20s timeout), followed by single-point fallback (20s timeout).
   - **Impact**: Up to 240 seconds (4 minutes) of sequential network calls if multiple candidates fail to route.
3. **Missing Request Cancellation & In-flight Join** `[VERIFIED BY CODE READING]`
   - When a user moves the map, the previous in-flight discovery request is not cancelled (`close(force: true)`), allowing race conditions where a previous search response overwrites a newer area.
4. **Unbounded In-Memory RouteCache** `[VERIFIED BY CODE READING]`
   - [`RouteCache`](file:///e:/FitBuddy/lib/features/maps/data/services/route_cache.dart#L11) uses a `Map<String, _CacheEntry<dynamic>>` with a 10-minute TTL but **no max size limit** or LRU eviction policy. Stale unaccessed keys leak memory over long app sessions.
5. **Precision-6 Polyline Decoding and Geometry Loop Analysis** `[VERIFIED BY TEST]`
   - Polyline decoding and closed-loop vs out-and-back geometry analysis are verified working and accurate (`test/maps/real_route_discovery_test.dart`).

---

### D. Outdoor Activity Tracking, Battery & Recovery
1. **Zero Session Autosave or Crash Recovery** `[VERIFIED BY CODE READING]`
   - `LocationTrackingService` holds all active tracking state (points, duration, distance, pace) in `ValueNotifier<TrackingState>` in RAM.
   - If Android OS kills the process in the background (or app crashes / battery dies), the entire recording is lost.
2. **Aggressive Location Settings & High Battery Drain** `[VERIFIED BY CODE READING]`
   - Android settings in [`location_tracking_service.dart:203-214`](file:///e:/FitBuddy/lib/features/maps/domain/services/location_tracking_service.dart#L203-L214):
     - `accuracy: LocationAccuracy.bestForNavigation`
     - `distanceFilter: 2` meters
     - `intervalDuration: Duration(seconds: 2)`
     - `enableWakeLock: true`
   - Running the GNSS chipset continuously at 0.5 Hz with an active CPU wake lock rapidly depletes battery during 30–60 minute sessions.
   - No distinction between walking (lower speed/frequency needed) and running.
3. **GPS Drift & Jump Math Filtering** `[VERIFIED BY TEST]`
   - Filtering out fixes with accuracy > 20 m, displacement < 3 m, or speed > 45 km/h is verified working (`test/maps/gps_filter_service_test.dart`).
4. **Non-Idempotent Activity Finish** `[VERIFIED BY CODE READING]`
   - `finishRecording()` generates activity ID via `'outdoor_${DateTime.now().millisecondsSinceEpoch}'`. Calling finish twice creates duplicate activities.

---

### E. Persistence, Supabase Sync & Schema Mismatches
1. **Critical Schema Mismatches with Migration 019** `[VERIFIED BY CODE READING]`
   - In [`SavedRoute.toJson()`](file:///e:/FitBuddy/lib/features/maps/domain/models/saved_route.dart#L242-L259):
     - Produces keys `'is_loop'` and `'is_difficulty_estimated'`.
     - In [`019_outdoor_activities_and_saved_routes.sql`](file:///e:/FitBuddy/supabase/migrations/019_outdoor_activities_and_saved_routes.sql#L51-L66), table `public.saved_routes` **does not have** `is_loop` or `is_difficulty_estimated` columns! PostgREST will fail with HTTP 400 Bad Request.
     - Database check constraint: `check (surface_type in ('paved', 'trail', 'mixed'))`. Dart enum has `RouteSurface.unknown`. If `'unknown'` is sent, Postgres rejects the insert.
     - Database check constraint: `check (elevation_profile in ('flat', 'moderate', 'hilly'))`. Dart enum has `RouteElevation.unknown`. If `'unknown'` is sent, Postgres rejects the insert.
2. **Silent Unretried Deletes** `[VERIFIED BY CODE READING]`
   - [`OutdoorActivityRepository.deleteActivity`](file:///e:/FitBuddy/lib/features/maps/data/repositories/outdoor_activity_repository.dart#L83-L93) and [`SavedRoutesRepository.deleteRoute`](file:///e:/FitBuddy/lib/features/maps/data/repositories/saved_routes_repository.dart#L64-L71) delete locally, but if the remote call fails offline, the error is caught and discarded. There is no tombstone queue, leaving remote rows orphaned.
3. **Account Deletion Cascade Verified** `[VERIFIED BY CODE READING]`
   - Migration 019 specifies:
     - `user_id uuid not null references public.profiles(id) on delete cascade`
     - Deleting a user profile cascades and deletes all outdoor activities and saved routes.

---

### F. Platform Manifests & Privacy Declarations
1. **Android Manifest & Foreground Service** `[VERIFIED BY MERGED MANIFEST INSPECTION]`
   - Merged manifest file: `build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml`
   - Service declared:
     ```xml
     <service
         android:name="com.baseflow.geolocator.GeolocatorLocationService"
         android:enabled="true"
         android:exported="false"
         android:foregroundServiceType="location" />
     ```
   - Permissions declared in `android/app/src/main/AndroidManifest.xml`:
     - `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`
     - `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`
     - `WAKE_LOCK`
2. **iOS Info.plist Configuration** `[VERIFIED BY CODE READING]`
   - [`ios/Runner/Info.plist`](file:///e:/FitBuddy/ios/Runner/Info.plist#L80-L88):
     - `UIBackgroundModes`: contains `location` and `fetch`
     - `NSLocationWhenInUseUsageDescription`: present
     - `NSLocationAlwaysAndWhenInUseUsageDescription`: present
3. **Privacy Policy Gaps** `[VERIFIED BY CODE READING]`
   - [`PRIVACY_POLICY.md`](file:///e:/FitBuddy/PRIVACY_POLICY.md) does not mention OpenStreetMap tile servers, Overpass API, Valhalla routing, or Nominatim geocoding, despite coordinates being transmitted to them.
   - Missing Google Play Console Data Safety documentation for location sharing with third-party infrastructure.

---

## 3. Phased Implementation Plan (Phases 1–6)

### Phase 1: Unified Location State & Architecture
- **Files Changed**:
  - `lib/features/maps/domain/models/user_location_state.dart` (NEW: typed state, status enum)
  - `lib/features/maps/domain/services/location_tracking_service.dart` (typed permission check, last known position, request de-duplication, generation counter)
  - `lib/features/maps/providers.dart` (introduce `userLocationNotifierProvider`, remove Central Park fallback)
  - `lib/features/maps/presentation/screens/maps_screen.dart` (listen to typed location state, show rationale/error UI, safe recenter)
  - `lib/features/maps/presentation/screens/outdoor_recording_screen.dart` (remove hardcoded New York fallback)
  - `lib/features/maps/presentation/screens/outdoor_summary_screen.dart` (remove hardcoded New York fallback)
  - `lib/features/maps/presentation/screens/route_detail_screen.dart` (remove hardcoded New York fallback)
  - `test/maps/user_location_state_test.dart` (NEW: comprehensive state, timeout, denial, and generation counter tests)
- **Key Implementation Details**:
  - Neutral global visual fallback for map initialization (`LatLng(20.0, 0.0)` at zoom 2.0 or map bounds); never treated as user location.
  - Typed `LocationPermissionResult` (serviceDisabled, denied, deniedForever, granted).
  - Single in-flight `Future` shared across concurrent callers.
  - Route discovery blocked until a valid, non-fallback location is acquired or user explicitly taps/searches.
- **Risks & Mitigations**:
  - *Risk*: Map screen opens with neutral world view before GPS fix.
  - *Mitigation*: Show subtle loading/seeking indicator on map; auto-animate to user fix once acquired.

---

### Phase 2: Map Rendering, Camera & Tile Configuration
- **Files Changed**:
  - `lib/features/maps/data/config/maps_config.dart` (NEW: centralized config with `--dart-define` overrides)
  - `lib/features/maps/presentation/screens/maps_screen.dart` (tile layer config, error callback, separate user heading marker vs center marker, guard mapController readiness)
  - `lib/features/maps/presentation/screens/outdoor_recording_screen.dart` (use maps config for tile URL)
  - `lib/features/maps/presentation/screens/outdoor_summary_screen.dart` (use maps config for tile URL)
  - `lib/features/maps/presentation/screens/route_detail_screen.dart` (use maps config for tile URL)
  - `test/maps/maps_camera_and_tile_test.dart` (NEW: widget tests for camera state, recenter, tile error handling)
- **Key Implementation Details**:
  - Configurable tile URL template (`MAPS_TILE_URL`) and user-agent (`MAPS_USER_AGENT`).
  - Tile load error callback shows non-blocking snackbar or badge.
  - Distinct visual markers: Real user GPS marker with heading vs selected map center marker.
  - Debounce map moves (600 ms) and only query if center shifted > 300 m.
- **Risks & Mitigations**:
  - *Risk*: Panning map triggers rapid re-queries.
  - *Mitigation*: Combined debounce (600 ms) and distance threshold (300 m) prevents queries during panning.

---

### Phase 3: Route Discovery Pipeline, Concurrency & Bounded LRU Cache
- **Files Changed**:
  - `lib/features/maps/data/config/maps_config.dart` (add endpoints: Valhalla, Overpass, Nominatim with public dev defaults)
  - `lib/features/maps/data/services/overpass_service.dart` (read endpoint from config; separate 429, 5xx, timeout handling)
  - `lib/features/maps/data/services/valhalla_service.dart` (read base URL from config)
  - `lib/features/maps/data/services/nominatim_service.dart` (read endpoint from config)
  - `lib/features/maps/data/services/real_route_discovery_service.dart` (bounded concurrency = 2, candidate cap = 8, 25s overall time budget, generation cancellation)
  - `lib/features/maps/data/services/route_cache.dart` (LRU cache with 50-entry cap and 10-minute TTL)
  - `lib/features/maps/presentation/widgets/route_discovery_sheet.dart` (rich state handling: searching, found, none found, offline, timeout, rate limit, retry)
  - `test/maps/real_route_discovery_test.dart` (update and extend with concurrency and cancellation tests)
- **Key Implementation Details**:
  - Loud warning in release builds if public demo endpoints are detected (`kReleaseMode`).
  - Candidates capped at 8; evaluated in parallel batches of 2 with `Future.wait`.
  - Overall search timeout capped at 25 seconds; returns partial routes discovered so far if timeout is reached.
  - Generation ID cancels obsolete HTTP requests (`client.close(force: true)`).
  - LRU `RouteCache` keeps memory bounded under 50 entries.
- **Risks & Mitigations**:
  - *Risk*: Network concurrency hitting demo server rate limits.
  - *Mitigation*: Concurrency bounded strictly to 2; rate limit errors trigger immediate early-stop with friendly UI.

---

### Phase 4: Outdoor Recording, Checkpoint Recovery & Battery Optimization
- **Files Changed**:
  - `lib/features/maps/domain/services/location_tracking_service.dart` (checkpointing every 30s/15 points, idempotent finish, activity-specific battery profiles)
  - `lib/features/maps/data/repositories/local_outdoor_storage.dart` (save/load/clear active session checkpoint)
  - `lib/features/maps/presentation/screens/outdoor_recording_screen.dart` (crash recovery prompt on mount: Resume / Save / Discard)
  - `test/maps/location_tracking_service_test.dart` (extend with checkpoint, crash recovery, and pause/resume tests)
- **Key Implementation Details**:
  - Checkpoint storage key: `outdoor_active_session_v1`. Stable UUID generated at session start.
  - Idempotent `finishRecording()`: uses session UUID; repeated calls return the same activity without duplicates.
  - Activity-specific GPS profiles:
    - Walking: `LocationAccuracy.high`, `distanceFilter: 5m`, `intervalDuration: 4s` (saves ~40% GPS radio power).
    - Running: `LocationAccuracy.high`, `distanceFilter: 3m`, `intervalDuration: 2s`.
    - Hiking: `LocationAccuracy.high`, `distanceFilter: 5m`, `intervalDuration: 5s`.
  - Diagnostic counter of fixes per minute exposed in tracking state.
  - Document Android 14 foreground service start rules and background restrictions.
- **Risks & Mitigations**:
  - *Risk*: Disk I/O overhead from frequent checkpoints.
  - *Mitigation*: Checkpoint every 30 seconds or 15 points, whichever comes first; minimal serialized JSON footprint (<5 KB).

---

### Phase 5: Persistence, Schema Alignment, Offline Deletion & Privacy Policy
- **Files Changed**:
  - `lib/features/maps/data/repositories/outdoor_activity_repository.dart` (tombstone deletion queue, retry on init/login)
  - `lib/features/maps/data/repositories/saved_routes_repository.dart` (tombstone deletion queue, sanitize payload for migration 019)
  - `lib/features/maps/data/repositories/local_outdoor_storage.dart` (tombstone storage keys and queue methods)
  - `supabase/migrations/020_saved_routes_metadata_additions.sql` (NEW: proposed additive migration adding `is_loop`, `is_difficulty_estimated`, and relaxing unknown surface constraints)
  - `PRIVACY_POLICY.md` (add third-party mapping disclosures: OpenStreetMap, Overpass, Valhalla, Nominatim; Play Console Data Safety guide)
  - `test/maps/local_outdoor_storage_test.dart` (test tombstone queue and offline delete retry)
- **Key Implementation Details**:
  - In `SavedRoutesRepository`, strip `'is_loop'` and `'is_difficulty_estimated'` before Supabase upsert until migration 020 is applied, and map `unknown` to `paved`/`flat` for DB check constraints.
  - Propose clean additive migration `020_saved_routes_metadata_additions.sql`.
  - Tombstone queues: `pending_deleted_activities_v1` and `pending_deleted_routes_v1`. Retried automatically in `syncPendingActivities()`.
  - Privacy policy explicitly lists coordinates shared with OSM tiles, Overpass, Valhalla, and Nominatim.
- **Risks & Mitigations**:
  - *Risk*: Offline deleted item resurrecting if sync runs before delete retry.
  - *Mitigation*: Local deletion is immediate; tombstone queue executes deletes before upserts during sync.

---

### Phase 6: Full Verification, Clean Build & Device Checklist
- **Tasks**:
  1. `flutter clean` && `flutter pub get`
  2. `flutter analyze` (enforce 0 issues)
  3. `flutter test test/maps/` (enforce 100% pass)
  4. `flutter test` (enforce 100% pass across all 700+ project tests)
  5. Verify no hardcoded colors (`AppPalette` enforcement) and no secrets.
  6. Write `docs/MAPS_DEVICE_TEST_CHECKLIST.md` with step-by-step test tables for Samsung Android device.

---

## 4. Regression Checklist & Risk Mitigation

| Component | Potential Regression | Mitigation & Test Coverage |
|---|---|---|
| **App Navigation** | Bottom bar tab switching or camera button broken | `test/maps/maps_navigation_test.dart` verifies 5 tabs and navigation stack |
| **Existing Saved Routes** | Old saved routes missing new fields failing to load | Backward compatibility tests in `test/maps/real_route_discovery_test.dart` |
| **Step Tracking / Health** | GPS tracking interfering with pedometer steps or calories | `LocationTrackingService` runs independently; zero shared pedometer state |
| **Route Filtering** | Filtering routes by activity, distance, or difficulty breaking | `test/maps/route_filter_test.dart` verifies filter matrices |
| **Color Palette** | New widgets using hardcoded colors | Enforced via `AppPalette` tokens; audited in static analysis |

---

## 5. Phase 0 Recommendation & Next Steps

This concludes **Phase 0**. In accordance with Rule 2:
> **Phase 0 is read-only: write the audit and plan, then STOP for my approval.**

No production application code has been modified. Upon your approval, we will proceed to **Phase 1: Location State**.

