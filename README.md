# corememz

## Problem & Goal

People avoid cleaning up large photo libraries because reviewing everything
at once is overwhelming. Core Mems lets someone review a stream of media a
few at a time, make reversible keep/delete decisions, and confirm deletion
only at the end — without guilt-based framing.

## Ground rules

1. Apple Photos remains the source of truth.
2. Marking an item for deletion is not deletion — no Photos-library
   mutation happens until explicit final confirmation.
3. An item never appears twice as an active review item within one
   session.
4. Confirmed deletion goes through Apple's Recently Deleted mechanism; the
   app must never imply permanent deletion.

## What it does

- **Review a few at a time**: shuffle, most recent, or from a date. Sessions
  run until you stop, with a periodic check-in.
- **Keep or mark for deletion** with a swipe, with a way back. Nothing is
  deleted until you confirm at the end.
- **Favorites and albums**: heart a photo or file it into a Photos album as
  you go, with pinned albums for the ones you use most.
- **Live Photos**: convert a Live Photo to a still.
- **Marked-photos tray and final review**: see and restore everything marked
  for deletion or conversion before confirming.
- **Skips what you've reviewed**, so each session picks up where the last
  one left off.
- **Settings and lifetime stats**: check-in frequency, reviewed photos,
  pinned albums, and running totals across sessions.

See [FEATURES.md](FEATURES.md) for the full feature list and what's planned.
