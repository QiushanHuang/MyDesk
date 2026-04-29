# Home, Pinned, And Canvas Interaction Fixes Design

## Goal

Fix the interaction gaps reported after the Global Library and canvas frame update, with a narrow focus on Home resource actions, Pinned sidebar behavior, resource preview pages, canvas connection reliability, organization frame usability, immediate selection feedback, and directional workflow animation.

## Scope

- Home pinned resource cards must expose the same everyday file/folder actions as the resource lists: details, Finder open/reveal, copy full path, and context-menu actions.
- Pinned sidebar resource rows must support double-click Finder routing and copy-path actions. Folder rows open Finder; file rows reveal in Finder.
- Selecting a pinned folder or file in the sidebar must show a useful resource page instead of a one-row table. Folders show a first-level directory browser. Files show a Quick Look-style preview when possible and metadata/actions when preview is unavailable.
- Clicking the Pinned Folders or Pinned Files section label must open the matching list page directly.
- Canvas linking must work reliably through both Connect mode and the per-card link button.
- Organization Frames must stay visible, selectable, draggable, connectable, and able to move contained child cards.
- Single-click selection must show the blue selected border immediately. Double-click open must not delay single-click selection feedback.
- Directional blue animation must move along connected edges from source to target. Unconnected cards must not glow.

## Design

### Shared Resource Actions

Introduce one shared `ResourceActionHandlers` pattern at the view layer: open/reveal/copy/inspect/rename/pin/remove are passed down as closures, so Home, sidebar, pinned pages, and list rows use the same Finder routing and status feedback. Finder routing remains centralized in `ResourceFinderRouting`: folders open, files reveal.

### Home

Replace the generic dashboard card for pinned resources with a `HomeResourceCard`. It keeps the dashboard layout but adds small icon buttons for Finder, copy path, and details, plus a context menu. Single-click selects/shows details. Double-click opens/reveals in Finder.

### Pinned Sidebar And Resource Detail

Pinned section labels use a tappable label/button surface that changes selection to `.pinnedFolders` or `.pinnedFiles`. Sidebar resource rows get an explicit double-click gesture and context menu actions.

The `.resource(id)` detail route becomes `ResourcePreviewView`:

- Folder target: show folder metadata, actions, and a first-level directory listing with names, type icons, sizes when available, and double-click Finder routing.
- File target: show metadata/actions and a Quick Look preview using AppKit `QLPreviewView` when possible. If preview fails, show a stable fallback panel with path, status, and note.

No real Finder delete/rename/move is introduced.

### Canvas

Remove the single-tap/double-tap conflict by handling card interactions through an explicit click gesture that selects immediately, and separately handling double-click open without waiting to show selection. Card link buttons must not be canceled by the card tap handler.

Frames render above the background and below cards, with a positive hit-test surface and a lower visual z-index than cards. They remain draggable and connectable. Dragging a frame keeps the existing containment-based child movement.

Edges render as directed arrows. Blue workflow animation is drawn on the edge path itself as a small moving highlight from source to target. Cards do not glow simply because they are connected.

## Performance

Selection and link state changes are local `@State` updates and must not wait for SwiftData saves. Canvas pan, zoom, and node drag continue to use transient state during gestures and write SwiftData only on gesture end. Edge animation uses a canvas-level pulse rather than one animation per card.

## Tests

Core tests cover resource Finder routing, edge direction identity, frame child movement, and drop placement. New tests will add small pure-logic coverage for folder-list sorting/preview metadata where practical. UI-heavy behavior will be verified by build/run and targeted manual inspection paths.
