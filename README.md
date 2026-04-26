# ReframePhoto
A lossless photo editor component for iOS.

The idea is to build a reusable component that can be used in any application to provide lossless photo editing; if the app remembers the source photo and `LosslessEdits`, it can reproduce the final image.

This is being built in public and is not yet ready for any real use.

Use:

* Use is not recommended right now, as this component is in its early stages. However, it's being distributed under the MIT license.

Features (current):

* Cropping.
* Tilting.
* Zooming.
* Brightness & contrast.
* Color saturation.
* Cropping to common fixed aspect ratios.
* Color hue shift / whitepoint adjustment.
* Persisting aspect ratio.

Features (1.0):

* Complete?

Features (future):

* Skewing.
* Other easy Core Image filters?

Issues:

* Device rotation doesn't rotate crop well.
* Many others.
