# Media Swipe — Product Requirements & Constitution

## 1. Product Definition

Media Swipe is a minimal, local-first Android application for quickly reviewing and cleaning photos and videos.

The core interaction is intentionally simple:

- Swipe left → Delete the current media item.
- Swipe right → Keep the current media item.
- Tap the Delete button → Delete.
- Tap the Keep button → Keep.

The application must feel immediate, smooth, and lightweight. The user should never feel that they are operating a file manager.

The primary product principle is:

> Open → Swipe → Swipe → Swipe → Done.

No accounts, cloud processing, social features, unnecessary onboarding, or complex navigation are part of the MVP.

---

## 2. Platform & Technology

- Platform: Android
- UI framework: Flutter
- Language: Dart
- Native Android code may be used through Flutter platform channels/plugins where Android's native media APIs provide better performance or capabilities.
- Architecture must remain clean, modular, testable, and maintainable.
- Avoid introducing dependencies unless they provide meaningful value.

Flutter is mandatory for the application UI and primary application layer.

---

## 3. Media Source & Performance

The application must use Android's indexed media APIs, preferably MediaStore, rather than repeatedly scanning raw filesystem storage.

### Requirements

- Query media through Android MediaStore/content URIs.
- Do not recursively scan the entire filesystem on every launch.
- Do not read or decode every media file before displaying the first card.
- Load metadata lazily.
- Load thumbnails/previews lazily.
- Use content URIs and system/media APIs wherever possible.
- Use efficient pagination rather than loading the entire media library into memory.
- Keep only the amount of data required for the current card and a very small look-ahead buffer.
- Avoid unnecessary full-resolution image decoding.
- Avoid loading full video files merely to display a preview.
- Database/cache layers should only be introduced when they solve a concrete performance or state-management problem.

The first card must appear as quickly as reasonably possible after the media query begins.

### Media Types

MVP supports:

- Images
- Videos

Video cards should use an optimized preview/thumbnail representing the beginning of the video. The implementation should prioritize responsiveness and low memory usage over high-fidelity video playback.

If a native/system thumbnail API can provide the preview efficiently, prefer it.

---

## 4. Ordering

Default media order:

> Newest media first.

Ordering should be based on the most useful Android MediaStore timestamp for the user's expected notion of recently added media. Prefer the timestamp representing when media was added/imported to the device when available, rather than blindly relying on filesystem modification time.

The exact Android field should be selected during implementation based on platform behavior and API level.

---

## 5. Sources / Folders

The user can review:

- All Media
- Photos
- Videos
- Device media folders/buckets exposed by Android
- Common folders/sources such as Downloads, Screenshots, Instagram, etc., when available through MediaStore.

Do not build an independent filesystem indexing system merely to reproduce Android's media organization.

Use MediaStore collections, buckets, relative paths, and other native metadata as appropriate.

The UI should expose source/folder selection through a minimal selector. It must not become a complex file browser.

Changing the selected source should update the media query efficiently rather than rescanning storage.

---

# 6. Main Screen

The main screen is the product.

It should contain:

1. A minimal source/filter selector.
2. The current media card in the center.
3. Optional subtle indication of the next card behind the current card.
4. Delete and Keep buttons at the bottom.

No unnecessary UI should compete with the media.

Conceptually:

        All Media ▾

              ┌─────────────────┐
              │                 │
              │                 │
              │      MEDIA      │
              │                 │
              │                 │
              └─────────────────┘

             Delete      Keep


The exact visual design is intentionally left to implementation, but it must remain minimal, modern, calm, and highly responsive.

---

## 7. Tutorial Card

The first card shown to a new user is always an interactive tutorial card.

Its purpose is to teach the two gestures without requiring a separate onboarding flow.

The card communicates:

- Swipe left = Delete
- Swipe right = Keep

The tutorial card itself behaves like the interaction it teaches.

- Swiping it left dismisses it.
- Swiping it right dismisses it.
- After dismissal, the first real media card appears.

Do not create a multi-screen onboarding sequence.

The tutorial should be understandable immediately and should not require explanatory dialogs.

---

# 8. Swipe Interaction

Swiping is the primary interaction.

### Left

Dragging the card toward the left should communicate that the media will be deleted.

When the gesture passes the configured dismissal threshold:

