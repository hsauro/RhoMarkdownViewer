# REPORT — recovering the mechanism of the hidden system

## 1. Summary of the answer

The system is **two kinetically independent modules**, not one pathway.

**Module A** (handles E1-E12, fed by boundary IN1, discharging to boundary IN2)
is a branched linear pathway with one regulatory edge:

    IN1 --E1--> S1 <--E3--> S2 --E4--> S3 <--E7--> S5 <--E8--> S6 <--E9--> S7 <--E10--> S8 <--E11--> IN2
                 |                      |                       |
              E2 |                   E5 |                       +--- S7 INHIBITS the E4 step
                 v                      v
                S16 --E12--> sink      S4 --E6--> sink

**Module B** (handles E13-E19, strung between boundaries IN4 and IN3) is a
reversible chain carrying a small net flux:

    IN4 <--E19--> S9 <--E13--> S10 <--E15--> S11 <--E16--> S12 <--E17--> S13 <--E18--> IN3
                                                                           |
                                                                        E14 --> sink

## 2. Candidate mechanisms considered, and how each was eliminated

**"One long linear pathway through all 13 observables."** Killed by the very
first sweep: knocking E1 down to 0.25 drives every module-A species to between
0.05x and 0.37x of nominal while S12 and S13 stay at 0.79x and 0.82x — within
noise of unchanged. Knocking down IN1 gives the same split. No E13-E19 handle
moves a module-A species and no E1-E12 handle moves a module-B species.

**"S4 and S5 are successive links in the chain."** In all 23 knockdowns S3, S4
and S5 move together — except under E5 and E7. E5 knockdown LOWERS S4 (0.56x)
while RAISING S3, S5, S6, S7 and S8. A species cannot fall while everything it
supposedly feeds rises. The only consistent reading is that S3 is a hub and S4
is a drain branch (S3<->S4->sink) whose closure diverts flux back into the main
chain — which is what E6 knockdown shows in reverse (S4 up 3.95x, everything
else up too).

**"S5 is a dead-end branch off S3."** Tempting, because S5 tracks S3 almost
perfectly. Killed by E7 knockdown: S5 falls to 0.66x while S3 rises. A dead-end
branch sits at equilibrium with its partner, so its RATIO to S3 cannot depend on
the enzyme level. It changed, so S5 carries flux and is on the chain. E8
knockdown then places the chain step: S3, S4, S5 all rise ~2.3x while S6, S7, S8
fall to ~0.7x.

**"IN2 is an input."** Killed by its knockdown signature: the effect is largest
at the far end of the pathway (S8 0.46x) and decays monotonically upstream (S7
0.62, S6 0.71, S3 0.87, S1 0.86). An input acts at its point of entry. This
gradient is what you get when you remove a boundary PRODUCT and pull the
terminal reaction forward, so E11 is a reversible S8 <-> IN2 step. It also tells
me the terminal step is reversible, which nothing else in my data would have.

**"Module B is a chain ending in a sink, S10->S11->S12->S13->out."** The chain
and its direction are solid — knockout accumulation sets nest exactly ({S10},
then {S10,S11}, then {S10,S11,S12} for E15, E16, E17), and pulse-chase by
set_initial confirms direction (spiking S10 to 2.0 drives S12 to a peak of 0.83
and S13 to 0.61, against a matched control that peaks at 0.29 and 0.28). But the
*terminus* was wrong: E16 knockout leaves S12 and S13 dead flat at baseline for
the full time course, and E17 knockout leaves S13 flat for 200 time units. In a
chain ending in a sink, cutting it upstream must starve everything downstream.
The resolution is that the chain ends in a reversible exchange with a boundary
(IN3), which PINS S13 (and S12 through it) regardless of what happens upstream.
The clinching evidence: E15, E16 and E17 knockouts all drive the species above
the cut to the SAME values (S10 ~1.4-1.5, S11 ~1.6-1.75, S12 ~8.9) — a chain cut
between two buffering boundaries.

**"S10-S13 are dead-end buffers on a hidden backbone."** Killed by the
pulse-chase above: real precursor-product transfer, with the expected time
ordering (S12 peaks at t~0.5, S13 at t~1.0-1.5).

**"E13, E14, E19 have measurable effects."** I believed this for a while, because
their knockouts appeared to cut S10 and S11 by 3-5x. Retracted: S10 (0.011) and
S11 (0.006) sit at the 0.01 absolute noise floor, so those ratios are noise.
Knockout TIME COURSES for E13 and E19 are indistinguishable from control in
every species. This was my most expensive mistake in reasoning, though not in
budget.

**"The blocked-chain steady states reported by the lab are converged."** Also
wrong. The E17-knockout time course shows S12 at 1.72 and still climbing at
t=200 against a reported steady state of 8.95. Blocked states do converge, but
very slowly, and a short-horizon reading of one is misleading.

## 3. The regulatory edge

Claiming exactly one: **S7 inhibits the S2 -> S3 reaction (E4/J4)**.

