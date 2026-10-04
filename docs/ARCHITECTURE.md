# Architecture

## Nothing writes until you confirm

Every keep/delete/convert/album decision and every edit stays in memory until confirm.

```
 swiping a session     hit confirm
 ─────────────────     ───────────

 ┌────────────┐        ┌──────────────┐
 │    deck    │        │ AlbumStaging │
 │ deletions  │        │  additions   │
 │ conversions│        │  removals    │
 │ edits      │        └──────┬───────┘
 └─────┬──────┘               │
       │                      │
       └──────────┬───────────┘
                  v
       SessionChangePlan           combines deck + staging,
                  │                drops album changes on photos
                  v                being deleted
       SessionLibraryChanges       one struct, no PhotoKit calls
                  │
                  v
       SessionViewModel.applyChanges()
```

## The two staging piles

- deck: pending deletions, pending Live Photo conversions, staged edits
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

`SessionChangePlan` combines both piles into `Services/PhotoLibraryServicing.swift`:

```swift
struct SessionLibraryChanges {
  var deletions: [PHAsset] = []
  var conversions: [String: PHAsset] = [:]        // keyed by session photo ID
  var albumAdditions: [String: Set<AlbumRef>] = [:]
  var albumRemovals: [String: Set<String>] = [:]
  var albumAssets: [String: PHAsset] = [:]
  var edits: [String: AssetEdit] = [:]            // keyed by session photo ID
}
```

Plain data. No PhotoKit calls in it.

## Committing it

```
 SessionViewModel.applyChanges()
          │
          v
 SessionApplyService.apply(_:)     measure storage size before deleting
          │                        (a deleted asset can't report its size)
          v
 PhotoLibraryService+Apply.swift   the only file that talks to PhotoKit
          │
          v
 PHPhotoLibrary.shared().performChanges {
   1. create a new asset (AssetReplacement) for each converted Live Photo
      still and each trimmed video clip
   2. attach each rotation's rendered output to its asset in place
   3. add/remove album memberships, creating any new albums; a new
      asset joins the albums its original was in
   4. delete originals — swiped deletions, originals of converted stills,
      and originals of trimmed clips unless Delete original is off
 }
          │
          v
 SessionLibraryResult              new asset/album IDs, freed bytes,
          │                        failed edits, any albums that
          v                        vanished mid-session
 completion-screen stats
```

Still data for a converted Live Photo gets downloaded and each edit gets rendered before the transaction opens — `performChanges` runs synchronously, nothing async is allowed inside it.

`performChanges` is atomic. All or nothing, for everything that made it in.

## Editing

```
 full-screen editor ── Done ──> SessionViewModel.saveEdit
 draft MediaEdit                  │  SessionPhoto.edit = edit (not a decision)
                                  │  MediaEditRenderer starts rendering
                                  v
                          Apply waits for the render, or retries once
```

`MediaEdit` holds quarter turns, an optional trim range, and whether the original is deleted. It is Codable, and is also written into the Photos adjustment data.

- An edit sits beside the decision, not in it. Editing a photo marked for deletion or conversion makes it a Keep, and `activeEdit` is `nil` while a photo is marked, so a marked photo never writes one.
- `MediaEditRenderer` keeps each asset's latest render and replaces it when the edit changes. Starting a render on Done means Apply only writes the result.
- Rotating a photo, video or Live Photo renders a `PHContentEditingOutput` that is written onto the asset. It builds on the asset's current look, so a Revert in Photos restores the original.
- Trimming exports the kept range into a temporary file, passthrough with no re-encode. That file is saved as a new clip through `AssetReplacement`, which carries over the date, location, favorite flag and albums. Slo-mo videos can't be trimmed because their time mapping wouldn't survive.
- A render that fails is retried once, then left out of the transaction and reported in `SessionLibraryResult.failedEdits` with an `EditFailureReason`. It never blocks deletions or other edits.
- `SessionViewModel.failedEdits` holds the `FailedEdit`s for the completion screen. Retry runs a second transaction with only those edits; discard drops one and leaves its photo as it is. Failed edits are not saved across launches.
- Edits are counted on their own in session and lifetime stats (`mediaEdited`), including edits that succeed on a retry. Trimmed clips are added to the kept history so later sessions skip them. When a trim deletes its original, the original's size minus the clip's counts as space cleaned (`bytesSavedByTrimming`); rotating frees none.

## Live Photo editing limits

Edits to a Live Photo are written in place through `PHLivePhotoEditingContext`, which only transforms each frame's image. That covers rotate, and nothing that changes which frames exist or which one is the still:

- `photoTime` (the key photo's moment) and `duration` are read-only, so the key photo can't be changed in place.
- The `frameProcessor` can't drop frames or shorten the video, so a Live Photo can't be trimmed in place. Blanking or freezing frames would leave its length unchanged.
- Photos does both with private APIs.

Changing the key photo or trimming would mean saving a new Live Photo through `PHAssetCreationRequest`, the way a trimmed video is saved as a new clip: re-render the still from a frame, rewrite the paired video's still-image-time, and optionally delete the original. The still would be re-encoded from a video frame, so it loses the original's HDR and depth data.

Frames can still be viewed: `LivePhotoFrames` reads the paired video resource, and the full-screen scrubber shows any frame without staging an edit.
