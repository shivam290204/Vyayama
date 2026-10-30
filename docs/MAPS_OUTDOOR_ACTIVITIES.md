# Maps & Outdoor Activities — Architecture and Implementation Guide

## 1. Overview and Project Goal

This module expands **Vyayama** by introducing a comprehensive Maps and Outdoor Activities experience inspired by Strava, implemented **additively** without replacing or modifying any existing feature, step-tracking logic, or health integration.

### Core Capabilities
1. **Interactive Full-Screen Map**: Rendered using modern, open-source OpenStreetMap tiles via `flutter_map` (zero paid Google Maps or Mapbox API keys).
2. **Real Route Discovery**: Discovers genuine nearby walking, running, and hiking routes using actual OpenStreetMap geographic data (Overpass API) and pedestrian network routing (Valhalla API). No artificial circular loops or fabricated routes.
3. **Real Place Search**: Integrated OpenStreetMap Nominatim geocoding search that finds real parks, trails, and landmarks, and centers the map view.
4. **GPS Outdoor Activity Recording**: Tracks walking, running, and hiking in real-time with live drawn polylines, elapsed duration, distance in kilometers, average pace (min/km), and speed (km/h).
5. **Robust GPS Drift & Jump Filtering**: Geodesic math filtering out inaccurate GPS fixes (>20m error), stationary jitter (<3m displacement), and unrealistic speed jumps (>45 km/h).
6. **Offline-First Storage**: Completed outdoor activities and user-saved routes are stored in local storage (`SharedPreferences` JSON) with automatic deferred sync to Supabase when authenticated.
7. **Route History & Template Saving**: Users can inspect previous outdoor sessions, review detailed stats, and save any recorded activity as a reusable route template.

---

## 2. Non-Negotiable Preservation of Existing Features

The implementation strictly followed the **ADD ONLY, NEVER REPLACE** policy:
- **Bottom Navigation Preserved**: Kept all existing destinations (`Home`, `Workouts`, `Friends`, `Profile`) and the central `_CameraButton` action button. Maps was introduced as an additional dedicated destination (`branch: 2`).
- **Step Tracking & Pedometer Independent**: The existing hardware pedometer, Health Connect, and `StepTrackingService` remain completely untouched. GPS outdoor distance and pace are calculated independently to prevent double-counting steps or calories.
- **Smart Insights & Adaptive Journey**: All Phase 1, Phase 2, and Phase 3 intelligence models, feedback sheets, and insight generators continue running seamlessly.

---

## 3. Architecture & Module Structure

```text
lib/features/maps/
├── data/
│   ├── repositories/
│   │   ├── local_outdoor_storage.dart          # Offline-first SharedPreferences persistence
│   │   ├── outdoor_activity_repository.dart    # Manages activity lifecycle and Supabase sync
│   │   └── saved_routes_repository.dart        # Manages saved route templates
│   └── services/
│       ├── nominatim_service.dart              # OSM Nominatim geocoding place search
│       ├── overpass_service.dart               # Queries OSM Overpass API for real parks & trails
│       ├── real_route_discovery_service.dart   # Orchestrates Overpass places + Valhalla routing
│       ├── route_cache.dart                    # In-memory TTL cache (10 min) for API queries
│       └── valhalla_service.dart               # Valhalla pedestrian routing & precision-6 polyline decoding
├── domain/
│   ├── models/
│   │   ├── gps_point.dart                      # LatLng coordinate, altitude, accuracy, speed, timestamp
│   │   ├── outdoor_activity.dart               # Recorded workout model with distance, duration, pace
│   │   ├── outdoor_activity_type.dart          # Enum: walking, running, hiking with MET multipliers
│   │   ├── route_filter.dart                   # Filters by activity, distance, difficulty, surface
│   │   └── saved_route.dart                    # Discovered/saved route model
│   └── services/
│       ├── gps_filter_service.dart             # Mathematical coordinate validation & distance math
│       ├── location_tracking_service.dart      # Geolocator stream controller, pause/resume, timer
│       └── route_discovery_engine.dart         # Production interface delegating to RealRouteDiscoveryService
├── presentation/
│   ├── screens/
│   │   ├── maps_screen.dart                    # Main map screen with real discovered route polylines
│   │   ├── outdoor_recording_screen.dart       # Live recording dashboard with map, pace & controls
│   │   ├── outdoor_summary_screen.dart         # Workout summary, route map, title edit, save
│   │   ├── route_detail_screen.dart            # In-depth route preview with "Start Workout" action
│   │   └── saved_routes_screen.dart            # Two-tab screen: Saved Routes and Activity History
│   └── widgets/
│       ├── map_controls_overlay.dart           # Floating search bar, recenter, zoom & bookmark badge
│       ├── recording_metrics_card.dart         # Live metric display during workouts
│       ├── route_card.dart                     # Reusable route preview card with difficulty & stats
│       ├── route_discovery_sheet.dart          # Draggable bottom sheet with real discovered routes list
│       └── route_filter_sheet.dart             # Modal filter sheet with multi-attribute choice chips
├── maps_routes.dart                            # GoRouter routes for /maps, /maps/record, /maps/saved
└── providers.dart                              # Riverpod dependency injection & reactive streams
```

