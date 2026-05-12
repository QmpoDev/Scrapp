# Scrapp — Junkshop Directory App

A mobile directory application for locating junkshops and recycling centers in **La Union, Philippines**. Built with Flutter, Scrapp allows residents and businesses to find nearby scrap buyers, compare material prices, and filter by location or material type. An internet connection is required to load map tiles (CartoDB/OpenStreetMap). The shop directory, search, and all filters work from bundled local data. Tapping Navigate hands off to the device's installed maps application (Google Maps, Waze, etc.) for routing, which also requires connectivity.

---

## Table of Contents

- [Installation & Setup](#installation--setup)
- [Technical Stack](#technical-stack)
- [Architecture Overview](#architecture-overview)
- [Folder Structure](#folder-structure)
- [Key Features & Engineering Rationale](#key-features--engineering-rationale)
- [Applied CS Principles](#applied-cs-principles)
- [Project Assets](#project-assets)
- [Developer's Note](#developers-note)

---

## Installation & Setup

### Prerequisites

- Flutter SDK ≥ 3.9.2
- Dart SDK ≥ 3.9.2
- Android Studio or VS Code with Flutter extension
- Android emulator or physical device (Android 5.0+ / iOS 12+)

### Steps

```bash
# 1. Clone the repository
git clone https://github.com/QmpoDev/Scrapp.git
cd Scrapp

# 2. Install dependencies
flutter pub get

# 3. Generate app icons
dart run flutter_launcher_icons

# 4. Run on a connected device or emulator
flutter run

# 5. Build a release APK
flutter build apk --release
```

### Permissions Required

| Permission | Platform | Purpose |
|---|---|---|
| `ACCESS_FINE_LOCATION` | Android | GPS coordinates for user location dot and distance calculation |
| `ACCESS_COARSE_LOCATION` | Android | Fallback location accuracy |
| `NSLocationWhenInUseUsageDescription` | iOS | Same as above |
| `INTERNET` | Android | Map tile loading (CartoDB/OpenStreetMap) and navigation deep-links |

> The shop directory, search, and all filters work without location permission — the user dot and distance labels are simply hidden. Map tiles and navigation require an active internet connection.

---

## Technical Stack

| Layer | Technology | Version |
|---|---|---|
| Language | Dart | SDK ^3.9.2 |
| Framework | Flutter | Latest stable |
| State Management | flutter_riverpod | ^2.6.1 |
| Map Rendering | flutter_map + latlong2 | ^7.0.2 / ^0.9.0 |
| Map Tiles | CartoDB Light Matter (HTTPS) | — |
| Location Services | geolocator | ^13.0.2 |
| Navigation / Deep Links | url_launcher | ^6.3.1 |
| Persistent Preferences | shared_preferences | ^2.3.3 |
| UI Animations | flutter_animate | ^4.5.0 |
| Splash Video | video_player | ^2.9.2 |
| Linting | flutter_lints | ^5.0.0 |
| App Icons | flutter_launcher_icons | ^0.14.3 |

---

## Architecture Overview

Scrapp follows a **layered MVVM (Model–View–ViewModel)** pattern. The three layers have strict boundaries: the View never touches raw data, the ViewModel never imports Flutter widgets, and the Data layer has no knowledge of UI state.

```
┌─────────────────────────────────────────────────────────┐
│  VIEW LAYER                                             │
│  lib/screens/   lib/widgets/                            │
│  MapScreen · ShopDetailScreen · SplashScreen            │
│  JunkshopBottomSheet · Filter Sheets · WelcomeModal     │
└────────────────────┬────────────────────────────────────┘
                     │  ref.watch / ref.read
┌────────────────────▼────────────────────────────────────┐
│  VIEWMODEL / STATE LAYER                                │
│  lib/providers/shop_provider.dart                       │
│  ShopNotifier · ShopState · filteredShopsProvider       │
│  allMaterialsProvider · pricingBoundsProvider           │
└────────────────────┬────────────────────────────────────┘
                     │  DataLoader.load() / PricingRepository.load()
┌────────────────────▼────────────────────────────────────┐
│  DATA LAYER                                             │
│  lib/data/   lib/models/   lib/utils/                   │
│  DataLoader · PricingRepository · JunkshopModel         │
│  MaterialPrice · ScheduleParser · GeoDistance           │
│  NavigationHandler                                      │
└─────────────────────────────────────────────────────────┘
                     │  AssetBundle (rootBundle)
┌────────────────────▼────────────────────────────────────┐
│  ASSETS (read-only, bundled at compile time)            │
│  junkshops.json · scrap_standard_pricing.json           │
│  la_union_municipalities.json                           │
└─────────────────────────────────────────────────────────┘
```

### Data Flow

1. `main()` wraps the app in a `ProviderScope`, making all Riverpod providers available globally.
2. `ShopNotifier` initialises on first access and calls `DataLoader.load(rootBundle)` asynchronously.
3. `DataLoader` reads `scrap_standard_pricing.json` via `PricingRepository`, builds a bounds map, then parses `junkshops.json` — injecting randomised per-shop prices before constructing each `JunkshopModel`.
4. The loaded list is stored in `ShopState`. All filter state (search query, municipality, materials, price range) lives in the same immutable value object.
5. `filteredShopsProvider` is a derived (synchronous) provider that re-runs whenever `ShopState` changes, applying five sequential filter steps and returning the narrowed list.
6. `MapScreen` watches both `shopProvider` (for filter state) and `filteredShopsProvider` (for the marker list). It calls intent methods on `ShopNotifier` — never mutating state directly.

---

## Folder Structure

```
lib/
├── main.dart                   # Entry point — ProviderScope + MaterialApp
├── theme.dart                  # AppTheme: colour palette + TextTheme
│
├── data/
│   ├── data_loader.dart        # Orchestrates JSON parsing + price injection
│   └── pricing_repository.dart # Parses scrap_standard_pricing.json; owns kMaterialToPricingKey
│
├── models/
│   └── junkshop.dart           # JunkshopModel + MaterialPrice (fromJson / toJson / displayPrice)
│
├── providers/
│   └── shop_provider.dart      # ShopState · ShopNotifier · all derived providers
│
├── screens/
│   ├── map_screen.dart         # Primary screen: map, search bar, filter chips
│   ├── shop_detail_screen.dart # Full shop profile with price list
│   └── splash_screen.dart      # Video splash with fallback navigation
│
├── utils/
│   ├── distance_calculator.dart # GeoDistance.km() — Haversine formula
│   ├── navigation_handler.dart  # geo: / maps.google.com deep-link launcher
│   └── schedule_parser.dart     # Parses "H:MM AM/PM - H:MM AM/PM" strings
│
└── widgets/
    ├── animated_marker.dart         # Copper pin with press-scale + pulsing user dot
    ├── glass_container.dart         # Frosted-glass surface (BackdropFilter)
    ├── junkshop_bottom_sheet.dart   # Quick-glance sheet on marker tap
    ├── material_filter_sheet.dart   # Multi-select material filter
    ├── municipality_filter_sheet.dart # Single-select municipality filter
    ├── price_filter_sheet.dart      # Material + RangeSlider price filter
    └── welcome_modal.dart           # First-launch onboarding dialog

assets/
├── data/
│   ├── junkshops.json               # 17 shop records (wrapped-object format)
│   ├── scrap_standard_pricing.json  # Standard price bounds per material
│   └── la_union_municipalities.json # Municipality list for the location filter
├── images/logo/
└── video/splash_animation/
```

---

## Key Features & Engineering Rationale

### 1. Local-First, Offline-Capable Data Strategy

**What:** All shop data is bundled as JSON assets. No network request is made to browse shops, search, or filter — the directory itself works from local data.

**Why:** La Union has variable connectivity. Bundling data guarantees the core directory experience (browsing, searching, filtering, viewing prices) is always available regardless of signal. Map tiles (CartoDB/OpenStreetMap) do require an internet connection to render, and navigation hands off to an external maps app which also needs connectivity. The `AssetBundle` abstraction means the data source can be swapped (e.g., to a remote API) without touching any provider or UI code.

---

### 2. Immutable State with `copyWith` and the Sentinel Pattern

**What:** `ShopState` is a `const`-constructable value object. Every mutation returns a new instance via `copyWith`. Nullable fields that need to be explicitly set to `null` (e.g., clearing a municipality filter) use a private `_sentinel` object as the default parameter value.

**Why:** Mutable state is the primary source of hard-to-reproduce bugs in reactive UIs. Immutable state makes every transition explicit and traceable. The sentinel pattern solves Dart's limitation where `null` cannot be distinguished from "not provided" in optional named parameters — a common pitfall when building `copyWith` for nullable fields.

```dart
// Without sentinel: impossible to clear selectedMunicipality to null
ShopState copyWith({ String? selectedMunicipality }) { ... }

// With sentinel: null means "clear it", omitting means "keep current"
ShopState copyWith({ Object? selectedMunicipality = _sentinel }) { ... }
```

---

### 3. Per-Shop Randomised Pricing (Session-Stable)

**What:** At load time, `DataLoader._generatePrices()` generates a unique price for each material at each shop by randomising within the standard bounds from `scrap_standard_pricing.json`. Prices are generated once per app session and remain stable until the app restarts.

**Why:** Real junkshops vary their rates. Hardcoding identical prices across all shops would make the price filter meaningless. The randomisation algorithm uses a single `Random()` instance shared across all shops (not re-seeded per shop), ensuring statistical independence between shops. The algorithm biases `randomMin` toward the lower half of the range (multiplied by 0.5) to reflect realistic market behaviour where most shops pay below the ceiling rate.

```
randomMin = bounds.min + rng.nextDouble() × (bounds.max - bounds.min) × 0.5
randomMax = randomMin + rng.nextDouble() × (bounds.max - randomMin)
```

Both values are rounded to 2 decimal places and clamped to `[bounds.min, bounds.max]` with `min ≤ max` guaranteed.

---

### 4. Composable Filter Pipeline

**What:** `filteredShopsProvider` applies five filters in a fixed sequence: Municipality → Open Now → Material → Price → Text Search. Each step operates on the output of the previous step.

**Why:** Sequential composition is more predictable than parallel filtering with AND logic applied at the end. It also short-circuits naturally — if the municipality filter reduces 17 shops to 3, the remaining four steps only process 3 records. The provider is declared as a synchronous `Provider<List<JunkshopModel>>` (not a `FutureProvider`) because all inputs are already loaded into `ShopState`; no async work is needed at filter time.

**Price filter overlap logic:** A shop qualifies if its price range *overlaps* the selected range, not just if its `min` falls within it. This is the correct interval-overlap condition:

```
shop.min ≤ filter.end  AND  shop.max ≥ filter.start
```

This prevents false negatives where a shop paying ₱501–₱645 for Copper would be excluded by a ₱510–₱560 filter under a naive `min-in-range` check.

---

### 5. Schedule Parsing and Midnight-Spanning Ranges

**What:** `ScheduleParser.parse()` uses a single regex to extract open/close times from strings like `"8:00 AM - 5:00 PM"`. `ScheduleParser.isOpen()` evaluates the current device time against the parsed range.

**Why:** The parser handles midnight-spanning schedules (e.g., `"10:00 PM - 2:00 AM"`) by detecting when `closeMinutes < openMinutes` in total-minutes representation and applying OR logic instead of AND:

```dart
// Normal range: open ≤ now ≤ close
// Overnight range: now ≥ open OR now ≤ close
```

This is a non-trivial edge case that naive implementations miss, causing shops with late-night hours to always appear closed.

---

### 6. Haversine Distance Calculation

**What:** `GeoDistance.km(LatLng a, LatLng b)` computes the great-circle distance between two coordinates using the Haversine formula.

**Why:** The Haversine formula accounts for Earth's spherical geometry. The simpler Euclidean distance on raw lat/lng coordinates produces significant errors at the distances relevant to this app (~5–50 km). The function was extracted from `MapScreen` into `lib/utils/distance_calculator.dart` so it can be unit-tested independently of the widget tree — a direct application of the Single Responsibility Principle.

---

### 7. Navigation Deep-Link Strategy

**What:** `NavigationHandler.launch()` tries `geo:<lat>,<lng>?q=<lat>,<lng>` first, then falls back to `https://maps.google.com/maps?q=<lat>,<lng>`. Both use `LaunchMode.externalApplication`.

**Why:** The `geo:` URI scheme is the Android standard and opens any registered maps app (Google Maps, Waze, etc.). The HTTPS fallback works cross-platform and triggers Google Maps via universal links on iOS. `LaunchMode.externalApplication` is critical — without it, `url_launcher` defaults to opening the URL inside the app, where the `geo:` scheme has no handler and silently fails.

---

### 8. Location Permission UX

**What:** On first launch, the app shows the welcome modal first, then requests location permission. The permission request fires automatically — the user does not need to tap the GPS button.

**Why:** Showing a system permission dialog immediately on cold start (before any context) is a known UX anti-pattern that leads to high denial rates. By sequencing the welcome modal first, the user understands the app's purpose before the OS dialog appears, increasing the likelihood of granting permission. The sequencing is implemented with `await showWelcomeModalIfNeeded(context)` followed by `_initLocation()` inside a single `addPostFrameCallback`.

---

### 9. Responsive Layout Strategy

**What:** Padding, font sizes, and dialog heights are computed as proportions of `MediaQuery.sizeOf(context)` and clamped to min/max values.

**Why:** Flutter's `MediaQuery` provides logical pixels, not physical pixels, making proportional sizing device-independent. The `clamp()` pattern prevents layouts from becoming unusably small on 320px-wide phones or excessively large on tablets. For example:

```dart
final hPad = (screenWidth * 0.053).clamp(14.0, 24.0);
```

This gives 17px padding on a 320px phone, 20px on a 390px phone, and caps at 24px on wide screens — all from a single expression.

---

### 10. Glass Morphism Surface

**What:** `GlassContainer` wraps its child in a `BackdropFilter` with a Gaussian blur (`sigmaX/Y = 12`) and a semi-transparent white fill.

**Why:** The map is always visible behind the UI overlays. A solid white background would obscure the map context. The frosted-glass effect maintains spatial awareness while keeping text legible. `ClipRRect` is required before `BackdropFilter` to prevent the blur from bleeding outside the rounded corners — a common Flutter gotcha.

---

## Applied CS Principles

| Principle | Where Applied |
|---|---|
| **Single Responsibility** | `PricingRepository` only parses pricing JSON; `DataLoader` only orchestrates shop loading; `GeoDistance` only computes distance |
| **Open/Closed** | `DataLoader` supports both flat-array and wrapped-object JSON formats without modifying the parsing logic for either |
| **Dependency Inversion** | `ShopNotifier` and `DataLoader` accept `AssetBundle` as a parameter rather than importing `rootBundle` directly, enabling mock injection in tests |
| **DRY** | `kMaterialToPricingKey` is defined once in `pricing_repository.dart` and imported by both `DataLoader` and `pricingBoundsProvider` |
| **Separation of Concerns** | View layer calls intent methods (`setQuery`, `setPriceFilter`); ViewModel owns all filter logic; Data layer owns all parsing |
| **Immutability** | `ShopState`, `JunkshopModel`, `MaterialPrice`, and `PricingBounds` are all `const`-constructable value objects |
| **Async Programming** | `DataLoader.load()`, `PricingRepository.load()`, and `NavigationHandler.launch()` are all `async/await` Futures; `pricingBoundsProvider` is a `FutureProvider` |

---

---

## Project Assets

| Asset | Format | Purpose |
|---|---|---|
| `junkshops.json` | JSON (wrapped object) | 17 junkshop records with coordinates, schedule, accepted materials |
| `scrap_standard_pricing.json` | JSON (nested object) | Standard min/max price bounds per material category |
| `la_union_municipalities.json` | JSON | Municipality list for the location filter chip |
| `SplashAnimation_Scrapp.mp4` | MP4 | Branded splash screen video |
| `scrapp-s-logo.png` | PNG | App icon and in-app logo |

---

## Developer's Note

This project was built to a standard that reflects the transition from a course-level implementation to professional-grade mobile development. Several deliberate engineering decisions were made beyond what the course requirements demanded:

**Testability by design.** `AssetBundle` injection into `ShopNotifier` and `DataLoader` means the entire data pipeline can be tested with a `FakeAssetBundle` — no device, no file system, no Flutter widget tree required. This is the Dependency Inversion Principle applied at the appropriate level for a mobile app.

**A single source of truth for data mapping.** The `kMaterialToPricingKey` constant was centralised in `pricing_repository.dart` after identifying that it was duplicated across two files. Duplication of this kind is the most common source of silent bugs in data-heavy apps — one copy gets updated, the other doesn't.

**Filter correctness over filter simplicity.** The price filter uses interval-overlap logic rather than a simpler point-in-range check. The schedule parser handles midnight-spanning hours. These edge cases were identified through systematic QA analysis of the filter logic against the actual data, not discovered at runtime.

**Responsive layout without a single `if (width < 360)` branch.** All responsive sizing uses proportional clamping (`value.clamp(min, max)`), which scales continuously across all screen sizes rather than snapping between breakpoints. This produces a more natural feel on the wide range of Android hardware in the Philippine market.

**Comment discipline.** Comments in this codebase explain *why* a decision was made, not *what* the code does. The code itself communicates the what; the comments communicate the engineering rationale. This distinction is the difference between documentation that helps future maintainers and documentation that adds noise.
