# corememz — Core Features

## Problem & Goal
People avoid cleaning up large photo libraries because reviewing everything
at once is overwhelming. Core Mems lets someone review a stream of media a
few at a time, make reversible keep/delete decisions, and confirm deletion
only at the end — without guilt-based framing.

Everywhere this doc says "photo," the same applies to videos, Live Photos,
timelapses, screenshots, and any other media type in the Photos library,
unless a feature is called out as photo- or video-specific.

## Session Setup
Selection modes, chosen at session start:
1. ✅ **Shuffle** — random from the whole library
2. ✅ **Most Recent** — newest first, working backward
3. ✅ **From a Date** — oldest-first from a chosen start date, e.g. a trip
4. **Review Screenshots** — a dedicated mode scoped to just screenshots

- ✅ Sessions are **open-ended**, not a fixed count — they run until the
  user stops.
- ✅ **Check-in interval** (default 12, adjustable 5–100 in Settings): every
  N items, a checkpoint overlay asks "keep going or stop here" so the
  session never feels endless. Decisions made so far are preserved either
  way.

## Review Interaction
One item at a time, full-screen, with drag-gesture swiping:
- ✅ Swipe/tap right → **Keep**
- ✅ Swipe/tap down → **Mark for deletion**
- ✅ Swipe left → **Quick undo** (reverses only the single most recent
  decision)

**Favorites & tagging**
- ✅ **Favorites**: heart-toggle on an item, carried through review, the
  Tray, Pending Review, and the delete confirmation (surfaced as "N of
  these are favorites").
- ✅ **Album tagging**: assign an item to a real Photos album (native
  `PHAssetCollection`) during review, from an inline quick-access strip
  (pinned + recent albums) or the full album sheet. The sheet's search
  field also creates a new album; albums are created in Photos when the
  session ends.
- ✅ **Pinned albums** (Settings): choose which albums show first in the
  strip and sheet; creating an album from Settings pins it automatically.
- **Smart folder suggestions**: auto-recommend a folder based on
  recency or visual similarity.

**In-flow editing**
- ✅ **Convert Live Photo to still photo**
- **Edit photos**: crop, adjust, etc. — saved as a new photo, retaining
  the original's metadata
- **Edit videos**: trim clip duration, saved as a new clip while
  deleting the original
- **Paste filter presets**
- **Show item in Photos app**: jump straight to it in Apple Photos

## Deletion Tray (mid-session)
- ✅ Persistent, always-reachable affordance showing a live count of items
  currently marked for deletion.
- ✅ Opens a multi-select grid of every pending-delete item from anywhere in
  the session (not just the most recent), letting the user restore several
  at once back to Keep.

## End-of-Session Review & Confirmation
- ✅ **Pending Review** screen: full-screen multi-select grid of everything
  marked for deletion, sharing the same underlying data as the in-session
  Tray. Zero pending deletions is a valid, normal outcome.
- ✅ Explicit **confirmation step** before any deletion; copy states plainly
  that deleted items move to **Recently Deleted** (Apple's standard ~30-day
  grace period), not permanent removal, and flags if any are favorites.
- ✅ **Completion screen**: neutral summary of kept/deleted counts, with
  the option to keep reviewing or stop for now.

## Lifetime Stats ("Your Core Mems")
- ✅ In-app-only fun stat, not a native Photos feature.
- ✅ Cumulative totals across sessions: items reviewed, kept, moved to
  Recently Deleted, sessions completed, kept-vs-deleted ratio bar.
- ✅ User can clear this history.

## Access & Inventory Edge States
- ✅ **Limited Photos access**: dismissible banner plus an entry point to
  grant broader access via Apple's native picker.
- ✅ **Empty library**: neutral "nothing to review yet" state.

## Critical Invariants
1. Apple Photos remains the source of truth.
2. Marking an item for deletion is not deletion — no Photos-library
   mutation happens until explicit final confirmation.
3. An item never appears twice as an active review item within one
   session.
4. Confirmed deletion goes through Apple's Recently Deleted mechanism; the
   app must never imply permanent deletion.