The anomaly that started it: S2 does not track S3. E8 knockdown raises S3 to
2.34x and leaves S2 at 0.96x; E6 knockdown raises S3 to 3.25x and S2 to 1.81x;
E11 knockdown raises S3 only 1.27x but S2 to 1.72x. Across all the downstream
knockdowns S2 tracks S7, not its own product.

The experiment designed to settle it was a pair of knockouts, chosen because S6
rises under BOTH and S8 falls under BOTH, so only S7 changes sign between them:

| experiment | S6 | S7 | S8 | S2/S3 vs baseline |
|---|---|---|---|---|
| E9 knockout | 37.1x | **0.20x** | 0.25x | **0.20x** |
| E10 knockout | 5.4x | **6.87x** | 0.24x | **2.26x** |

An 11-fold swing in S2/S3 following a 34-fold swing in S7, in the right
direction, with S6 and S8 excluded by construction. I predicted S2 itself would
fall under the E9 knockout and it rose — I had forgotten that E9 knockout also
drives S3 up 8.6x, which pushes S2 up through the reverse of J4. The ratio is the
right statistic and it is unambiguous.

I claim **no other regulators.** No other substrate/product ratio in the sweep
departed from stoichiometric expectation by more than noise. Since a false
regulator costs as much as a missed one, I have not speculated beyond the one
edge the data forces.

## 4. Rate laws and how they were chosen

Default position, per the brief, is mass action; a saturating form was adopted
only where the data cannot be reproduced without one. Two arguments from data,
not from curve-fitting, force Michaelis-Menten:

- **The S16 drain (J12) is saturated.** E2 knockdown to 0.25 drops S16 to 0.10x
  of baseline. If that drain were first order, a 4x cut in its supply enzyme
  could drop the pool by at most 4x, for any choice of constants. A 10x drop
  requires a drain running near Vmax, which crashes the pool when supply falls.
- **The entry step (J1) is saturated in IN1.** In a mass-action entry, E1 and IN1
  multiply the same rate, so knocking either to 0.25 must give identical results.
  They do not: E1 gives S1 = 0.05x, IN1 gives S1 = 0.36x. Only a saturating
  dependence on IN1 separates them.

Beyond those, every reaction was tested by a greedy search that upgraded one law
at a time and kept the upgrade only if it bought a substantial improvement in
fit. Whatever the search did not accept stayed mass action, which is the form
the brief asks me to prefer when the data does not demand more parameters. The
final per-reaction assignment and my confidence in each are in uncertainty.json.

## 5. Experiments bought, and what each was for

| # | experiment | cost | what it was designed to distinguish |
|---|---|---|---|
| 1 | baseline steady state x3 | 9 | nominal state; empirical noise, which revealed S10/S11 are at the floor |
| 2 | knockdown E1..E19 at 0.25, steady state | 171 | the 19x13 response fingerprint: pathway order, branch points, module split |
| 3 | knockdown IN1..IN4 at 0.25, steady state | 36 | assign inputs to modules; found IN2 is a product, not an input |
| 4 | knockout E13..E19, steady state | 91 | module-B species are at the floor, so maximum displacement beat a weak repeat |
| 5 | baseline + E17-knockout time courses, t=200 | 42 | time scales; and whether blocked-chain steady states converge (they had not) |
| 6 | four set_initial pulse-chases, t=10 | 88 | precursor-product ordering in module B |
| 7 | short baseline time course, t=10 | 20 | the matched control I should have bought before #6 |
| 8 | knockout E13/E16/E19 time courses | 90 | whether S12 is fed through S11 (it is not) |
| 9 | knockout E9 and E10, steady state | 26 | identify the regulator: only S7 changes sign between them |
| 10 | validation set (see section 7) | 38 | test predictions on experiments never fitted |

Perturbation amplitude was a real choice. I used factor 0.25 rather than the
default 0.5 throughout the sweep — same cost, roughly twice the displacement
against the same 5% noise — and full knockouts wherever a species sat near the
floor, where no amount of replication of a weak perturbation would have helped.
Replication was bought only where it earned its keep: three baseline replicates
to calibrate the noise, and nowhere else, because every marginal effect I cared
about was better attacked with a stronger perturbation than a repeated weak one.

## 6. What remains non-identifiable

- **Which reaction each of E13, E14 and E19 catalyses.** All three knockouts are
  indistinguishable from control in every observable, in steady state and in time
  course. They are placed so that perturbing them changes nothing measurable,
  which is all the data says. Confidence 0.25-0.3.
- **S10 and S11 at the unperturbed steady state.** Both sit at the 0.01 noise
  floor (one baseline replicate returned a negative value for S10). Their
  baseline values carry roughly 100% relative uncertainty.
- **True irreversibility versus a small reverse constant** on J1, J6, J12, J14.
  Written irreversibly for parsimony; the data cannot separate the two claims.
- **Absolute levels of IN1..IN4.** Only relative scaling is observable, so all
  four are set to 1 and absorbed into rate constants.