- Animate the card out to the left.
- Trigger deletion.
- Immediately advance to the next card.

### Right

Dragging the card toward the right communicates that the media will be kept.

When the gesture passes the configured dismissal threshold:

- Animate the card out to the right.
- Do not modify the media.
- Immediately advance to the next card.

### Gesture Requirements

- Gesture recognition must feel direct and physically connected to the user's finger.
- No unnecessary animation delay.
- No artificial loading transition between cards.
- The next card should already be prepared before the current card leaves.
- Swipe thresholds should be forgiving enough for fast use but resistant to accidental actions.

---

# 9. Action Buttons

Two buttons exist below the card:

- Delete
- Keep

They are alternative input methods for the same actions.

Delete button:
- Deletes the current media.
- Advances immediately.

Keep button:
- Keeps the current media.
- Advances immediately.

Buttons must never open confirmation dialogs during normal use.

The user should be able to process media entirely with taps if desired.

---

# 10. Delete Behavior

Delete means:

> Send the media item to the device's normal Android trash/recycle mechanism where supported.

The app must not permanently destroy files directly in the MVP unless Android's platform behavior requires that operation for a particular API level.

Use the appropriate Android MediaStore deletion/trash APIs.

The user remains able to recover deleted media through the device's supported trash/recycle behavior.

The application should not create its own duplicate trash folder.

No confirmation dialog should interrupt the swipe flow.

If Android requires user authorization/confirmation for a deletion operation on a particular API level, handle the platform requirement gracefully and only when necessary.

---

# 11. Deleted Media Tab

The application includes a separate Deleted section.

Its purpose is to provide a quick visual history of media that this application sent to the device trash.

The Deleted section is a grid/tile view.

Layout:

- Three columns on typical phone widths.
- Scrollable vertically.
- Each item is represented by a thumbnail tile.
- Videos should have a small, unobtrusive video indicator.
- The grid should be optimized for fast scrolling and lazy loading.

The user can tap a deleted item to inspect it and restore it when Android/platform permissions allow restoration.

Restoring means:

> Return the item from the device trash/recycle state using the appropriate Android MediaStore API.

The app must not duplicate or copy the media merely to implement restoration.

If the OS permanently removes an item from its trash before the app can restore it, the app must gracefully treat it as unavailable.

The Deleted section is not intended to become a full file manager.

---

# 12. Empty States

When there are no more media items in the selected source:

Show a minimal completion/empty state.

Example concept:

    You're done.

The exact copy is implementation-defined.

Do not add unnecessary illustrations, tutorials, statistics, or gamification.

The state must make it immediately clear that there are no more items to review.

---

# 13. UI/UX Principles

The most important UX requirement is perceived speed.

The application should feel:

- Instant
- Smooth
- Minimal
- Calm
- Predictable
- Responsive

### Animation

Animation should be used only where it improves physical feedback or orientation.

Good uses:

- Card following the finger.
- Card dismissal.
- Very subtle next-card reveal.
- Minimal state transitions.

Avoid:

- Long transitions.
- Decorative animations.
- Loading animations that could be avoided.
- Animated page transitions that slow down navigation.
- Excessive scaling, bouncing, particles, or effects.

The user should never wait for an animation to finish before being able to continue processing media.

---

# 14. Perceived Performance

Performance is a product requirement, not an implementation detail.

The app should:

- Show the first usable card quickly.
- Preload the next one or two thumbnails.
- Avoid blocking the UI isolate with media processing.
- Avoid unnecessary Dart-side image decoding.
- Avoid repeated queries for the same media.
- Use background/isolate/native processing where appropriate.
- Reuse image resources when possible.
- Avoid memory spikes from large images or videos.
- Keep scrolling in the Deleted grid smooth.
- Maintain responsive gestures even when media operations are occurring.

Deletion and advancement should feel like one continuous action.

If deletion itself takes time, the UI must advance optimistically where platform behavior makes this safe, while the underlying operation is handled asynchronously.

Errors must not freeze the swipe interface.

---

# 15. State Management

The app must maintain a clear distinction between:

### Media state

What the Android MediaStore currently reports.

### Review state

Which media items the current session has already processed.

### UI state

Current card, selected source, gesture state, and navigation state.

Do not persist large media objects in memory.

