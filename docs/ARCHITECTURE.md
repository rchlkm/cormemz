# Architecture

## Nothing writes until you confirm

Every keep/delete/convert/album decision stays in memory until confirm.

```
 swiping a session     hit confirm
 ─────────────────     ───────────

 ┌────────────┐        ┌──────────────┐
 │    deck    │        │ AlbumStaging │
 │ deletions  │        │  additions   │
 │ conversions│        │  removals    │
 └─────┬──────┘        └──────┬───────┘
       │                      │
       └──────────┬───────────┘
                  v
       SessionConfirmationPlan     combines deck + staging,
                  │                drops album edits on photos
                  v                being deleted
       SessionLibraryChanges       one struct, no PhotoKit calls
                  │
                  v
       SessionViewModel.commit(_:)
```

## The two staging piles

- deck: pending deletions, pending Live Photo conversions
- `Models/AlbumStaging.swift`: diffs against the album membership loaded at session start

```
 initial membership   staged this session   effective (what you see)
 ───────────────────  ────────────────────  ─────────────────────────
 { Trips, Family }  +  add Favorites       = { Trips, Family, Favorites }
                    -  remove Trips
 add X then remove X = staged nothing
```

Only the net diff is kept. Toggle an album on then off and nothing gets staged for it.

## The changes struct

`SessionConfirmationPlan` combines both piles into `Services/PhotoLibraryServicing.swift`:

```swift
struct SessionLibraryChanges {
  var deletions: [PHAsset] = []
  var conversions: [String: PHAsset] = [:]        // keyed by session photo ID
  var albumAdditions: [String: Set<AlbumRef>] = [:]
  var albumRemovals: [String: Set<String>] = [:]
  var albumAssets: [String: PHAsset] = [:]
}
```

Plain data. No PhotoKit calls in it.

## Committing it

```
 SessionViewModel.commit(_:)
          │
          v
 SessionCommitService.commit(_:)   measure storage size before deleting
          │                        (a deleted asset can't report its size)
          v
 PhotoLibraryService+Commit.swift  the only file that talks to PhotoKit
          │
          v
 PHPhotoLibrary.shared().performChanges {
   1. create a still copy of each converted Live Photo
   2. add/remove album memberships, creating any new albums
   3. delete originals — swiped deletions + originals of converted stills
 }
          │
          v
 SessionLibraryResult              new asset/album IDs, freed bytes,
          │                        any albums that vanished mid-session
          v
 completion-screen stats
```

Still data for a converted Live Photo gets downloaded before the transaction opens — `performChanges` runs synchronously, nothing async is allowed inside it.

`performChanges` is atomic. All or nothing.

## Live Photo editing limits

Edits to a Live Photo are written in place through `PHLivePhotoEditingContext`, which only transforms each frame's image. That covers rotate, and nothing that changes which frames exist or which one is the still:

- `photoTime` (the key photo's moment) and `duration` are read-only, so the key photo can't be changed in place.
- The `frameProcessor` can't drop frames or shorten the video, so a Live Photo can't be trimmed in place. Blanking or freezing frames would leave its length unchanged.
- Photos does both with private APIs.

Changing the key photo or trimming would mean saving a new Live Photo through `PHAssetCreationRequest`, the way a trimmed video is saved as a new clip: re-render the still from a frame, rewrite the paired video's still-image-time, and optionally delete the original. The still would be re-encoded from a video frame, so it loses the original's HDR and depth data.

Frames can still be viewed: `LivePhotoFrames` reads the paired video resource, and the full-screen scrubber shows any frame without staging an edit.
