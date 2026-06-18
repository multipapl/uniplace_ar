# Backlog — future tasks

Short list of things we deliberately deferred. Not committed reality yet; pick up when relevant.

## Xcode debug-session slowness (NOT an app problem)
Launching/loading under the **Xcode debug session is ~3× slower and the session sometimes drops**.
Running the same build **directly on the iPad (untethered)** is fast — scene load is near-instant.
→ Do **not** judge app/load performance from a tethered debug run. Profile memory/timing from an
untethered launch (or Instruments attach) instead. The deferred-loading design (load after the floor
is confirmed, behind the loading screen, reveal after full load) is fine as-is.

## Probes layer ships textures twice
The `*_Probes.reality` layer still embeds the probe textures, and we also extract them to
`Content/ProbesTextures/`. The runtime only needs probe **positions** from the layer. Future: ship the
probes layer geometry-only (strip textures) to avoid the small double VRAM cost.

## Per-probe IBL blending
Current reflect/glass/water IBL uses the **single nearest** probe per receiver. AVP blended the two
nearest probes by distance. Add 2-probe blend later if reflections pop too hard when crossing between
probe zones.
