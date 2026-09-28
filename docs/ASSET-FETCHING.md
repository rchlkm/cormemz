# Asset fetching

Loads photos in batches instead of fetching the whole library.

## The pipeline

```
 SelectionMode (shuffle / recent / date)
          │
          v
 PHFetchOptions              predicate: mediaType == image
 (PhotoLibraryService)       sort: creationDate, if not shuffling
          │                  .date adds a creationDate < ceiling filter
          v
 PHFetchResult<PHAsset>      the full matching set, a lazy handle,
                             not materialized assets
          │
          v
 AssetBatchSource (actor)    an index order into the fetch result,
                             shuffled or not
          │
          v
 nextBatch(count:)           walks the order, skips `excluding`,
                             returns up to `count` PHAssets
          │
          v
 registerPhotos              PHAssets -> SessionPhoto cards
```

`AssetBatchSource` (`Services/AssetBatchSource.swift`) is the only thing that walks the fetch result, one batch at a time. It's an actor because batches get pulled off the main thread and the cursor isn't safe otherwise.

## Batching and lookahead

`startSession` loads `lookaheadBatches * batchSize` photos up front, tops up as you swipe:

```
 deck:  [■ ■ ■ ■ ■ ■ □ □ □ □ □ □ □ □ □ □ □ □]
         ▲ reviewed  ▲ still to review
                      │
                      loadMoreIfNeeded() fires once this drops below
                      lookaheadBatches * batchSize, pulls one more
                      batch from the same AssetBatchSource
```

Same source for the whole session. Cursor continues from wherever the last batch left off.

## Skipping already-reviewed photos

Sessions exclude photos kept in earlier sessions (`ReviewedPhotosStore`), passed as `excluding`. One fallback so an all-reviewed library doesn't dead-end into an empty session:

```
 makeAssetSource(excluding: reviewed) -> nextBatch
          │
    empty, but library has eligible photos?
          │
          v
 makeAssetSource(excluding: []) -> nextBatch   (show reviewed photos again)
```

## Skipping photos that need a download

When downloads aren't allowed (offline, Low Data Mode, or the `.downloadedOnly` policy),
`makeAssetSource` wraps the base `AssetBatchSource` in `FilteringAssetSource`
(`Services/AssetBatchSource.swift`):

```
 AssetBatchSource.nextBatch   ->   FilteringAssetSource.nextBatch
 (unfiltered session order)        probes each candidate, keeps only what's
                                    displayable locally, refills from the base
                                    source until `count` is met or it's exhausted
```

A photo counts as "downloaded" if PhotoKit can produce an image for it with
`isNetworkAccessAllowed = false` (`probeDisplayable` in `PhotoLibraryService`). A cached
preview counts, not just a full-resolution original, so Low Data Mode shows a photo at
reduced quality instead of skipping it. When `networkAccess.allowsDownloads` is true,
every candidate is admitted and no probing happens.

Rejected photos aren't lost — they're left out of the current session's deck, the same
way `excluding` leaves out already-reviewed photos, and can surface (and get re-probed)
in a later session.

### Mid-session drops

If network access changes mid-session and downloads become disallowed,
`SessionViewModel.dropPhotosNeedingDownloadAhead()` re-probes every *undecided* photo
ahead of the current card and removes the ones no longer displayable. Already-reviewed
cards are left alone; dropped photos stay unreviewed for a future session.

## PhotoKit quirks

- `.shuffle` isn't PhotoKit-native. `AssetBatchSource` fetches in default order and shuffles its own index array instead of the assets.
- `.date` uses an exclusive ceiling, not an exact match, so a picked day means the whole day (`dateCeiling(for:)`).
- `neighborAssets` uses a separate, always-chronological cached fetch (`ChronologicalImages`), independent of the session's own shuffled/filtered order.