- **Unmeasured species.** S9, S14 and S15 are absent from the observable list. I
  introduce only S9, and only because module B needs a reversible upstream
  boundary connection; S14 and S15 are not used.
- **Michaelis-Menten vs mass action on the steps the search left alone.** I never
  bought an enzyme titration series, the experiment that would separate them. For
  any of those steps, an MM law with Km well above the operating concentration is
  observationally equivalent to the mass-action law I fitted.
- **Parameter precision.** With cv=0.05 noise the individual rate constants are
  identified to roughly a factor of 1.5-2 at best, and the reverse constants of
  near-equilibrium steps much worse. Reporting more figures than that would be
  fitting noise.

## 7. Validation and stopping

See VALIDATION section appended below and the tail of DECISIONS.md for the
predictions written down BEFORE the validation experiments were bought, and the
comparison afterwards.

## 7. Validation, and the decision to stop

Three experiments were bought AFTER the model was complete, with the predictions
written into DECISIONS.md first, and none of them was used to choose any
structure.

**knockup E11 x3** (predicted / observed ratio to nominal):
S8 0.54 / 0.51, S7 0.67 / 0.61, S6 0.77 / 0.72, S2 0.84 / 0.73, S1 0.88 / 0.82,
S16 0.88 / 0.78, S3 1.01 / 0.90, S4 1.02 / 1.00. Every sign right and every
magnitude inside about two standard deviations, on an experiment never fitted.
The prediction I most wanted to test � that S3 barely moves while S8 halves �
held; it is the joint consequence of a near-irreversible S2 -> S3 step and the
S7 inhibition partly cancelling.

**knockdown E9 to 0.25, time course.** Predicted S6 dips to ~0.29 by t=1.25 and
then climbs to a plateau of ~0.545 by t~15. Observed: dip to 0.31 at t=1.25-2.5,
plateau ~0.59 by t=20. The time scale and the non-monotone shape are right, on
dynamics never fitted. This matters because steady states say nothing about time
scale � without the two baseline time courses nothing in my data would have
pinned it.

**knockup E4 x3.** Every sign correct (S1, S2, S16 down; S3 through S8 up) but
the magnitudes are off by about 30% in both directions: I predicted S2 = 0.40
and got 0.56, predicted S3 = 1.29 and got 1.75. So the topology of the regulated
step is confirmed and its quantitative parameterisation is not.

**Stopping.** 889 of 1500 budget kept. The remaining disagreement is in
parameter values on module A, not in topology or regulation, and a fourth
experiment of the same kind would not remove a systematic 30% bias � only a
different structural idea would, and I do not have one the data supports. Model
fit overall sits at about 2 sigma against a 1 sigma noise floor; module B fits
within noise everywhere. The two validation steady states were folded into the
final parameter fit afterwards, so the delivered parameters use everything I
bought; the out-of-sample check above stands as recorded, before that refit.

## 8. Final rate-law assignment

| reaction | step | law | confidence |
|---|---|---|---|
| J1 | IN1 -> S1 | michaelis_menten_irreversible | 0.75 |
| J2 | S1 <-> S16 | michaelis_menten_reversible | 0.55 |
| J3 | S1 <-> S2 | michaelis_menten_reversible | 0.55 |
| J4 | S2 -> S3, **inhibited by S7** | michaelis_menten_reversible_inhibited | 0.50 (inhibition itself 0.72) |
| J5 | S3 <-> S4 | mass_action_reversible | 0.50 |
| J6 | S4 -> sink | michaelis_menten_irreversible | 0.60 |
| J7 | S3 <-> S5 | mass_action_reversible | 0.50 |
| J8 | S5 <-> S6 | michaelis_menten_reversible | 0.50 |
| J9 | S6 <-> S7 | mass_action_reversible | 0.50 |
| J10 | S7 <-> S8 | mass_action_reversible | 0.50 |
| J11 | S8 <-> IN2 | michaelis_menten_reversible | 0.55 |
| J12 | S16 -> sink | michaelis_menten_irreversible | 0.70 |
| J13 | S9 <-> S10 | mass_action_reversible | 0.20 |
| J14 | S13 -> sink | mass_action_irreversible | 0.20 |
| J15 | S10 <-> S11 | mass_action_reversible | 0.55 |
| J16 | S11 <-> S12 | mass_action_reversible | 0.55 |
| J17 | S12 <-> S13 | mass_action_reversible | 0.55 |
| J18 | S13 <-> IN3 | mass_action_reversible | 0.50 |
| J19 | IN4 <-> S9 | mass_action_reversible | 0.20 |

Twelve of the nineteen reactions, and every one of the seven in module B, came out **mass action**. That is a
positive result, not a default: a near-equilibrium chain running far below
saturation is legitimately described by mass action, and nothing in the module-B
data demanded the extra parameters.

## 9. Budget

Spent 611 of 1500; **889 kept**. Breakdown in section 5.
