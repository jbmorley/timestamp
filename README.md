timestamp
=========

Render an analog clock showing the EXIF timestamp into an image.

Examples
--------

![Large Clock](graphics/timestamp.jpg)

Usage
-----

```
usage: render-time [-radius RADIUS] [-centerX CENTERX] [-centerY CENTERY] image1 [image2 ...]

Render an analog clock showing the EXIF timestamp into an image.

optional arguments:
 -radius RADIUS       Radius of the clock
  -centerX CENTERX     The x-coordinate of the center of the clock
  -centerY CENTERY     The y-coordinate of the center of the clock
```

Limitations
-----------
- Meta-data is not transferred to the new file.