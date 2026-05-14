# Scrapp — Junkshop Directory App

A mobile directory application for locating junkshops and recycling centers in **La Union, Philippines**. Built with Flutter, Scrapp allows residents and businesses to find nearby scrap buyers, compare material prices, and filter by location or material type.

The app now supports **zero-friction junkshop registration** — any user can submit a new listing directly from the map without creating an account. Security is enforced through GPS geofencing, device fingerprinting, and a locally-stored edit token. Submitted shops enter a `pending` state and are promoted to `verified` by an admin via a web dashboard.

---

## Table of Contents

- [Installation & Setup](#installation--setup)
- [Technical Stack](#technical-stack)
- [Architecture Overview](#architecture-overview)
- [Folder Structure](#folder-structure)
- [Zero-Friction Registration System](#zero-friction-registration-system)
- [Admin Dashboard](#admin-dashboard)
- [Data Migration](#data-migration)
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
- A Supabase project (for the live backend)

### Steps

```bash
# 1. Clone the repository
git clone https://github.com/QmpoDev/Scrapp.git
cd Scrapp

# 2. Install dependencies
flutter pub get

# 3. Generate app icons
dart run flutter_launcher_icons

# 4. Run on a connected device or emulator (with Supabase credentials)
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key

# 5. Build a release APK
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

### Supabase Setup

1. Create a new Supabase project at [supabase.com](https://supabase.com)
2. Run the SQL migrations in order from `supabase/migrations/`:
   - `001_create_junkshops.sql` — main table with PostGIS geography column
   - `002_create_otp_tokens.sql` — OTP recovery table
   - `003_rls_policies.sql` — Row Level Security policies
   - `004_update_shop_function.sql` — token-gated update function
   - `005_otp_verify_function.sql` — OTP verification function
3. Enable the PostGIS extension in your Supabase project (Database → Extensions)
4. Create a `storefront-photos` storage bucket (public)
5. Run the migration script to seed existing shops (see [Data Migration](#data-migration))

### Permissions Required

| Permission | Platform | Purpose |
|---|---|---|
| `ACCESS_FINE_LOCATION` | Android | GPS for user location and shop registration geofencing |
| `ACCESS_COARSE_LOCATION` | Android | Fallback location accuracy |
| `NSLocationWhenInUseUsageDescription` | iOS | Same as above |
| `CAMERA` | Android & iOS | Storefront photo capture during registration |
| `READ_MEDIA_IMAGES` | Android 13+ | Required by image_picker |
| `WRITE_EXTERNAL_STORAGE` | Android ≤ 12 | Required by image_picker |
| `INTERNET` | Android | Map tiles, Supabase API, navigation deep-links |

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
| Backend / Database | Supabase + PostGIS | — |
| Camera / Photo | image_picker | ^1.1.2 |
| Secure Storage | flutter_secure_storage | ^9.2.2 |
| Device Identity | device_info_plus | ^10.1.2 |
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
┌─────────────────────────────────────────────────────────────────────┐
│  VIEW LAYER                                                         │
│  lib/screens/   lib/widgets/                                        │
│  MapScreen · ShopDetailScreen · SplashScreen                        │
│  RegistrationPinScreen · RegistrationFormScreen                     │
│  RegistrationSuccessScreen · ShopEditScreen · ClaimShopScreen       │
│  JunkshopBottomSheet · Filter Sheets · WelcomeModal                 │
│  RegistrationFab · PendingStatusBadge · AnimatedMarker              │
└────────────────────┬────────────────────────────────────────────────┘
                     │  ref.watch / ref.read
┌────────────────────▼────────────────────────────────────────────────┐
│  VIEWMODEL / STATE LAYER                                            │
│  lib/providers/                                                     │
│  ShopNotifier · ShopState · filteredShopsProvider                   │
│  RegistrationNotifier · RegistrationState                           │
│  editTokenProvider · deviceFingerprintProvider                      │
│  supabaseProvider · tokenStoreProvider                              │
└────────────────────┬────────────────────────────────────────────────┘
                     │  SupabaseShopRepository / TokenStore / Services
┌────────────────────▼────────────────────────────────────────────────┐
│  DATA / SERVICE LAYER                                               │
│  lib/data/   lib/models/   lib/services/   lib/utils/              │
│  SupabaseShopRepository · TokenStore · SecureTokenStore             │
│  GeofenceService · PhotoService · OtpService                        │
│  JunkshopModel · ShopStatus · MaterialPrice                         │
│  ScheduleParser · GeoDistance · NavigationHandler                   │
└────────────────────┬────────────────────────────────────────────────┘
                     │  Supabase REST + Realtime
┌────────────────────▼────────────────────────────────────────────────┐
│  BACKEND (Supabase)                                                 │
│  junkshops table (PostGIS) · otp_tokens table                       │
│  RLS policies · update_shop_with_token() · verify_otp_and_recover() │
│  Supabase Storage (storefront-photos bucket)                        │
└─────────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. `main()` initialises Supabase before `runApp`, then wraps the app in a `ProviderScope`.
2. `ShopNotifier` fetches shops from Supabase on startup and subscribes to Realtime changes.
3. `filteredShopsProvider` derives the filtered view, excluding `rejected` shops.
4. `MapScreen` renders markers colour-coded by status: copper for `verified`, amber for `pending`.
5. Tapping the "+" FAB starts the registration flow via `RegistrationNotifier`.
6. On submission, the app enforces GPS geofencing (50 m), device rate limiting (1/24 h), photo capture, and Supabase insert.
7. The returned `edit_token` is stored in `flutter_secure_storage` for future edits.

---

## Folder Structure

```
lib/
├── main.dart                        # Entry point — Supabase init + ProviderScope
├── theme.dart                       # AppTheme: colour palette + TextTheme
│
├── data/
│   ├── data_loader.dart             # Legacy local JSON loader (kept for migration script)
│   ├── pricing_repository.dart      # Parses scrap_standard_pricing.json
│   ├── supabase_shop_repository.dart # All Supabase queries for junkshops
│   └── token_store.dart             # TokenStore interface + SecureTokenStore
│
├── models/
│   └── junkshop.dart                # JunkshopModel + ShopStatus + MaterialPrice
│
├── providers/
│   ├── shop_provider.dart           # ShopNotifier · filteredShopsProvider
│   ├── registration_provider.dart   # RegistrationNotifier state machine
│   ├── supabase_provider.dart       # SupabaseClient singleton
│   ├── device_fingerprint_provider.dart
│   ├── token_store_provider.dart
│   └── edit_token_provider.dart
│
├── screens/
│   ├── map_screen.dart              # Primary screen: map, search, filters, FAB
│   ├── shop_detail_screen.dart      # Full shop profile with price list
│   ├── splash_screen.dart           # Video splash with fallback navigation
│   ├── registration_pin_screen.dart # Drop-pin map for shop location
│   ├── registration_form_screen.dart # Shop name / owner / contact form
│   ├── registration_success_screen.dart
│   ├── shop_edit_screen.dart        # Token-gated edit form
│   └── claim_shop_screen.dart       # Two-step OTP recovery flow
│
├── services/
│   ├── geofence_service.dart        # Haversine distance + 50 m geofence check
│   ├── photo_service.dart           # Camera capture + 2 MB compression
│   └── otp_service.dart             # OTP send/verify via Supabase RPC
│
├── utils/
│   ├── distance_calculator.dart     # GeoDistance.km() — Haversine formula
│   ├── navigation_handler.dart      # geo: / maps.google.com deep-link launcher
│   └── schedule_parser.dart         # Parses "H:MM AM/PM - H:MM AM/PM" strings
│
└── widgets/
    ├── animated_marker.dart         # Status-aware pin (copper/amber/green)
    ├── glass_container.dart         # Frosted-glass surface (BackdropFilter)
    ├── junkshop_bottom_sheet.dart   # Quick-glance sheet with Edit/Claim buttons
    ├── pending_status_badge.dart    # Amber "Pending Verification" pill
    ├── registration_fab.dart        # Amber "+" FAB with GPS loading state
    ├── material_filter_sheet.dart
    ├── municipality_filter_sheet.dart
    ├── price_filter_sheet.dart
    └── welcome_modal.dart

supabase/
└── migrations/
    ├── 001_create_junkshops.sql
    ├── 002_create_otp_tokens.sql
    ├── 003_rls_policies.sql
    ├── 004_update_shop_function.sql
    └── 005_otp_verify_function.sql

tools/
└── migration/
    ├── pubspec.yaml
    └── migrate_shops.dart           # Seeds existing JSON shops into Supabase

admin-dashboard/                     # Next.js 14 admin verification dashboard
├── lib/supabase.ts
├── pages/
│   ├── dashboard/index.tsx          # Pending submissions list
│   └── api/shops/[id]/
│       ├── approve.ts
│       └── reject.ts
└── package.json

assets/
├── data/
│   ├── junkshops.json               # 17 legacy shop records (used by migration script)
│   ├── scrap_standard_pricing.json  # Standard price bounds per material
│   └── la_union_municipalities.json # Municipality list for the location filter
├── images/logo/
└── video/splash_animation/
```

---

## Zero-Friction Registration System

The registration system lets any user submit a junkshop listing without creating an account. Security is enforced through three physical credentials:

### UX Flow

1. **Tap the "+" FAB** (bottom-left of the map) — the app acquires a high-accuracy GPS fix (≤ 20 m, 15 s timeout)
2. **Place the pin** — a full-screen map opens at zoom 17; pan to position the pin over the shop's rooftop
3. **Fill in details** — Shop Name, Owner Full Name, Contact Number (3 fields, no password)
4. **Take a photo** — the device camera opens; gallery uploads are blocked to enforce physical presence
5. **Submit** — the app re-checks GPS (must be within 50 m of the pin), checks device rate limit (1 submission/24 h), uploads the photo, and inserts the record

### Security Layer

| Mechanism | Implementation |
|---|---|
| **GPS Geofencing** | Haversine distance between submission GPS and pin must be < 50 m |
| **Device Fingerprinting** | Android ID / iOS `identifierForVendor` limits to 1 submission per device per 24 hours |
| **Edit Token** | UUID returned by the database on insert, stored in `flutter_secure_storage`; required to edit the listing |

### Shop Status

| Status | Pin Colour | Visible on Map |
|---|---|---|
| `pending` | Amber `#FFA000` | Yes |
| `verified` | Copper `#B87333` | Yes |
| `rejected` | — | No |

### Editing & Token Recovery

- The **"Edit"** button appears in the bottom sheet only if the device holds a matching edit token
- If the token is lost (new phone), the **"Claim This Shop"** button triggers a 6-digit OTP sent to the registered contact number
- OTP flow: 5-minute expiry, max 3 attempts, 30-minute lockout, max 3 resends

---

## Admin Dashboard

The `admin-dashboard/` directory contains a Next.js 14 web app for reviewing pending submissions.

### Features

- Paginated list of pending shops (25 per page, oldest first)
- Per-shop: name, owner, contact, municipality, submission timestamp, storefront photo, Google Street View link
- **Approve** — sets `status = 'verified'`, shop pin turns copper for all users
- **Reject** — requires a mandatory rejection reason (1–500 chars), sets `status = 'rejected'`, pin disappears from map
- Filter by municipality and date range

### Running the Dashboard

```bash
cd admin-dashboard
cp .env.local.example .env.local
# Fill in NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY
npm install
npm run dev
```

> The service-role key bypasses RLS and must never be exposed to the browser. The dashboard is server-side rendered — the key only lives on the server.

---

## Data Migration

To seed the existing 17 local JSON shops into Supabase as pre-verified records:

```bash
cd tools/migration
dart pub get
SUPABASE_URL=https://your-project.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key \
dart run migrate_shops.dart
```

The script derives a stable UUID v5 per shop from `name + '|' + municipality`, so re-running it is safe (idempotent upsert).

---

## Testing Guide

This section walks through setting up Supabase and testing every part of the registration system end-to-end.

### Step 1 — Create a Supabase Project

1. Go to [supabase.com](https://supabase.com) and create a free account
2. Click **New Project**, choose a region close to the Philippines (e.g. Singapore)
3. Once the project is ready, go to **Settings → API** and note:
   - **Project URL** (e.g. `https://xyzxyz.supabase.co`)
   - **anon public key** — used by the Flutter app
   - **service_role key** — used by the admin dashboard and migration script (keep this secret)

### Step 2 — Enable PostGIS

In your Supabase dashboard: **Database → Extensions → search "postgis" → Enable**

### Step 3 — Run the SQL Migrations

Go to **SQL Editor** in your Supabase dashboard and run each file in order:

```
supabase/migrations/001_create_junkshops.sql
supabase/migrations/002_create_otp_tokens.sql
supabase/migrations/003_rls_policies.sql
supabase/migrations/004_update_shop_function.sql
supabase/migrations/005_otp_verify_function.sql
```

Paste each file's contents into the SQL Editor and click **Run**.

### Step 4 — Create the Storage Bucket

In your Supabase dashboard: **Storage → New bucket**
- Name: `storefront-photos`
- Toggle **Public bucket** ON
- Click **Create bucket**

### Step 5 — Seed Existing Shops

Run the migration script to populate Supabase with the 17 existing shops as verified records:

```bash
cd tools/migration
dart pub get

# Windows (PowerShell)
$env:SUPABASE_URL="https://yourproject.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
dart run migrate_shops.dart

# macOS / Linux
SUPABASE_URL=https://yourproject.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key \
dart run migrate_shops.dart
```

You should see `OK` for each of the 17 shops and a summary at the end.

### Step 6 — Run the Flutter App

> **Important:** Registration requires a physical Android or iOS device. The GPS geofence and camera enforcement do not work on emulators.

```bash
# From the project root
flutter run \
  --dart-define=SUPABASE_URL=https://yourproject.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

The map should load and show the 17 seeded shops as copper pins.

### Step 7 — Test the Registration Flow

1. Tap the amber **"+"** FAB in the bottom-left corner of the map
2. Wait for the GPS fix (the FAB shows a spinner) — this takes a few seconds outdoors
3. The map zooms to zoom level 17 — pan to position the pin over your exact location
4. Tap **Confirm Location**
5. Fill in the three fields: Shop Name, Owner Full Name, Contact Number
6. Tap **Next — Take Photo** — the camera opens
7. Take a photo of anything in front of you (the storefront)
8. The app submits — you should see the success screen with "Pending admin review"
9. Go back to the map — an **amber pin** should appear at your location

### Step 8 — Verify via Admin Dashboard

```bash
cd admin-dashboard
cp .env.local.example .env.local
```

Edit `.env.local`:
```
NEXT_PUBLIC_SUPABASE_URL=https://yourproject.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) — you should see your test submission in the pending list.

Click **Approve** → enter a confirmation → the pin on the map turns **copper** within a few seconds (Realtime subscription).

### Step 9 — Test the Edit Flow

1. Tap the copper pin you just approved
2. The bottom sheet should show an **"Edit Listing"** button (because the edit token is stored on your device)
3. Tap **Edit Listing** → the edit form opens pre-populated
4. Change the shop name → tap **Save Changes**
5. The map refreshes and the bottom sheet shows the updated name

### Step 10 — Test the Claim Flow (Token Recovery)

To simulate losing your token:

1. Go to **flutter_secure_storage** — you can clear app data on Android (Settings → Apps → Scrapp → Clear Data)
2. Reopen the app and tap the pin
3. The **"Edit Listing"** button is gone; **"Claim This Shop"** appears instead
4. Tap **Claim This Shop** → enter the contact number you registered with
5. You'll receive an OTP SMS (requires the Supabase `send-otp` Edge Function to be deployed — see note below)
6. Enter the 6-digit OTP → the edit form opens

> **Note on OTP SMS:** The `send-otp` Edge Function needs to be deployed to your Supabase project separately. It handles sending the SMS via a provider like Twilio or Vonage. Without it, the OTP send step will return an error. For testing purposes, you can manually insert an OTP record into the `otp_tokens` table in Supabase Studio.

### Common Issues

| Issue | Fix |
|---|---|
| Map shows error state | Check that `SUPABASE_URL` and `SUPABASE_ANON_KEY` are correct |
| GPS fix times out | Test outdoors; emulators don't provide real GPS |
| Geofence rejection | You must be within 50 m of the pin — don't drag the pin far from your actual location |
| Photo upload fails | Check that the `storefront-photos` bucket exists and is set to public |
| Migration script fails | Ensure PostGIS is enabled and all 5 SQL migrations ran successfully |

---

## Key Features & Engineering Rationale

### 1. Zero-Friction Registration

**What:** Shop owners register without creating an account. Security is enforced through GPS geofencing, device fingerprinting, and a locally-stored UUID edit token.

**Why:** Non-tech-savvy junkshop owners in La Union are unlikely to complete a traditional sign-up flow. Removing the login barrier maximises adoption while the physical-presence checks (GPS + camera) prevent remote abuse.

---

### 2. Supabase Realtime for Live Status Updates

**What:** `ShopNotifier` subscribes to Postgres changes on the `junkshops` table. When an admin approves or rejects a shop, the pin colour updates for all connected users within seconds.

**Why:** The admin verification loop is the critical path. Without Realtime, a newly verified shop would only appear after the user restarts the app. The subscription is set up once in `ShopNotifier._subscribeRealtime()` and torn down in `dispose()`.

---

### 3. Token-Gated Editing via SECURITY DEFINER Function

**What:** Shop edits are routed through a PostgreSQL `SECURITY DEFINER` function (`update_shop_with_token`) that validates the edit token server-side before applying changes. Anonymous users have no direct UPDATE permission.

**Why:** RLS alone cannot enforce token validation because the token value is stored in the same row being updated. A SECURITY DEFINER function runs with elevated privileges, reads the stored token, compares it to the submitted token, and only then applies the update — preventing any bypass.

---

### 4. Immutable State with `copyWith` and the Sentinel Pattern

**What:** `ShopState` and `RegistrationState` are `const`-constructable value objects. Every mutation returns a new instance via `copyWith`. Nullable fields use a private `_sentinel` object to distinguish "not provided" from explicit `null`.

**Why:** Mutable state is the primary source of hard-to-reproduce bugs in reactive UIs. The sentinel pattern solves Dart's limitation where `null` cannot be distinguished from "not provided" in optional named parameters.

---

### 5. Composable Filter Pipeline

**What:** `filteredShopsProvider` applies filters in a fixed sequence: Rejected exclusion → Municipality → Open Now → Material → Price → Text Search. Each step operates on the output of the previous step.

**Why:** Sequential composition is more predictable than parallel filtering. It also short-circuits naturally — if the municipality filter reduces 17 shops to 3, the remaining steps only process 3 records.

---

### 6. Per-Shop Randomised Pricing (Session-Stable)

**What:** At load time, `DataLoader._generatePrices()` generates a unique price for each material at each shop by randomising within the standard bounds from `scrap_standard_pricing.json`. Prices are stable for the lifetime of the app session.

**Why:** Real junkshops vary their rates. Hardcoding identical prices across all shops would make the price filter meaningless.

---

### 7. Schedule Parsing and Midnight-Spanning Ranges

**What:** `ScheduleParser.isOpen()` handles overnight schedules (e.g., `"10:00 PM - 2:00 AM"`) by detecting when `closeMinutes < openMinutes` and applying OR logic instead of AND.

**Why:** A naive implementation would cause shops with late-night hours to always appear closed — a non-trivial edge case that only surfaces with real data.

---

## Applied CS Principles

| Principle | Where Applied |
|---|---|
| **Single Responsibility** | `GeofenceService` only computes distances; `PhotoService` only handles capture/compression; `OtpService` only manages OTP flows |
| **Open/Closed** | `TokenStore` is an abstract interface; `SecureTokenStore` is the production implementation; tests can inject a mock |
| **Dependency Inversion** | `RegistrationNotifier` accepts `SupabaseShopRepository` and `TokenStore` as constructor parameters, enabling test injection |
| **DRY** | `kMaterialToPricingKey` is defined once in `pricing_repository.dart`; form validation rules are shared between `RegistrationFormScreen` and `ShopEditScreen` |
| **Separation of Concerns** | View calls intent methods; ViewModel owns state transitions; Data layer owns all Supabase queries |
| **Immutability** | `ShopState`, `RegistrationState`, `JunkshopModel`, `MaterialPrice` are all `const`-constructable value objects |
| **Async Programming** | All network operations use `async/await`; GPS acquisition uses `.timeout()` to enforce hard deadlines |

---

## Project Assets

| Asset | Format | Purpose |
|---|---|---|
| `junkshops.json` | JSON | 17 legacy shop records (used by migration script) |
| `scrap_standard_pricing.json` | JSON | Standard min/max price bounds per material category |
| `la_union_municipalities.json` | JSON | Municipality list for the location filter chip |
| `SplashAnimation_Scrapp.mp4` | MP4 | Branded splash screen video |
| `scrapp-s-logo.png` | PNG | App icon and in-app logo |

---

## Developer's Note

This project was built to a standard that reflects the transition from a course-level implementation to professional-grade mobile development. The zero-friction registration system in particular required careful thinking about security without authentication — a genuinely hard problem.

**Physical credentials over passwords.** The GPS geofence, camera enforcement, and device fingerprint together form a "proof of presence" system. None of these checks are individually unbreakable, but together they raise the cost of abuse high enough to deter casual fraud while keeping the UX frictionless for legitimate owners.

**Server-side token validation.** The `update_shop_with_token` SECURITY DEFINER function is the correct pattern for this problem. Doing the token check client-side would be trivially bypassable. Doing it in a regular RLS policy is impossible because the token is in the same row being updated. The SECURITY DEFINER function is the only approach that is both secure and correct.

**Testability by design.** `SupabaseShopRepository`, `TokenStore`, `GeofenceService`, and `PhotoService` are all constructor-injected into `RegistrationNotifier`. This means the entire registration pipeline can be tested with mock implementations — no device, no network, no camera required.

**Comment discipline.** Comments in this codebase explain *why* a decision was made, not *what* the code does. The code itself communicates the what; the comments communicate the engineering rationale.
