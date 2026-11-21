# Changelog

## 2.3.0

- 在其他应用输入时，操作暂存面板会保留原输入焦点。
- 展开途中再次点击，可从当前位置收回。修复了显示桌面时收起画面停顿、变形的问题。

- 收起时，文字与图标随外框收拢进度同步淡出。

- Keep the expanded window level throughout collapse and lower it only after committing the capsule, avoiding a stale expanded surface during Show Desktop restoration.

- Add session mouse-button polling as a fallback for outside clicks consumed by Show Desktop, so returning to application windows dismisses the expanded island.

- Animate a fixed snapshot of the shelf content during window transitions, then restore live controls at completion, isolating text layers from desktop window restoration.

- Preserve content aspect ratio while following the animated panel, avoiding stretched text/icons during collapse and desktop window restoration.

- Prepare and rasterize visible rows at native display resolution during transitions so first-drop icon/text layers scale together.

- Keep content geometry locked to the actual animated panel bounds; fading no longer controls content movement.

- Animate the complete content between the capsule rectangle and its expanded layout, so it unfolds from and returns into the capsule.

- Gather content toward the capsule when closing and expand it outward when opening; request a display-synchronized 120 Hz animation cadence where supported.

- Automatically expand and show the current item count for five seconds when additions cross 50, 100 or 200 items; batch additions show one reminder and loading saved items does not trigger it.

- Replace Clear actions with Delete Selected; batch-remove only selected references, preserving external originals and existing owned-screenshot Trash behavior.


- Add a persistent capsule opacity setting (0–100%, retaining interaction when invisible) in all five languages; opening and closing animations and the expanded panel stay fully opaque black.

## 2.2.1

- 修复了已知的问题

- Prepare newly added rows and their first drawing before starting transitions, update empty/list visibility before sizing the viewport, clip row layers explicitly, and defer visible-row updates until viewport geometry is consistent.

- Settle content scaling and panel geometry before the final fade so text stays still at the end of expansion.

- Pace transitions with the display refresh using a coalescing display link, and use a damped geometry curve with a soft, non-bouncing finish.

- Add separate persistent expand/collapse animation duration sliders (0.10–1.50 seconds) in all five languages, preserving current default timing.

- Preserve hover protection over the capsule and expanded panel throughout animation, including screen-top edges.

- Keep the shelf viewport at its expanded size during transitions to avoid repeated row layout and thumbnail creation while resizing.

- Fade content concurrently with expansion using a soft easing curve; gently scale composited content from 96% to full size without laying out text again. Align window edges to display pixels and update content before drawing to reduce transition jitter.

- Open all shelf files in their default app on double-click; keep Finder reveal in the context menu.
- Preserve reference-only removal for ordinary files and Trash handling for owned screenshots.

- Keep narrow side gutters available for marquee selection when the list is full.
- Automatically scroll at the top and bottom edges during marquee selection, including while the pointer is stationary.
- Preserve file drag-out behavior and stop scrolling when the selection gesture ends.

## 2.2.0

- Automatically capture newly copied text and clipboard images with separate settings in all five languages.
- Show screenshot thumbnails and open saved screenshots directly on double-click.
- Move owned screenshots to Trash when removed or cleared; keep entries if trashing fails, and protect external originals.
- Show newest additions first and migrate existing saved order once.
- Virtualize the shelf list, reuse rows during window resizing, and bound long-text previews without truncating stored text.
- Consolidates the local 2.2.x development builds into the public 2.2.0 release.

## 2.1.5

- Center the primary drag preview on the pointer hotspot (arrow tip), removing the lower-right offset. Other behavior is unchanged.

## 2.1.4

- Anchor file and text drag previews next to the pointer, independent of where the row was grabbed.
- Use an opaque gray text card with dark marks and contrasting edges for visibility over light and dark destinations.
- Keep multi-item previews in a compact cursor-relative stack.

## 2.1.3

- Align the item count at the bottom-left. No other layout or behavior changes.

## 2.1.2

- Move the localized item count to the bottom of the expanded panel, above the drag hint, so the hardware notch cannot obscure it.
- Reserve separate space for the count, file list and drop confirmation.

## 2.1.1

First public release of Floatsland.

- Unified English branding across all five interface languages.
- Added persistent, immediately applied language selection.
- Black notch shelf with configurable geometry and negative vertical offsets.
- Multi-selection and file/text drag-and-drop.
- Outside-click dismissal and stable, non-moving drop confirmation.
