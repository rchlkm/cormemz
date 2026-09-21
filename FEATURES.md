# Core Mems — Features

The full feature list, plus what's planned. For the overview, see
[README.md](README.md).

Everywhere this doc says "photo," the same applies to videos, Live Photos,
timelapses, screenshots, and any other media type in the Photos library,
unless a feature is called out as photo- or video-specific.

## Features

### Session Setup

**Selection modes**, chosen at session start:

1. **Shuffle** — random from the whole library
2. **Most Recent** — newest first, working backward
3. **From a Date** — oldest-first from a chosen start date, e.g. a trip

**How sessions run**

- Sessions run until you stop, with a periodic check-in
- Photos you've already kept are skipped in later sessions

### Settings

- Set check-in frequency
- Include or reset reviewed photos
- Choose pinned albums
- View lifetime stats

### Review Interaction

One photo at a time, full-screen, decided with a swipe or the buttons below it.

**Gestures**

- Swipe right → Keep
- Swipe down → Mark for deletion
- Swipe left → Quick undo (reverses only the most recent decision)
- Swipe up → Details (photo metadata)

**Along the way**

- Favorite a photo
- File a photo into a Photos album, including a new one, with pinned albums shown first
- Pin or unpin an album without leaving the review
- Mark a Live Photo for conversion to a still photo
- Undo back onto a photo marked for conversion keeps it marked, so you can file the still into an album or change your mind
- Open the marked-photos tray to see everything marked for deletion or conversion and restore items to Keep
- Open a marked photo full screen to undo its mark, from the tray or the final review

### End-of-Session Review & Confirmation

- Review everything marked for deletion or conversion before confirming, and filter or swipe between All, Delete, and Convert
- Deleted photos move to Recently Deleted, and favorites are flagged before you confirm
- See a summary of what was kept and deleted
- See how much of your library you've reviewed, here and in lifetime stats

### Lifetime Stats

- "Your core memories"
- Running totals across sessions: reviewed, kept, deleted, sessions completed
- Live Photos converted to stills
- Storage cleaned, split between deleted photos and Live Photo conversions
- Kept-vs-deleted ratio bar
- Clear lifetime stats, which resets the totals and the tracking date

### Access & Inventory Edge States

- Prompt to share more photos when access is limited
- Friendly message when the library is empty

---

## Planned

### Session Setup

- **Review Screenshots** — a dedicated selection mode scoped to just screenshots

### Review Interaction

- **Smart folder suggestions** — auto-recommend a folder based on recency or visual similarity
- **Edit photos** — crop, adjust, etc., saved as a new photo that retains the original's metadata
- **Edit videos** — trim clip duration, saved as a new clip while deleting the original
- **Paste filter presets**
- ~~**Show item in Photos app** — jump straight to it in Apple Photos~~ — PhotoKit does not support this
