# Image alignment

Markdown block image — placed by the `ImageAlign` property, since `![]()` has
nowhere to carry an attribute:

![example](Images/example.png)

An `<img>` with no `align` follows the property too:

<img src="Images/example.png" width="120">

`align="center"` overrides the property for this image only:

<img src="Images/example.png" width="120" align="center">

`align="right"`:

<img src="Images/example.png" width="120" align="right">

`align="left"` pins it left even when the property says otherwise:

<img src="Images/example.png" width="120" align="left">

An image inside a line of prose is <img src="Images/example.png" width="40"
align="center"> never re-aligned — the align attribute applies only when the
image is the whole paragraph, so this sentence stays left-aligned.
