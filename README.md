# ReframePhoto
A lossless photo editor component for iOS.

The idea is to build a reusable component that can be used in any application to provide lossless photo editing; if the app remembers the source photo and `LosslessEdits`, it can reproduce the final image.

This is being built in public and is not yet ready for any real use.

Use:

* Use is not recommended right now, as this component is in its early stages. However, it's being distributed under the MIT license.

1.0 Goals:

* Cropping.
* Cropping to common fixed aspect ratios.
* Zooming.

Eventually:

* Brightness & contrast.
* Color saturation.
* Color hue shift.
* Skewing.

Issues:

* Device rotation doesn't rotate crop well.
* Demo should use same lossless edits.
* Crop should not allow more than one point per side to be out of limits.
* Structure of files does not support component, demo as separate pieces.
* Many others.
