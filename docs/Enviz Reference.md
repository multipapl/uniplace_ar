# Enviz Reference

This document collects public information about Enviz / EnvisionVR. It is the reference our
project leans on: the interaction category, product behaviour, and content-preparation approach
we are matching. It is a reference sheet only — it describes Enviz, not our implementation.

It separates confirmed public information from interpretation. Anything not backed by a source
is marked as inference.

## Research Status

- Official Enviz website, Help Center, Blog, and podcast transcripts were found and are useful.
- No public source describes Enviz's internal renderer or build stack. Those internals are
  unknown and not important to us — what we lean on is the product behaviour and the
  content-preparation approach, both of which are publicly described.

## Main Product Positioning

Source: https://www.enviz.co/platform/enviz

> "3D model or floor plan in"

Confirmed public details:

- Enviz accepts 3D models, floor plans, or project files.
- The output is an Enviz Space.
- Spaces can be opened on mobile, tablet, browser, or headset.
- The product targets client presentations, design validation, marketing assets, virtual
  display homes, and pre-construction sales.
- Enviz emphasizes walkable spaces, not static renders or 360 panoramas.

Relevance: same category as us — interactive real-time archviz for sales and presentation. We
only need the device-as-camera / walkable-space part, not the platform around it.

## Device Support

Source: https://help.enviz.co/en/articles/10352876-device-compatibility

> "minimum of 4GB of RAM"

Confirmed public details:

- Enviz supports mobile devices and tablets through native apps.
- Enviz supports desktop access through browser links.
- Enviz supports VR headsets including Meta Quest II, III, Pro, and Apple Vision Pro.
- Enviz lists 4GB RAM as a mobile/tablet minimum.
- Enviz lists iOS devices from 2017 onward as supported.
- Camera access is needed for AR features.

Relevance: iPad Air 4 with 4GB RAM is a reasonable lower-bound target. Enviz is clearly designed
around mobile constraints, not only headset or desktop hardware.

## App Entry And Project Tiles

Source: https://help.enviz.co/en/articles/10352911-navigate-the-app

> "customised tile for each experience"

Confirmed public details:

- Users can log in or use guest access.
- First-time users see options such as adding a project, guided viewing, and tutorials.
- Existing users see a tile for each experience.
- Tiles include name, image, quick view access, and detailed access.
- Experience pages can include sales information, floor plans, brochures, sharing, and metadata.

Relevance: a simple project card / start screen fits the Enviz pattern. We do not need accounts,
project upload, marketing metadata, or a full experience library.

## In-Experience Navigation

Source: https://help.enviz.co/en/articles/10352911-navigate-the-app

> "Tap the Human icon to enter AR Walkable mode."

Confirmed public features:

- Back navigation.
- Navigation tutorial.
- Native share.
- Walkable Mode.
- Dollhouse Mode.
- Zoom switching between 0.5x and 1x.
- Detailed information panel.
- Teleport location display through a pin icon.
- Style switching through a palette icon.

Relevance: Enviz separates the walkable experience from extra modes. Walkable Mode is the key
reference for us. Teleport locations confirm teleport as a core navigation tool. Style switching,
share, tutorial, and detailed information are future ideas, not core.

## Dollhouse, Table, And Site AR

Source: https://help.enviz.co/en/articles/10352911-navigate-the-app

> "view the dollhouse"

Confirmed public features:

- Dollhouse mode provides a 3D external perspective, including slicing.
- Table View can project the model onto a flat surface.
- View on Site uses passthrough AR to place the experience on a site.

Relevance: Enviz separates walkable mode from tabletop / model-placement AR. We focus on walkable
mode; tabletop and site placement are out of scope for us.

## Guided Viewing

Source: https://help.enviz.co/en/articles/10363316-guided-viewing

> "Presenter uses a tablet"

Confirmed public details:

- Guided Viewing lets a presenter control a viewer's experience.
- Presenter can use a tablet; viewer can connect through headset, tablet, or phone.
- Presenter can select rooms on a floor plan and disable chat and teleport.
- Tablet viewers can enter Walkthrough Mode and confirm the floor level.
- Presenter can change designs, colour schemes, and views.

Relevance: Enviz treats tablet viewing as presentation-grade, not a secondary viewer.
Floor-level confirmation aligns with the calibration step. Room / floorplan navigation is useful
inspiration for hotspots. Guided multi-user viewing is out of scope.

