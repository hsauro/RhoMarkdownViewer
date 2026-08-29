

## 18. Milestones

Each ends with something runnable and testable. **Status is as of 2026-08-25.**

Where a milestone was met by different work from the one planned, the row says so rather
than being quietly rewritten: the difference between what was designed and what the code
demanded is the useful part of a plan afterwards.

| # | Status | Milestone | Done when |
| :-- | :-- | :---- | :---- |
| **M0** | **done** | Migrate Iridium to `..\..\libAntimonyAPI\uAntimonyAPI.pas` (§5.1) | Iridium builds and runs on the new wrapper; load, simulate and SBML import unchanged |
| **M1** | **done** | Sibling project skeleton, `RateLaw.Types`, `IModelSource`, console harness | The harness builds and runs against a hand-built fixture model source |
| **M2** | **done** | Parser, AST, canonicaliser, stable AST printer | Algebraically-equivalent pairs canonicalise identically; non-equivalent do not |
| **M3** | **part** | Registry: JSON schema, built-in/user/project layers, load, validate, self-validation | Round-trips a registry; rejects a self-inconsistent RLD with a clear error |
| **M4** | **done** | MM and Hill entries; role binding | A correct MM model binds `Vm`/`Km`/`S` and reports nothing |
| **M5** | **done** | Static engine v1 — `S003`–`S008`, `S011`, `S014` | `Vm*S/(Km + Km)` caught as `S004` with the right fix; the Hill equivalent caught with **no Hill-specific code** |
| **M6** | | Iridium's `IModelSource` adapter; §10.3 model-level checks | A real model in Iridium reaches the engine and reports findings |
| **M7** | | Association — annotation, applicability, inference, `S001`/`S002`/`S013` | An unannotated model associates correctly; a deliberately ambiguous case reports `S002` rather than guessing |
| **M8** | **part** | User-function inlining and assignment-rule resolution (§8.2 rules 6–7) | A model that factors its rate law into `function MM(...) end` reports the same findings as the inline form |
| **M9** | **part** | Mutation-testing harness | Coverage report runs over the whole registry; every mutation class detected for both laws |
| **M10** | | UI (§14) — button, report, settings dialog, registry editor | `btnModelChecker` produces a readable report on a real model |
| **M11** | | Generative laws — indexed product/sum, mass action, symbolic stoichiometry | One entry checks first-, second- and third-order reactions |
| **M12** | | Dynamic Layer 1 — evaluator, sampling, invariants, `D001`–`D005`, `D007`, witnesses | A law with half-max at the wrong point is caught by `D005` **alone**, with the static engine silent |
| **M13** | | Dynamic Layer 2 — `D006` | A near-equal-in-regime defect is caught, with the domain point where it diverges |
| **M14** | | Registry expansion — reversible MM, competitive/uncompetitive/non-competitive inhibition, convenience kinetics | All pass self-validation and mutation tests, **with zero new law-specific code** |
| **M15** | | Documentation — RLD authoring guide, defect code reference, worked walkthrough | Someone else in the lab can add a rate law without reading the source |
| **M16** | | *Stretch:* Layer 3 simulation checks, `D101`–`D106` | A defect with no dynamic consequence is reported as `D106`, not a bare error |
| **M17** | | *Stretch:* BioModels corpus evaluation | A quantified false-positive figure and a triage list of causes |

Only M0, M6 and M10 touch Iridium; everything else is library work with its own tests.
M0 is done, so nothing in Iridium has changed since.

