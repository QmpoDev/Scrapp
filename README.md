# Scrapp — Production-Ready Junkshop Ecosystem

A robust, full-stack platform for locating, registering, and managing junkshops and recycling centers in **La Union, Philippines**. Built with a modern tech stack centered around **Supabase**, Scrapp bridges the gap between environmental sustainability and local commerce.

The ecosystem consists of:
1.  **Mobile App (Flutter)**: A premium directory for residents to find junkshops, view material prices, and for owners to register their businesses.
2.  **Admin Dashboard (Next.js)**: A high-fidelity verification panel for administrators to review and approve shop submissions.
3.  **Supabase Backend**: A PostgreSQL database with PostGIS for spatial queries, secure Auth, and real-time synchronization.

---

## Table of Contents

- [Core Features](#core-features)
- [Installation & Setup](#installation--setup)
- [Technical Stack](#technical-stack)
- [Architecture Overview](#architecture-overview)
- [Database Schema](#database-schema)
- [Admin Dashboard](#admin-dashboard)
- [Data Migration](#data-migration)
- [Applied CS Principles](#applied-cs-principles)

---

## Core Features

### 📍 Public Map & Discovery
- **Anonymous Browsing**: Users can view the map and filter junkshops without an account.
- **PostGIS Spatial Queries**: High-performance "Open Now" and "Nearby" filtering using GIST indexing.
- **Material Pricing**: Compare standard pricing bounds for magnetic metals, plastics, paper, and more.

### 🏪 Junkshop Registration (Auth-Gated)
- **Supabase Auth Integration**: Secure owner accounts with Login/Signup workflows.
- **Full-Screen Registration Wizard**: A premium, multi-step form capturing detailed address, operating schedules, and categories.
- **Relational Material Selection**: Owners can select exactly which materials they accept from a dynamic list.
- **Physical Verification**: GPS geofencing (50m radius) and mandatory storefront photo capture to prevent fraudulent entries.

### 🛡️ Verification Pipeline
- **Real-time Status**: Submissions appear instantly as `pending` (amber pins).
- **Admin Approval**: Promotes shops to `active` (copper pins) via the web dashboard.
- **Public Visibility Control**: Only `active` shops are visible on the map by default.

---

## Installation & Setup

### Prerequisites
- Flutter SDK ≥ 3.24.x
- Node.js ≥ 18.x (for Admin Dashboard & Migration)
- A Supabase project with PostGIS enabled

### Mobile App Setup
```bash
# 1. Clone and install dependencies
git clone https://github.com/QmpoDev/Scrapp.git
cd Scrapp
flutter pub get

# 2. Run with credentials
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

### Admin Dashboard Setup
```bash
cd admin-dashboard
npm install
# Set NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY, and SUPABASE_SERVICE_ROLE_KEY in .env.local
npm run dev
```

### Database Initialization
1.  Enable the **PostGIS** extension in Supabase.
2.  Run the migration script: `supabase/migrations/007_phase1_init.sql`.
3.  Create a public storage bucket named `junkshop-storefronts`.

---

## Technical Stack

| Layer | Technology |
|---|---|
| **Mobile App** | Flutter, Riverpod, Geolocator, flutter_map |
| **Admin Dashboard** | Next.js 14, Tailwind CSS, Lucide React |
| **Backend** | Supabase (PostgreSQL + PostGIS) |
| **Authentication** | Supabase Auth (Email/Password) |
| **Storage** | Supabase Storage (Storefront Photos) |
| **Migration** | TypeScript, ts-node |

---

## Architecture Overview

Scrapp uses a **Layered Architecture** with strict separation of concerns, coordinated by Riverpod on mobile and Next.js Server Actions on the web.

```
┌──────────────────────────┐      ┌──────────────────────────┐
│      MOBILE APP          │      │     ADMIN DASHBOARD      │
│ (Flutter / Riverpod)     │      │     (Next.js 14)         │
└───────────┬──────────────┘      └──────────────┬───────────┘
            │                                    │
            │          ┌──────────────────┐      │
            └──────────►  SUPABASE API     ◄─────┘
                       │ (REST/Realtime)  │
                       └────────┬─────────┘
                                │
             ┌──────────────────┴──────────────────┐
             │         POSTGRESQL DATABASE         │
             │  (PostGIS / RLS / Auth / Triggers)  │
             └─────────────────────────────────────┘
```

---

## Database Schema

The system uses a **Fully Normalized Relational Schema** to ensure data integrity and scalability:

- `profiles`: Extends Supabase Auth users with role-based metadata.
- `junkshops`: Main shop records with a PostGIS `geography` column.
- `categories`: Definitions for shop types (e.g., Aggregator vs. Community Center).
- `materials`: Master list of recyclable materials and base pricing.
- `junkshop_materials`: Junction table mapping shops to the materials they accept.
- `ref_municipalities`: Geography reference for the 20 municipalities of La Union.

---

## Admin Dashboard

The `admin-dashboard/` features a **Premium Dark UI** designed for high-efficiency verification.

- **Approval Queue**: Filterable list of all `pending` submissions.
- **Validation Tools**: Direct Google Street View links and storefront photo expansion.
- **One-Click Actions**: Approve (activates shop) or Reject (requires a specific reason).
- **Relational Filtering**: Filter submissions by Municipality and Date Range.

---

## Data Migration

To seed the live database with existing JSON datasets:

```bash
cd tools
npm install
# Set environment variables
npx ts-node migration_service.ts
```

This script normalizes and seeds:
- 20 Municipalities of La Union.
- 50+ Material price benchmarks.
- 17+ Verified junkshop records.

---

## Applied CS Principles

- **Separation of Concerns**: UI, Business Logic, and Data Access are strictly isolated.
- **Immutability**: App state is managed using immutable data classes and `copyWith` patterns.
- **Dependency Inversion**: Repositories are injected via Riverpod providers, allowing for easy mocking/testing.
- **Spatial Optimization**: Uses GIST (Generalized Search Tree) indexing for sub-millisecond proximity queries.
- **Relational Integrity**: Foreign key constraints and Postgres triggers enforce business rules at the database level.

---

## Possible Presentation Questions

**Q: Why use PostGIS instead of standard latitude/longitude filtering?**  
**A:** PostGIS provides highly optimized spatial indexing (GIST). It allows us to compute accurate geographic distances and perform complex bounding-box queries directly at the database level. This is significantly faster and more scalable than computing distances client-side or using raw math formulas in SQL.

**Q: How do you ensure data security and prevent unauthorized edits?**  
**A:** We use Supabase Auth for session management (JWTs) and enforce **Row Level Security (RLS)** at the database level. RLS policies ensure that users can only UPDATE or DELETE records where `owner_id = auth.uid()`. This makes it impossible for users to tamper with other shops' data, even via direct API calls.

**Q: How does the system prevent fake junkshop registrations?**  
**A:** The registration workflow incorporates strict validation rules:
1. **Camera-Only Capture**: Requires a live storefront photo (disabling gallery uploads) to prove physical presence.
2. **Manual Validation**: All submissions start as `pending` and remain hidden from the public map until an Administrator approves them via the web dashboard.

**Q: Why separate the Admin Dashboard (Next.js) from the Mobile App (Flutter)?**  
**A:** Separation of concerns. Flutter is optimized for our mobile-first, highly interactive consumer map experience. The Admin Dashboard requires dense data tables, rapid data-entry flows, and seamless web integrations, where React/Next.js excels.

**Q: How do you handle complex database insertions (e.g., a shop with multiple materials)?**  
**A:** We use **Supabase RPC (Remote Procedure Calls)** to handle complex insertions atomically. The `insert_shop_with_materials` RPC inserts the shop record and all related `junkshop_materials` junction rows within a single PostgreSQL transaction. If any part fails, the entire operation rolls back, preventing orphaned data.

---

## Developer's Note

This project marks the evolution from a static prototype to a production-grade infrastructure. By leveraging Supabase's managed services (PostGIS, Auth, Realtime) alongside a fully normalized schema, we have built a system that is not only secure and performant but also ready for regional expansion beyond La Union.