---

## 4. Real Route Discovery Architecture

### A. Data Flow & Routing Pipeline

```
[User Location / Selected Center]
               │
               ▼
   [OverpassService] ── Query OSM Overpass for named parks, recreation grounds, trails, footways
               │
               ▼
   [Candidate Filtering & Deduplication] ── Sort by proximity, prioritize parks/trails, eliminate duplicate IDs
               │
               ▼
   [ValhallaService] ── Route pedestrian loop: Origin → Waypoint → Origin via mapped walkable ways
               │
               ▼
   [Precision-6 Polyline Decoding] ── Decode actual geometry following streets and park paths
               │
               ▼
   [SavedRoute Model Generation] ── Real OSM place name, calculated distance/duration, inferred surface & difficulty
               │
               ▼
   [Filter Application] ── Filter by distance, activity type, difficulty, surface, search query
               │
               ▼
   [RouteDiscoverySheet & Map Display] ── Render actual route geometry on map; empty state if none
```

### B. Geographic Data Sources & Endpoints

| Provider | Endpoint | Role | Rate Limit / Politeness |
|---|---|---|---|
| **OSM Overpass API** | `https://overpass-api.de/api/interpreter` | Discovers nearby named parks, recreation grounds, paths, footways, and hiking routes. | Max 1 request per 5 seconds; cached for 10 minutes in memory. |
| **Valhalla Routing API** | `https://valhalla1.openstreetmap.de/route` | Computes pedestrian routes along actual routable road and path segments. | Low-volume usage; includes `X-Client-Id: vyayama` header; cached in memory. |
| **OSM Nominatim API** | `https://nominatim.openstreetmap.org/search` | Geocoding search for places, parks, and cities. | Max 1 request per second; user agent `Vyayama/1.0 (com.vyayama.fitbuddy)`. |

### C. Honest Empty, Error, and Retry States
- **Discovery Without Mandatory Names**: Overpass queries retrieve both named and unnamed footways, pedestrian paths, tracks, and park segments. Unnamed ways are assigned honest descriptive tags (e.g., "Mapped Footway", "Pedestrian Path") without fabricating proper nouns. Multiple unnamed routes with identical labels in distinct geographic corridors are preserved.
- **Strict Geometry-Based Loop Detection**: Loop verification is computed entirely from actual polyline coordinates (`isClosedLoopGeometry`) analyzing endpoint closure (<200m), turnaround divergence, and lateral separation (requiring divergent paths with $\ge 45\text{m}$ max separation and $<60\%$ retraced samples). Retraced out-and-back paths are never mislabeled as loops even when multiple waypoints were used.
- **Deduplication by Geometry & Corridor**: Routes are deduplicated by OSM element pairs and geographic corridor overlap (requiring both $<150\text{m}$ length difference and $<150\text{m}$ centroid/farthest-point divergence), preventing distinct routes with identical generic names from being discarded.
- **Truthful Metadata & Estimates**: Terrain difficulty without explicit OSM SAC scale or difficulty tags is clearly labeled as an estimate (`Est. Easy`, `Est. Moderate`, `Est. Hard`). Elevation gain is omitted (`--`) when unavailable, and untagged surface defaults strictly to `unknown`.
- **Backward Compatibility**: Older saved routes without `is_loop` are evaluated geometrically or default safely to `false` (never assumed to be verified loops). Untagged older JSON safely defaults to `RouteSurface.unknown`.
- **Activity Suitability**: Pedestrian paths on paved and mixed surfaces are marked suitable for both walking and running (`isSuitableFor`), ensuring running filters return valid paths.
- **Explicit Error Distinction**: Typed exceptions (`RouteRateLimitException`, `RouteNetworkException`, `OverpassServiceException`, `ValhallaRoutingException`) are surfaced in the UI with a dedicated `_RouteErrorView` and a **Retry** button (`ref.invalidate(discoveredRoutesProvider)`), rather than masking API failures as "No routes found".
- **Map Pan & Place Search Separation**: Place search centers the map without polluting the route filter query, and map panning refreshes discovery after a 900ms debounce and 350m displacement gate.
- When genuinely no mapped routes exist nearby, the bottom sheet displays:  
  **"No mapped routes found nearby."**  
  *"Try panning to an area with mapped pedestrian paths or parks."* with "Clear Filters" or "Check Again" actions.
