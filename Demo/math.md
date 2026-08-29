# Math rendering

The rendering corpus for LaTeX math. It deliberately carries the awkward cases
(currency, escapes, code spans) alongside the formulas — those are where the
`$` delimiter goes wrong.

Open it with the math engine deployed to see typeset formulas, and without it
to see the fallback: every formula renders as its literal LaTeX source.

## Inline

Inline math sits on the text baseline: the roots of $ax^2+bx+c=0$ are given by
the quadratic formula, and $e^{i\pi} + 1 = 0$ is Euler's identity. Greek and
subscripts flow with the text — $\alpha$, $\beta_0$, $\Delta G^\circ$,
$\hbar\omega$ — as do relations like $x \le y \ne z$ and $A \subseteq B$.

## Display

A `$$` block, centred on its own line:

$$
\frac{-b \pm \sqrt{b^2-4ac}}{2a}
$$

The same thing as a fenced block, which is how GitHub spells it:

```math
\sum_{i=1}^{n} i = \frac{n(n+1)}{2}
```

Display style inside a paragraph: an integral, $$\int_0^\infty e^{-x^2}\,dx =
\frac{\sqrt{\pi}}{2}$$ set right in the flow.

## Structures

A matrix:

$$
\begin{pmatrix}
a & b \\
c & d
\end{pmatrix}
\begin{pmatrix} x \\ y \end{pmatrix}
=
\begin{pmatrix} ax + by \\ cx + dy \end{pmatrix}
$$

A system of equations, aligned on the relation:

$$
\begin{aligned}
\frac{dS}{dt} &= -k_1 S E + k_2 C \\
\frac{dC}{dt} &= k_1 S E - (k_2 + k_3) C \\
\frac{dP}{dt} &= k_3 C
\end{aligned}
$$

A case split:

$$
f(x) = \begin{cases}
  x^2 & \text{if } x \ge 0 \\
  -x^2 & \text{otherwise}
\end{cases}
$$

Stretchy delimiters and limits:

$$
\lim_{n \to \infty} \left( 1 + \frac{1}{n} \right)^{n} = e
\qquad
\prod_{k=1}^{n} k = n!
$$

## Kinetics

Michaelis-Menten: $v = \frac{V_{max}[S]}{K_M + [S]}$, where $K_M$ is the
substrate concentration at half-maximal rate. In display form:

$$
v = \frac{V_{max}\,[S]}{K_M + [S]}
\qquad\text{and}\qquad
v = \frac{V_{max}\,[S]^h}{K_{0.5}^h + [S]^h}
$$

the second being the Hill equation with coefficient $h$.

Chemistry, via mhchem:

$$
\ce{H2SO4 + 2NaOH -> Na2SO4 + 2H2O}
$$

$$
\ce{E + S <=>[k_1][k_2] ES ->[k_3] E + P}
$$

## Not math

None of this is a formula, and all of it must survive intact:

Currency — it costs $5 and $10, or US$100 and CA$200 if you prefer. An escaped
\$x\$ stays literal, and `$x^2$` inside a code span stays code.

A `$$` block is only math when it is closed, so a lone `$$` in prose is just
two dollar signs.

## Mixed with everything else

- A list item with inline math: the decay constant $\lambda = \ln 2 / t_{1/2}$
- Another, with a fraction: $\frac{\partial u}{\partial t} = \alpha \nabla^2 u$

> A quote containing math: the Gaussian $e^{-x^2/2\sigma^2}$ normalises to
> $\frac{1}{\sigma\sqrt{2\pi}}$.

| Quantity | Symbol | Relation |
| :--- | :---: | :--- |
| Rate constant | $k_1$ | $v = k_1 [S]$ |
| Half life | $t_{1/2}$ | $t_{1/2} = \ln 2 / \lambda$ |
| Price | — | $2.50 |

Math also works in a **heading**, as in $\Delta G = \Delta H - T\Delta S$ below.

### $\Delta G = \Delta H - T\Delta S$

That heading is typeset too.
