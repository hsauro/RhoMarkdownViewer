# Block alignment containers

The GitHub idiom — a `<p align="center">` wrapping an image, all on one line:

<p align="center"><img src="Images/example.png" width="200"></p>

A multi-line `<div>` wrapping a markdown image:

<div align="center">

![example](Images/example.png)

</div>

Text centres too, not just images:

<div align="center">
This whole paragraph is centred by the container that encloses it, and it is
long enough to wrap so the alignment is visible on more than one line.
</div>

Right alignment:

<p align="right">Pushed to the right margin.</p>

A container can hold several blocks:

<div align="center">

## A centred heading

![example](Images/example.png)

And a centred paragraph underneath.

</div>

A bare `<div>` with no align attribute is NOT a container — it stays literal,
which is the documented default for block HTML we do not interpret:

<div>
Still literal.
</div>

Back to ordinary left-aligned text.