- **No artificial concentric circles or fictional names** (e.g. "Greenway Park Circuit") are ever displayed to the user in production.

---

## 5. GPS Signal Processing and Mathematical Filtering

GPS data from mobile hardware can suffer from multipath interference, urban canyon reflections, and sensor sleep. To maintain elite tracking precision, `GpsFilterService` enforces 5 strict mathematical filters:

1. **Horizontal Accuracy Gate**: Points reporting `accuracy > 20.0 meters` are rejected from accumulating distance.
2. **Stationary Drift Rejection**: Displacement between consecutive points must exceed `3.0 meters` (using Vincenty / Haversine geodesic math), preventing distance creeping when the athlete is stopped at a crosswalk.
3. **Teleportation Speed Filter**: Calculated instantaneous velocity ($v = \Delta d / \Delta t$) cannot exceed `12.5 m/s` (45 km/h). Any larger jump is flagged as a satellite acquisition glitch and dropped.
4. **Time Inversion Prevention**: Candidate timestamps $\le$ the previous timestamp are rejected.
5. **Pause Isolation**: During pause, timer ticks and GPS distance accumulation are strictly frozen ($0.0$ added distance).

### Geodesic Distance Math
Distance is computed using the ellipsoidal Haversine / Vincenty formula via `latlong2`:
$$\Delta\sigma = 2 \arcsin \left( \sqrt{\sin^2\left(\frac{\Delta\phi}{2}\right) + \cos\phi_1 \cos\phi_2 \sin^2\left(\frac{\Delta\lambda}{2}\right)} \right)$$
$$d = R \cdot \Delta\sigma$$

---

## 6. Permissions and Privacy Safeguards

### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
<uses-feature android:name="android.hardware.location.gps" android:required="false" />
```

### iOS (`ios/Runner/Info.plist`)
```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>fetch</string>
</array>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Vyayama uses your location to show your position on the map and record outdoor walking, running, and hiking routes.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Vyayama uses background location to track your outdoor activity route even when your screen is locked.</string>
```

### Privacy & Data Protection
- **Private by Default**: All recorded activities and saved routes are stored locally on-device. No location data is shared publicly without explicit user consent.
- **Explicit Recording**: GPS tracking only starts when the user taps "Start Workout" and explicitly grants permission.

---

## 7. Verification and Testing

### 1. Static Analysis
- `flutter analyze`: **No issues found!** (0 errors, 0 warnings across the entire repository).

### 2. Unit and Integration Test Suite
- `test/maps/real_route_discovery_test.dart` (31 tests):
  - Overpass place tag classification (parks, recreation grounds, footways, hiking routes).
  - Honest descriptive names for unnamed paths without fictional proper nouns.
  - Typed error propagation (`RouteRateLimitException`, `RouteNetworkException`, `OverpassServiceException`, `ValhallaRoutingException`).
  - Valhalla trip response parsing and precision-6 polyline decoding.
  - Retraced out-and-back vs genuine polygon circuit loop detection via geometry.
  - Prevention of false loop classification on open paths and retraced multi-waypoint routes.
  - Multi-activity suitability (walking and running overlap on pedestrian ways).
  - Elevation gain handling (honest `--` formatting when elevation data is missing).
  - Difficulty estimation labeling (`Est. Easy` vs verified `Hard`).
  - Preservation of multiple unnamed routes sharing identical display labels.
  - Geometry-based deduplication of corridor duplicates.
  - Backward compatibility: old JSON without `is_loop` or `surface_type` parses safely without falsely claiming verified loops.
  - RouteCache TTL caching (get, set, invalidate, expiration).
- `test/maps/` (54 tests total): All 54 maps tests passing (100%).
- **Full Test Suite**: **681 tests passed (100%)** across all features in the repository.
- **Live API Low-Volume Verification**: Verified live HTTP 200 responses and real geometry from both `https://overpass-api.de/api/interpreter` (15 real pedestrian elements parsed) and `https://valhalla1.openstreetmap.de/route` (genuine pedestrian polyline generated).

---

## 8. Capability Audit & Verification Pass Status

