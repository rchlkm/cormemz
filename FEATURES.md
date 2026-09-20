# Core Mems — Features

The full feature list, plus what's planned. For the overview, see
[README.md](README.md).

Everywhere this doc says "photo," the same applies to videos, Live Photos,
timelapses, screenshots, and any other media type in the Photos library,
unless a feature is called out as photo- or video-specific.

## Features

### Session Setup

Three selection modes, chosen at session start:

1. **Shuffle** — random from the whole library
2. **Most Recent** — newest first, working backward
3. **From a Date** — oldest-first from a chosen start date, e.g. a trip

Protocols(?):

- Sessions run until you stop, with a periodic check-in
- Photos you've already kept are skipped in later sessions

### Settings

- Set check-in frequency
- Include or reset reviewed photos
- Choose pinned albums
- View lifetime stats

### Review Interaction

One photo at a time, full-screen, decided with a swipe or the buttons below it:

- Swipe right → **Keep**
- Swipe down → **Mark for deletion**
- Swipe left → **Quick undo** (reverses only the most recent decision)
- Swipe up → **Details** (photo metadata)

#### Favorites & tagging

- Favorite a photo
- File a photo into a Photos album, including a new one, with pinned albums shown first

#### In-flow editing

- Convert a Live Photo to a still photo

### Deletion Tray (mid-session)

- See everything marked for deletion and restore items to Keep

### End-of-Session Review & Confirmation

- Review everything marked for deletion before confirming
- Deleted photos move to Recently Deleted, and favorites are flagged before you confirm
- See a summary of what was kept and deleted

### Lifetime Stats ("Your Core Mems")

- Running totals across sessions: reviewed, kept, deleted, sessions completed

### Access & Inventory Edge States

- Prompt to share more photos when access is limited
- Friendly message when the library is empty

## Planned

### Session Setup

- **Review Screenshots** — a dedicated selection mode scoped to just
  screenshots.

### Review Interaction

#### Favorites & tagging

- **Smart folder suggestions**: auto-recommend a folder based on recency or
  visual similarity.

#### In-flow editing

- **Edit photos**: crop, adjust, etc. — saved as a new photo, retaining the
  original's metadata.
- **Edit videos**: trim clip duration, saved as a new clip while deleting
  the original.
- **Paste filter presets**
- **Show item in Photos app**: jump straight to it in Apple Photos.

### Lifetime Stats

- **Kept-vs-deleted ratio bar**.
- **Clear lifetime stats** from Settings.
