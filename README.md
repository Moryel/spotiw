# spotiw

Pock widget for Spotify now playing display.

## Preview

![Spotiw screenshot](images/preview.png)

## Try the widget

Build the Pock bundle from the package root:

```sh
sh Scripts/package-pock-widget.sh
```

The installable widget is created at:

```text
.swiftpm/xcode/swiftpm-build/release/Spotiw.pock
```

Open Pock, choose the widget manager/install option, then drag `Spotiw.pock` into Pock.

## Notes

- Uses PockKit widget structure.
- Uses AppleScript to query Spotify current track.
- Includes a procedural equalizer animation.