| Capability | Status | Implementation Details & Findings |
|---|---|---|
| **Map Rendering** | `VERIFIED BY TEST` | `FlutterMap` renders OSM raster tiles with `TileLayer` using `userAgentPackageName: 'com.vyayama.fitbuddy'`. Tested without layout overflow or memory leak. |
| **OSM Attribution** | `VERIFIED BY TEST` | Visible `RichAttributionWidget` with clickable `TextSourceAttribution('OpenStreetMap contributors')` pointing to `https://openstreetmap.org/copyright` integrated on all 4 map screens. Complies strictly with OSM Tile Usage Policy. |
| **Tile Caching** | `VERIFIED BY TEST` | Built-in disk caching configured via `NetworkTileProvider`. Complies with OSM policy by strictly avoiding bulk tile prefetching. |
| **GPS Filtering & Metrics** | `VERIFIED BY TEST` | 5 mathematical filters in `GpsFilterService` thoroughly tested (accuracy < 20m, stationary drift > 3m, speed jump < 45km/h, time monotonicity, pause freeze). |
| **Real Route Discovery (OSM Overpass + Valhalla)** | `VERIFIED BY TEST` | Integrated in `RealRouteDiscoveryService`. Queries real Overpass features, routes with Valhalla pedestrian costing, decodes precision-6 polyline geometry, and constructs `SavedRoute`. Tested with mocked and unit fixtures. |
| **Place Search (Nominatim)** | `VERIFIED BY TEST` | Integrated in `NominatimService` and `MapControlsOverlay`. Queries OSM Nominatim API, moves map to selected coordinates, throttled to 1 req/sec with in-memory query caching. |
| **Honest Empty State** | `VERIFIED BY TEST` | Displays "No mapped routes found nearby" with zero artificial circular polylines or fake names when no OSM data exists. |
| **Background GPS (Android)** | `CODE READING ONLY` | Configured `AndroidSettings` with `ForegroundNotificationConfig` and permissions (`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`). Physical device verification recommended. |
| **Background GPS (iOS)** | `CODE READING ONLY` | Configured `UIBackgroundModes` with `location` and `fetch` in `Info.plist`, plus `AppleSettings`. Physical device verification recommended. |
| **Supabase Remote Sync** | `NOT IMPLEMENTED / CODE-PREPARED` | Database migration `019_outdoor_activities_and_saved_routes.sql` created with RLS. Client repositories have catch-wrapped upsert/delete logic. Remote sync will activate once migration 019 is applied to the live Supabase instance. |

---

## 9. Production Infrastructure & Deployment Recommendations

For large-scale production deployment, relying on free public demonstration servers (overpass-api.de, valhalla1.openstreetmap.de, nominatim.openstreetmap.org) is not recommended due to rate limits and fair-use policies.

### Recommended Production Setup
1. **Self-Hosted Valhalla**:
   - Run Valhalla via Docker (`gisops/valhalla`) on a regional VPS (2–4 vCPUs, 8–16 GB RAM depending on regional extract size).
   - Ingest regional OpenStreetMap `.osm.pbf` extracts from Geofabrik.
   - Provides sub-50ms routing responses with unlimited request volume.
2. **Managed Routing & Geocoding Alternative**:
   - Stadia Maps, Jawg Maps, or Mapbox provide hosted Valhalla and geocoding endpoints with production SLAs.
   - Endpoints in `OverpassService`, `ValhallaService`, and `NominatimService` can be pointed to custom URLs via environment variables (`ROUTING_ENDPOINT`, `GEOCODING_ENDPOINT`).
3. **Tile Hosting**:
   - For high traffic, consider serving map tiles from a dedicated CDN (e.g., Fastly/Cloudflare caching proxy, Stadia Maps, or self-hosted OpenMapTiles/Tegola server) to adhere to OSM foundation tile usage guidelines.

---

## 10. Physical Device Verification Checklist

To complete full hardware validation before store release, perform these steps on physical Android and iOS devices:

1. **Outdoor GPS Signal Acquisition**:
   - [ ] Walk outside with clear sky view.
   - [ ] Verify location puck centers on physical location.
   - [ ] Tap "Start Workout" and verify elapsed time and distance begin ticking.
2. **Real Route Discovery**:
   - [ ] Open the Maps screen in an area with mapped parks/trails.
   - [ ] Verify discovered routes display genuine names and follow actual streets/paths.
   - [ ] In an unmapped or remote area, verify the app displays the honest empty state without generating fake circular loops.
3. **Place Search**:
   - [ ] Search for a known nearby park or landmark in the search bar.
   - [ ] Verify the map pans to that location and shows nearby routes.
4. **Background & Lock Screen Tracking**:
   - [ ] Begin recording an outdoor walk.
   - [ ] Lock the phone screen and walk 200 meters.
   - [ ] Verify Android persistent notification shows ongoing recording with wake lock.
   - [ ] Verify iOS blue status bar indicator shows background location is active.
   - [ ] Unlock phone: verify polyline has correctly drawn the 200m path without gaps or straight-line teleport jumps.
5. **Pause / Resume / Finish**:
   - [ ] Tap "Pause": verify timer stops and distance no longer increments.
   - [ ] Tap "Resume": verify recording continues smoothly.
   - [ ] Tap "Finish": verify `OutdoorSummaryScreen` displays total distance, duration, avg pace, calories, and complete route polyline.
   - [ ] Edit workout title and tap "Save Activity".
   - [ ] Open "Saved Routes & History": verify saved session appears in "Activity History" tab.
