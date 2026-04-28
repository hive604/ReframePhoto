# ReframePhoto

A reusable **lossless photo editor component for iOS** built with SwiftUI.

ReframePhoto is designed for apps that want to offer photo editing without destroying the original image. Instead of modifying source pixels directly, edits are stored as lightweight data (`LosslessEdits`) that can be reapplied later to recreate the final result.

## Status

ReframePhoto is under active development and is not yet considered production-ready. APIs, behavior, and implementation details may change as the project evolves.

The project is being developed in public and released under the MIT License.

## Why ReframePhoto?

Many apps need simple photo editing features such as cropping, straightening, and image adjustments, but do not need a full photo management solution.

ReframePhoto aims to provide:

- A reusable SwiftUI editing component
- Non-destructive editing
- Lightweight persisted edit data
- Consistent preview and export rendering
- Easy integration into existing iOS apps

## How It Works

Instead of saving a rewritten image after each edit, ReframePhoto stores edit instructions separately.

If your app keeps:

- The original source image
- The associated `LosslessEdits`

…then it can regenerate the edited result at any time.

This enables:

- Re-editing later
- Smaller storage requirements
- Reliable previews
- Consistent exports
- Sync-friendly edit metadata

## Current Features

### Geometry

- Cropping
- Straightening / tilt rotation
- Zooming
- Cropping to common fixed aspect ratios
- Persisted aspect ratio selection

### Tone & Color

- Brightness
- Contrast
- Saturation
- Hue / white balance style adjustments

## Version 1.0 Goals

The initial stable release is expected to focus on:

- Polished crop workflow
- Reliable tilt + crop interaction
- Stable reusable editor API
- Consistent rendered export pipeline
- Persisted edit model
- Documentation and integration examples

## Future Ideas

Potential later features include:

- Perspective / skew correction
- Additional Core Image adjustments
- More advanced color controls
- Batch processing workflows
- macOS support

## Current Limitations

Known rough edges remain during active development, including crop behavior during device rotation and other in-progress areas.

## Example Use Case

* A seller picks a product photo before publishing an item.
* You let them:
   * straighten the image with tilt
   * crop to a required aspect ratio like 1:1 or 4:5
   * slightly raise exposure
   * adjust contrast, saturation, or sharpness
* You store the edits as Lossless​Edits, so:
   * the original upload stays untouched
   * the seller can reopen the editor and continue from the same edit state

That fits this library well because:
* the edit model is lightweight and codable
* crop/rotation/adjustments are all reversible
* different surfaces can render from the same saved edits:
   * listing thumbnail
   * detail page image
   * social share export

## License

MIT License

## Feedback

ReframePhoto is being built iteratively. Feedback, testing, and real-world integration ideas are valuable while the API is still taking shape.