Represent media primarily through lightweight identifiers, content URIs, metadata, and thumbnail references.

The system must tolerate the media library changing externally while the app is open.

For example:

- A file may be deleted by another application.
- A file may be moved.
- A file may disappear from the MediaStore.
- A file may already be in trash.

These cases must fail gracefully and advance rather than crash the application.

---

# 16. Permissions

Request only permissions that are required.

Use Android's current media permission model appropriate to the device/API level.

The permission experience should be minimal and understandable.

Do not request unrelated permissions.

If permission is denied, show a concise state explaining that media access is required for the application to work.

---

# 17. Architecture

Recommended high-level separation:

    Flutter UI
        ↓
    Application / Domain layer
        ↓
    Media repository abstraction
        ↓
    Android MediaStore implementation

The Flutter application should not directly depend on Android-specific implementation details.

Create abstractions around:

- Media querying
- Thumbnail/preview retrieval
- Delete/trash
- Restore
- Source/folder discovery

Android-specific implementations should live behind these abstractions.

The architecture should allow testing domain/application logic without requiring an Android device.

---

# 18. Suggested Project Structure

Use a clean feature-oriented structure rather than organizing everything by widget type.

Example:

    lib/
      core/
        ...
      features/
        media_review/
          data/
          domain/
          presentation/
        deleted_media/
          data/
          domain/
          presentation/
        sources/
          data/
          domain/
          presentation/

The exact structure may differ if a better clean architecture is justified.

Do not over-engineer.

---

# 19. Error Handling

Errors must never leave the primary review flow stuck.

Examples:

- Thumbnail unavailable → show lightweight fallback and allow action.
- Media disappeared → skip it.
- Delete failed → inform the user minimally and keep the item available for retry.
- Restore failed → show a concise error.
- Permission changed → request/recover gracefully.

Do not show technical exceptions or stack traces to the user.

---

# 20. Accessibility

The swipe interaction is primary, but every action must also be accessible through buttons.

Buttons must have meaningful semantic labels.

The UI should remain usable with Android accessibility services.

Do not make color the only indicator of Delete vs Keep.

---

# 21. Non-Goals for MVP

Do NOT implement:

- Cloud storage
- User accounts
- Social features
- AI categorization
- Duplicate detection
- Automatic cleanup
- Face recognition
- Photo editing
- Video editing
- File copying/moving
- Custom trash storage
- Gamification
- Achievements
- Complex statistics
- Ads in the core interaction
- Complicated settings
- Full filesystem browsing

The product succeeds by doing one thing extremely well.

---

# 22. Core User Flow

First launch:

    Open app
       ↓
    Request required media permission
       ↓
    Tutorial Card
       ↓
    Swipe left/right
       ↓
    First real media card
       ↓
    Swipe / Tap
       ↓
    Next media
       ↓
    Repeat
       ↓
    No more media
       ↓
    Completion state


Deleted flow:

    Deleted tab
       ↓
    3-column media grid
       ↓
    Tap item
       ↓
    Preview/details
       ↓
    Restore
       ↓
    Item leaves Deleted view


---

# 23. Definition of Done

The MVP is complete when:

- The application builds and runs on Android.
- Flutter is used for the application UI.
- MediaStore/native Android APIs are used for media discovery.
- The app does not perform unnecessary full filesystem scans.
- The first media card appears quickly.
- Images and videos are displayed efficiently.
- The first card is an interactive tutorial.
- Left swipe deletes/trashes the media.
- Right swipe keeps the media untouched.
- Delete and Keep buttons perform the same actions as swipes.
- The next card is ready without noticeable delay.
- Media can be filtered by available sources/folders.
- Media is ordered newest first by the selected Android media timestamp.
- Deleted media appears in a 3-column scrollable grid where recoverable items can be restored.
- The app does not create a custom trash copy of files.
- Large media libraries do not cause excessive memory use.
- Missing/deleted media does not crash the app.
- The review interaction remains responsive during media operations.
- There are no unnecessary dialogs or onboarding screens.
- The UI feels fast and smooth on mid-range Android hardware.

---

# 24. Product Rule

Whenever there is a conflict between adding functionality and preserving the simplicity/speed of the core interaction:

> Prefer simplicity and speed.

The application should feel like a single gesture-based tool, not a media-management suite.
