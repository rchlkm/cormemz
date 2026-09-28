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

## PhotoKit quirks

- `.shuffle` isn't PhotoKit-native. `AssetBatchSource` fetches in default order and shuffles its own index array instead of the assets.
- `.date` uses an exclusive ceiling, not an exact match, so a picked day means the whole day (`dateCeiling(for:)`).
- `neighborAssets` uses a separate, always-chronological cached fetch (`ChronologicalImages`), independent of the session's own shuffled/filtered order.
