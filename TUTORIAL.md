Porting 3D Endless Runner to XR
===============================

This tutorial walks through how we took a simple, flat-screen
[3D Endless Runner](https://github.com/dsnopek/3d-endless-runner)
and turned it into an XR game using the
[Spatialize](https://github.com/GodotVR/spatialize) addon.

By the end, the game can be played in three different XR modes, switchable
at runtime from the settings menu:

- **Immersive**: you stand on the road, right behind the runner, with the game
  world all around you.
- **Portal**: the game world is visible through a flat window floating in
  your real room.
- **Volume**: the game world is shrunk down into a small box floating in front
  of you, like a diorama.

The flat-screen version of the game keeps working the whole time - it's the
same project, same scenes and same scripts, with an XR layer added on top.

You'll need Godot 4.6 or later and an OpenXR headset. We developed and tested
this on an Android XR device, but the same approach works on any headset that
supports passthrough (for the Portal and Volume modes) via OpenXR.

## 1. Installing the addons

We started by installing these three addons into the `addons/` directory:

- [Godot OpenXR Vendors](https://github.com/GodotVR/godot_openxr_vendors):
  adds support for vendor-specific OpenXR features, primarily for Android-based
  XR headsets.
- [Godot XR Tools](https://github.com/GodotVR/godot-xr-tools): a large
  collection of ready-made scenes for common XR functionality. We only used a
  few of them for: starting OpenXR, showing a 2D UI in 3D, and the pointers used
  to click on it.
- [Spatialize](https://github.com/GodotVR/spatialize): the utilities for
  converting a flat game to XR, which is what this tutorial is primarily about.

In "Project Settings" -> "Plugins", we enabled both **Godot XR Tools** and
**Spatialize**. (The OpenXR Vendors plugin is a GDExtension and doesn't need to
be enabled.)

## 2. Project settings

Next, we followed the "First Steps" from the Spatialize [README](addons/spatialize/README.md).

In "Project Settings", we:

- Checked **XR** -> **OpenXR** -> **Enabled**
- Checked **XR** -> **Shaders** -> **Enabled**

We also changed a few more settings while we were in there, setting:

- **XR** -> **OpenXR** -> **Reference Space** to **Local Floor**, so the origin
  of the XR world is on the floor where the player launches the app.
- **XR** -> **OpenXR** -> **Foveation Level** to **High**, which is recommended
  for performance.

Then we restarted the editor, which is required after enabling OpenXR.

## 3. Exporting for Android XR

The application won't work in XR yet, but we set up the export preset early,
so that we could add a custom `xr` feature tag to use in "Project Settings"
(which is covered in the next section).

In "Project" -> "Export...", we added a second Android preset, called
"Android XR", and set:

- **Gradle Build** -> **Use Gradle Build** to checked, which is required to use
  the OpenXR Vendors plugin
- **Custom Features** to `xr`, as mentioned above
- **XR Features** -> **XR Mode** to **OpenXR**
- **XR Features** -> **Enable Android XR Plugin** to checked, which comes from
  the OpenXR Vendors addon. When targeting a headset from a different vendor,
  you'd want to enable a different setting.

We also renamed the original preset to "Android (flat)" and marked the new
"Android XR" preset as **Runnable**, so that it's used by the editor's
"Remote Deploy" button.

## 4. Creating the XR main scene

Rather than adding XR nodes to the existing main scene, we made a new main
scene, just for XR, that reuses other scenes from the existing game.

### 4.1 Scene structure

We created a new `xr_main.tscn` scene, built like this:

```
XRMain
├── StartXR                (from XR Tools)
├── XROrigin3D
│   ├── XRCamera3D
│   ├── LeftController     (XRController3D, tracker = left_hand)
│   └── RightController    (XRController3D, tracker = right_hand)
└── GameParent             (Node3D)
    ├── Level              (instance of level.tscn)
    └── Player             (instance of player.tscn)
```

Everything that is "the game" goes under `GameParent`. In the flat main
scene, `Level` and `Player` are direct children of the root, but the additional
`GameParent` node will be useful later, when we want to scale and move the game
for the Portal and Volume modes.

The `XROrigin3D` node is where the player will stand when the game launches,
so we positioned it a few meters behind the character.

### 4.2 Starting OpenXR

We added an instance of `start_xr.tscn` from XR Tools to the root of the
scene. This initializes OpenXR when the app launches, and switches the main
viewport over to rendering in XR.

### 4.3 Reusing the game logic

We gave the XR scene's root a script that extends the flat main script:

```gdscript
extends "res://src/main/main.gd"
```

That's it, for now. The flat script's `_ready()` connects all the signals
from the player and UI, handles starting, pausing, retrying, and so on. By
inheriting from it, the XR scene gets all of that for free. We just had to
point the `level` and `player` exported properties at the nodes under
`GameParent` in the Inspector.

### 4.4 Keeping the flat game runnable

The flat main scene stays as the project's main scene.

In "Project Settings", we selected **Run** -> **Main Scene**, then used the
feature tag override button to add an override for the custom `xr` feature tag,
and pointed that at the new `xr_main.tscn`.

So, pressing play in the editor will still launch the flat `main.tscn` scene.
But when exporting with the "Android XR" preset (including using the
"Remote Deploy" button), the `xr_main.tscn` will be used instead!

At this point, we could run the scene in the headset, and find ourselves
standing on the road behind the runner! We couldn't actually play yet,
though, since there would be no way to click "Play" or move the character.

## 5. User interface

The game's menus and HUD are all in a single `ui.tscn` scene, which the flat
main scene shows in a `CanvasLayer`.

In XR, we show that same scene on a panel floating in front of the player,
using `viewport_2d_in_3d.tscn` from XR Tools.

We added an instance of it as a child of `XROrigin3D`, and set:

- **Content** -> **Scene** to `ui.tscn`
- **Screen Size** to 2x2 meters
- **Viewport Size** to 1024x1024
- **Transparent** to enabled
- **Material** to a transparent, unshaded material so the panel doesn't have a
  visible background and isn't affected by lighting.

Then we added an instance of `function_pointer.tscn` from XR Tools under each
of the two `XRController3D` nodes. These give the player a laser pointer from
each hand that can click the buttons on the panel.

We set their **Process Mode** to **Always**, because the game pauses the scene
tree when the pause menu is up, and the pointers still need to work then.

One catch: the flat main script expects `ui` to be an exported property
pointing at a `Control` node. In the XR scene, the UI is instanced inside the
viewport, so we grab it in code before the parent's `_ready()` runs:

```gdscript
func _ready() -> void:
	ui = viewport_2d_in_3d.get_scene_instance()
	super._ready()
```

Now, if we launch the game, we can press the "Play" button, but are still unable
to steer the character.

## 6. Input

The game already has actions for `move_left`, `move_right`, `jump`, `slide`
and `pause` in its input map, each with both keyboard and gamepad bindings.

However, XR controllers don't go through Godot's input map, so none of those
work in the headset.

Fortunately, the Spatialize addon provides the `controller_input.tscn` scene,
which we instanced in the XR main scene. It listens for the OpenXR actions from
the default action map and re-emits them as normal gamepad input, so the existing
gamepad bindings start working with the XR controllers.

If we were to launch the game at this point, it would finally be fully playable,
moving the character side-to-side with the thumbstick, and using the "A" button
to jump.

## 7. Making the game world relocatable

Before we could build the Portal and Volume modes, the game needed to cope
with the entire world being moved, and shrunk, by changing the transform of
`GameParent`. The flat game was written assuming the world was always at the
origin, with a scale of one, and breaking that assumption caused a few problems.

### 7.1 Local instead of global positions

The level script placed each spawned road, coin, and rock with
`global_transform.origin`, and the player script did the same to slide between
lanes. Global positions are in the XR world's coordinate space, so with a
scaled `GameParent` these would all land in the wrong place.

Since every one of these nodes is a direct child of something in the game
world, the fix was just to use `position` instead:

```gdscript
# Before:
road_asset.global_transform.origin = Vector3(0, 0, p_z)

# After:
road_asset.position = Vector3(0, 0, p_z)
```

### 7.2 Relative positions with Spatialize utils

The `MovingObject` script, which moves the road, coins, and rocks towards the
player, checks each object's global Z position to decide when it has passed
the player and can be freed. That's a global position again, but this time
the object's parent isn't the level, so using `position` won't help.

Spatialize includes a utility for this exact situation: getting a node's
position relative to a specific ancestor.

```gdscript
const SpatializeUtils = preload("res://addons/spatialize/utils.gd")

if SpatializeUtils.get_relative_position(parent, GameState.current_level).z > MAX_Z:
	parent.queue_free()
```

For this to work, the moving object needs to know what the "game world"
node is. We added a `current_level` property to the `GameState` autoload,
and the main script sets it in `_ready()`. This works in both the flat and XR
scenes, because they each set it to their own level.

### 7.3 Scaling physics with the parent

The player is a `CharacterBody3D`, and its gravity and jump velocity are
constants tuned for the world at full size. When the world is shrunk to a
tenth of its size in Volume mode, the character would still jump just as
high in absolute terms - ten times too high relative to the scenery.

The fix was to multiply both by the parent's scale:

```gdscript
var velocity_scale: float = get_parent().scale.x if get_parent() else 1.0

if not is_on_floor():
	velocity.y -= GRAVITY * velocity_scale * p_delta

if is_on_floor() and Input.is_action_pressed("jump"):
	velocity.y = JUMP_VELOCITY * velocity_scale
```

In the flat scene, the parent's scale is one, so nothing changes there.

### 7.4 Level tweaks

A few small changes to the level scene itself:

- **A faux sky box.** We added a large `SphereMesh` with **Flip Faces**
  enabled and an unshaded, sky-colored material. In Portal mode, the
  environment's real sky can't be clipped to the portal (it isn't a mesh),
  so we'll be turning it off and this sphere will stand in for it. The
  environment's **Ambient Light** -> **Source** was set to **Sky**, so the
  lighting stays the same when the sky background is switched off.
- **Spawn further away.** The road and obstacles used to spawn 50 units down
  the road. On a flat screen with a fixed camera, that's off in the distance.
  In a headset, you can see further and turn your head, so objects popping
  into existence were noticeable. Now they spawn at 65 units.

## 8. Adding an XR mode setting

With all that groundwork done, we could start on the Portal and Volume modes.

First, the UI: we added a "Settings" button to the main menu, and a settings
screen with a single **XR Mode** option button offering "Immersive", "Portal"
and "Volume". Selecting one emits a new `xr_mode_changed` signal from the UI
script. The settings button is hidden unless running on a platform where the
mixed reality modes work, so the flat build won't show it.

In the XR main script, that signal is connected to a `set_xr_mode()`
function. The bulk of it is just deciding where things go and what's visible
for each mode. To make positions easy to tweak in the editor, we added a few
`Marker3D` nodes to the XR scene, and the script copies their positions into
the `XROrigin3D` and `GameParent` when the mode changes:

- `VROriginMarker`: where the player stands in Immersive mode.
- `PortalOriginMarker`: where the player stands in Portal mode.
- `VolumeOriginMarker` and `VolumeGameMarker`: where the player stands and
  where the shrunken game world floats in Volume mode.

### 8.1 Immersive mode

This is the mode the game has been running in up until this point.

When switching to Immersive mode, we only need to _reset_ the various settings
that are changed in Portal and Volume mode, for example:

- `XROrigin3D` moves to `VROriginMarker`
- `GameParent` is reset to the origin, at a scale of one
- The OpenXR environment blend mode is set to opaque (disabling passthrough)
- The environment's background is set back to the sky:

```gdscript
openxr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_OPAQUE
world_environment.environment.background_mode = Environment.BG_SKY
get_viewport().transparent_bg = false
```

### 8.2 Portal mode

The Portal mode follows the "Portal" section of the Spatialize [README](addons/spatialize/README.md).

We added a `MeshInstance3D` (called `FlatPortal`) with a `QuadMesh` (ours is
4x4 meters) to the XR scene and positioned it standing upright between the player
and the road. Then in `_ready()`, we used `Stencilizer` to turn it into a portal
(using stencils), and to mark the game world as only visible through it:

```gdscript
const Stencilizer = preload("res://addons/spatialize/stencilizer.gd")

var stencilizer: Stencilizer = Stencilizer.new()

func _ready() -> void:
	# ...
	stencilizer.setup_portal_material(flat_portal)
```

The objects that should appear inside the portal are set up when entering the
mode, rather than in `_ready()`, because Immersive mode needs them *not* to
be stencilized:

```gdscript
stencilizer.setup_object_materials(player)
stencilizer.setup_object_materials(level)
```

There's a wrinkle: the level keeps spawning new roads, coins, and rocks while
the game runs, and those need to be stencilized as well. We added an
`object_spawned` signal to the level script, emitted every time something is
added, and the XR main script listens for it:

```gdscript
func _on_level_object_spawned(obj: Node3D) -> void:
	if xr_mode >= 1:
		stencilizer.setup_object_materials(obj)
```

To see the real room around the portal, we needed passthrough. The Spatialize
README suggests the **Enable Passthrough** property on `StartXR`, but since
we're switching modes at runtime, we did the equivalent in code:

```gdscript
openxr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
world_environment.environment.background_mode = Environment.BG_COLOR
world_environment.environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
get_viewport().transparent_bg = true
```

This is where the faux sky box from section 7.4 comes in. With the
environment background transparent, the sphere provides the sky, and because
it's an ordinary mesh, the `Stencilizer` clips it to the portal along with
everything else.

Finally, the `XROrigin3D` moves to `PortalOriginMarker`, `GameParent` stays
at the origin at full scale, and the `FlatPortal` is made visible.

### 8.3 Volume mode

Volume mode is similar to Portal mode, but with a `BoxMesh` as the portal
instead of a `QuadMesh`. So, we added a second `MeshInstance3D` called `CubePortal`,
which is also set up with `stencilizer.setup_portal_material()` in `_ready()`.

In this mode, `GameParent` is scaled down to a tenth of its size, and moved
up to `VolumeGameMarker` so that the road runs through the middle of the box,
which floats at about waist height. The `XROrigin3D` moves to
`VolumeOriginMarker`, which is right in front of it.

As the Spatialize README explains, the `CubePortal` on its own isn't enough:
the game world would still render out to the camera's far distance whenever you
look through it. So, we also added an instance of the `cube_depth.tscn`
scene from Spatialize, with its mesh sized and positioned to match `CubePortal`.
It fills the depth buffer, so nothing renders beyond the box.

The faux sky box and the ground plane are hidden in this mode, so that the
box really does look like a little chunk of road floating in the room.

### 8.4 Switching modes at runtime

Because the modes can be changed at any time from the settings menu, each
one has to fully undo the others. The `Stencilizer` remembers the original
materials, so going back to Immersive is just:

```gdscript
stencilizer.restore_object_materials(player)
stencilizer.restore_object_materials(level)
```

Everything else is handled by setting the visibility of `FlatPortal`,
`CubePortal`, `CubeDepth`, the faux sky box and the ground plane explicitly
in every branch of `set_xr_mode()`.

## Where to go from here

Everything described in this tutorial is a
[single commit](https://github.com/GodotVR/3d-endless-runner/commit/050ac88d89ece556ee601c15ff686eb5331b6d99)
in the demo's Git history, and the full code is there if you want to dig into
any of the details.

We've continued to iterate on the demo since then!

For example, we added support for hand tracking, with on-screen buttons that
appear in the UI panel when the controllers are put down, and updated the project
to Godot 4.7.

See the [Spatialize README](addons/spatialize/README.md) for a high-level description
of how you could spatialize your own app.