## Model Preparation Guidelines

Source: https://help.enviz.co/en/articles/10334723-guidelines

> "Add a ground plane"

Confirmed public details:

- Enviz asks users to open or hide doors to allow access.
- Enviz asks for a ground plane for navigation.
- Enviz recommends purging unused elements.
- Enviz asks users to check texture requirements and scale.
- Native formats include Revit, SketchUp, and 3ds Max; Blender must be exported to a supported format.
- Model must fit within a 500m x 500m x 500m bounding box.
- Triangle limit is listed as under 4 million; for 3ds Max, max object count is 100,000.

Relevance: walkable navigation needs explicit model preparation — a ground plane / navigation
surface and correct scale matter. The limits are Enviz upload-automation context, not directly
our numbers, since we prepare content ourselves rather than through Enviz's upload pipeline.

## Texture, Material, And Lighting Notes

Source: https://help.enviz.co/en/articles/10334723-guidelines

> "We do not support any custom lighting."

Confirmed public details:

- Enviz upload docs mention support for colour and opacity textures.
- Their 3ds Max notes list Standard, Physical Material, Corona, and VRayMtl.
- The docs say multi textures are not supported.
- The docs describe even lighting with basic ambient occlusion.

Interpretation: these notes likely describe Enviz's automated upload / conversion pipeline, not
necessarily their internal renderer or curated premium examples.

Relevance: Enviz's public upload pipeline appears compatibility-first. Because we prepare and
art-direct content ourselves, we are not bound by these automated-conversion constraints, and we
should not infer Enviz's rendering internals from upload limits.

## Recovery From Bad Position

Source: https://help.enviz.co/en/articles/10366756-stuck-outside-the-model

> "select a room"

Confirmed public details:

- Enviz has help documentation for getting stuck outside the model.
- Suggested recovery includes opening the menu and selecting a room or changing models.
- If that fails, a restart is suggested.

Relevance: getting outside geometry is a real problem even in mature products. A reset / recenter
/ return-to-hotspot flow is required, not optional. Room or hotspot selection can serve as both
navigation and recovery.

## Multi-Platform Story

Source: https://www.enviz.co/platform/enviz

> "mobile, tablet, browser, or headset"

Confirmed public details:

- Enviz presents one Space across several device classes.
- Desktop browser access exists through experience links.
- The platform story supports meetings, follow-up, sales, and design validation.

Relevance: Enviz expresses one source asset across multiple device formats. Our iPad app is
another expression of the same source content, not a separate novelty.

## Content-Preparation Findings (Blog & Podcast)

The blog and podcast transcripts give the clearest public picture of Enviz's hard problem:
turning heavy archviz content into something that runs on lightweight mobile devices.

### Mobile-first strategy

Source: https://www.enviz.co/articles/buildipedia-podcast-ft-david-esber

> "we've always focused on mobile devices"

> "50, 60 gigabytes"

Confirmed public details:

- Enviz contrasts their approach with tethered experiences that need powerful computers.
- They describe mobile devices as central to the business.
- They say they may receive 50-60GB source files and reduce them to something light while
  maintaining fidelity.

Relevance: their core technology is not just a viewer but a content optimization / reduction
process. Their business problem is very close to ours at a smaller scale: take heavy archviz
content and make it run on lightweight devices.

### Internal "black box" conversion

Source: https://www.enviz.co/articles/buildipedia-podcast-ft-david-esber

> "what we refer to as a black box"

Confirmed public details:

- They describe an in-house process developed over several years.
- It takes complex files and makes them very light while still looking real and immersive.
- They describe it as a differentiator.

Relevance: their moat appears to be automated or semi-automated content reduction / optimization.
This aligns with our own view that the hardest part is scalable content preparation.

### Phone / tablet as a window into the design

Sources:
- https://www.enviz.co/articles/off-plan-on-air-podcast-david-esber
- https://www.enviz.co/articles/bridging-the-gap-for-home-builders

> "acts as a window"

Confirmed public details:

- They describe phone / tablet AR as a one-to-one scale walk-through.
- The phone or tablet acts as a window into the design.
- The app tracks movement through the real room and maps it to the model.

Relevance: this is the clearest public confirmation of the exact interaction format we target.
Our portal / magic-window framing matches their public product explanation directly.

### Cross-device distribution

Source: https://www.enviz.co/articles/off-plan-on-air-podcast-david-esber

> "Apple app store or Google play store"

