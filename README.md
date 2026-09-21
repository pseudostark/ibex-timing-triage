# ibex-timing-triage

**Which failing timing paths does the flow fix on its own, and which ones end up on an engineer's desk?**

This project stresses the [Ibex](https://github.com/lowRISC/ibex) RISC-V core in the open-source
[OpenROAD-flow-scripts](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts) flow on the
SkyWater 130 nm (`sky130hd`) platform. It reads timing directly from the OpenSTA engine at two
checkpoints: after clock tree synthesis, and at signoff. The goal is tooling that compares the checkpoints
endpoint by endpoint and flags the paths that survive automated optimisation.

## Results so far

| Run | Checkpoint | WNS (ns) | TNS (ns) | Failing endpoints | Hold WNS (ns) |
|---|---|---:|---:|---:|---:|
| Reference clock | after CTS | +0.0107 | 0.0000 | 0 | +0.4191 |
| Reference clock | signoff | +0.0097 | 0.0000 | 0 | +0.4190 |
| Tightened clock | after CTS | −0.0954 | −0.4469 | 9 | +0.4274 |
| Tightened clock | signoff | **−0.0553** | **−0.0747** | **2** | +0.4301 |

Clock period: reference **10.00 ns**, tightened **09.00 ns**.

**What this shows**

- At the reference clock, Ibex closes timing with about 10 ps to spare, and routing costs only 1 ps.
- With a tighter clock, 9 endpoints fail after CTS. Post-CTS optimisation (global-route repair and the
  final `repair_timing`) cuts that to 2 and reduces TNS by about 83%.
- The 2 remaining endpoints are the interesting part: they are what a human would have to fix.
  Working out why they survive is the next step.
- Hold timing is healthy throughout, so this is a pure setup-timing study.

## Repository

| File | Purpose |
|---|---|
| `cts.tcl` | Loads the post-CTS checkpoint with placement-estimated parasitics and reports setup/hold timing |
| `final.tcl` | Loads the signoff checkpoint with extracted SPEF parasitics and reports the same metrics |
| `extract_paths.tcl` | **Work in progress.** Dumps per-endpoint path data (CSV and JSON) for the diff tool |

## How to reproduce

Run the flow in the official Docker image. I mount the host `flow/` directory directly over the one inside
the image. The `docker_shell` helper mounted the host directory elsewhere, so the flow silently ran from
the image's built-in copy and ignored local edits.

```bash
cd OpenROAD-flow-scripts/flow
docker run --rm -it -u $(id -u):$(id -g) \
  -v "$(pwd):/OpenROAD-flow-scripts/flow" openroad/orfs:latest bash

# inside the container
cd /OpenROAD-flow-scripts/flow
make DESIGN_CONFIG=./designs/sky130hd/ibex/config.mk          # full RTL-to-GDS run
make DESIGN_CONFIG=./designs/sky130hd/ibex/config.mk bash     # shell with every flow variable set
$OPENROAD_EXE -no_init -exit cts.tcl
$OPENROAD_EXE -no_init -exit final.tcl
```

Two things that cost me time:

- The `make ... bash` shell sets the flow variables but not the `PATH`, so `openroad` is not found.
  Call it through `$OPENROAD_EXE`, which the Makefile sets to an absolute path.
- The post-CTS checkpoint is written as `4_1_cts.odb`, not `4_cts.odb`.

To tighten the clock, edit `clk_period` in `designs/sky130hd/ibex/constraint.sdc` and rerun from synthesis.

## Next steps

- [ ] Dump every failing endpoint at both checkpoints and diff them: which were fixed, which survived,
      which appeared.
- [ ] Trace the 2 surviving paths stage by stage (`report_checks -to <pin> -fields {slew cap fanout}`)
      and explain why the resizer could not close them.
- [ ] Group endpoints by module so a long violation list collapses into a few root causes.
- [ ] Wrap it all in one `make` target that runs on committed sample data without installing OpenROAD.

---
Aditya Shah · M.Sc. Control, Microsystems and Microelectronics, University of Bremen ·
[LinkedIn](https://www.linkedin.com/in/adityashah1310/)