Confirmed public details:

- Enviz is downloadable from the Apple App Store and Google Play.
- It supports phone, tablet, Quest headsets, Quest Pro, and future headset builds.
- It also provides browser-embedded player links.

Relevance: Enviz ships the same experience across many device classes from app stores and the browser.

### 3ds Max plugin and GI workflow

Source: https://www.enviz.co/articles/elevate-hotspot-tours

> "EnvisionVR's plugin"

Confirmed public details:

- They reference an EnvisionVR plugin and ask for an archived 3ds Max file.
- They mention review renders generated from the plugin.
- They advise using global illumination rather than individual camera exposure for consistency.

Relevance: their content pipeline is strongly oriented around 3ds Max, with tooling before upload,
and cares about consistent lighting across the full navigable model rather than isolated camera shots.

### Bertrand Benoit case study

Source: https://www.enviz.co/articles/bertrand-benoit

> "clean quad topology"

Confirmed public details:

- They converted Bertrand Benoit's Garden Loft project.
- Clean quad topology helped processing.
- Complex materials were adaptable and the aesthetic was preserved.
- They removed V-Ray Fur to balance quality and performance for a mobile platform.

Relevance: even high-end CGI scenes require content adaptation. Hair / fur-like features are
problematic for mobile, and material adaptation is part of the conversion process.

## Careers / Hiring Signals

Source: https://www.enviz.co/careers

> "mobile platform"

> "all the technical complexities"

Confirmed public details:

- Enviz is a Sydney-based startup building AR/VR architectural visualization.
- They describe the product as a mobile platform for high-fidelity immersive experiences.
- They emphasize removing technical complexity for partner studios.
- The visible open role during this check was a **Spatial Experience Artist / 3D Technical Artist**
  (location shown: Bangkok), linked via LinkedIn (detail page not accessible during research).

Relevance: the visible hiring signal points toward content preparation / spatial-experience
production as a key operational role — matching the blog/podcast evidence that their hard problem
is conversion and optimization of complex archviz content.

## Unknowns

No reliable public source found for:

- how floor calibration is implemented;
- how tablet walkable mode is implemented internally;
- how reflections are handled;
- whether they use lightmaps, full texture baking, probes, or custom shaders;
- how assets are split or streamed;
- exact mobile performance targets;
- the exact implementation of their 3ds Max plugin;
- what their "black box" optimization actually does.

## What We Draw From Enviz

Use Enviz as reference for:

- a simple project tile / entry screen;
- floor calibration before the walkable experience;
- walkable mode as the primary mode;
- teleport locations;
- a small edge HUD with the important actions;
- a room / hotspot menu for both navigation and recovery;
- the tablet as a presentation-grade client device;
- 4GB-RAM mobile target awareness;
- content reduction as a first-class problem;
- mobile-first performance thinking;
- one-to-one phone / tablet window interaction.

## Out Of Our Scope

Do not try to reproduce:

- the SaaS portal and account system;
- the upload / conversion pipeline;
- guided multi-user viewing;
- AI render generation;
- the full marketing platform;
- tabletop / site-placement AR;
- their content-conversion "black box".

## Source Index

- Enviz Platform: https://www.enviz.co/platform/enviz
- Enviz Home: https://www.enviz.co/
- Enviz Help Center: https://help.enviz.co/
- Navigate the App: https://help.enviz.co/en/articles/10352911-navigate-the-app
- Device Compatibility: https://help.enviz.co/en/articles/10352876-device-compatibility
- Guided Viewing: https://help.enviz.co/en/articles/10363316-guided-viewing
- Guidelines: https://help.enviz.co/en/articles/10334723-guidelines
- Stuck Outside the Model: https://help.enviz.co/en/articles/10366756-stuck-outside-the-model
- Enviz Blog: https://www.enviz.co/blog
- Buildipedia podcast transcript: https://www.enviz.co/articles/buildipedia-podcast-ft-david-esber
- Off-Plan On Air podcast transcript: https://www.enviz.co/articles/off-plan-on-air-podcast-david-esber
- Bertrand Benoit case study: https://www.enviz.co/articles/bertrand-benoit
- Hotspot tours to immersive experiences: https://www.enviz.co/articles/elevate-hotspot-tours
- Home Builders immersive experiences: https://www.enviz.co/articles/bridging-the-gap-for-home-builders
- Enviz Careers: https://www.enviz.co/careers
