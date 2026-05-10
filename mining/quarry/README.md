# ComputerCraft Quarry

Mining turtle quarry program for ComputerCraft / CC:Tweaked.

The normal version runs one turtle. The fleet beta adds a controller computer so several turtles can start, return, stop, and report inventory totals together.

# Quick Install

Basic stable version:

```lua
wget run https://raw.githubusercontent.com/raf181/cc-prog/main/mining/quarry/setup.lua
```

Fleet beta version:

```lua
wget run https://raw.githubusercontent.com/raf181/cc-prog/fleet-beta/mining/quarry/setup.lua
```

The setup command installs these programs:

* `quarry`: the turtle mining program.
* `fleet`: the fleet controller program, beta branch only.
* `inv`, `t`, and `farmTrees`: helper files used by the turtle.
* `setup`: the updater. Run it again later to pull the newest code from GitHub.

# Turtle Requirements

Use a mining turtle.

Required inventory before starting:

* Fuel, usually coal or charcoal.
* One `minecraft:chest` if there is not already a chest on the turtle's left side.

For fleet beta:

* Put a wireless modem on the right side of every turtle.
* Put a wireless modem on the controller computer. The controller can use any side.
* Keep all fleet turtles close enough for rednet wireless range.

# Starting Position

The turtle treats its starting block as home:

```text
home chest  turtle  quarry starts forward
   left       here        this direction
```

The home chest must be directly on the turtle's left side at startup. If the left side is empty and the turtle has a chest in inventory, it will place that chest on the left automatically.

Each turtle mines a 16x16 area in front of its own starting position. It mines the current layer, then moves down three blocks for the next layer. It saves progress in `quarry.state`, so after a restart or chunk unload you can run `quarry` again to continue.

# Quarry Commands

Run the turtle with:

```lua
quarry [-m] [-c] [-r] [-w]
```

Flags:

* `-m`: open rednet on the turtle's right modem and broadcast status.
* `-c`: use only charcoal as fuel. This stops the turtle from burning coal it mines.
* `-r`: reset saved progress and start a new quarry from the current turtle position.
* `-w`: fleet wait mode. The turtle waits for the controller's `start` command before mining. This also enables modem mode.

Common starts:

```lua
quarry
```

Starts or resumes a normal single turtle quarry.

```lua
quarry -r
```

Deletes the old saved position and starts a fresh quarry.

```lua
quarry -rw
```

Fleet beta turtle mode. Reset this turtle's saved quarry, wait for the controller, then start when the controller sends `start`.

# Fleet Beta Setup

For a 32x32 quarry with four turtles, place four turtles so each turtle owns one 16x16 quadrant.

Example layout from above:

```text
T1 -> mines top-left 16x16
T2 -> mines top-right 16x16
T3 -> mines bottom-left 16x16
T4 -> mines bottom-right 16x16
```

Each turtle must face into its own 16x16 area. Put its home chest on its left side, or put a chest in its inventory so it can place one.

On every turtle:

```lua
wget run https://raw.githubusercontent.com/raf181/cc-prog/fleet-beta/mining/quarry/setup.lua
quarry -rw
```

On the controller computer:

```lua
wget run https://raw.githubusercontent.com/raf181/cc-prog/fleet-beta/mining/quarry/setup.lua
fleet
```

# Fleet Controller Screen

The controller screen looks like this:

```text
Quarry Fleet [quarry]
Commands: start | return | stop | reset | clear | quit

ID   Z    Fuel   Event
-------------------------------
10   -6   1200   progress

Kept item totals:
iron_ore                 14
diamond                  2

>
```

Fields:

* `Quarry Fleet [quarry]`: the fleet group name. Current code uses the group `quarry`.
* `ID`: the ComputerCraft computer ID of the turtle that reported status.
* `Z`: the turtle's saved vertical quarry depth. Lower numbers mean it has mined farther down.
* `Fuel`: current turtle fuel level when it last reported.
* `Event`: the last status event from that turtle.
* `Kept item totals`: combined count of non-trash items currently reported by all turtles.
* `(none reported yet)`: the controller has not received item counts from any turtle yet.
* `>`: command prompt. Type a fleet command here and press Enter.

Common events:

* `waiting`: turtle is waiting for a fleet `start`.
* `started`: turtle received the fleet `start` command.
* `ready`: turtle created a new quarry state.
* `resumed`: turtle loaded an existing `quarry.state`.
* `chest`: home chest is ready.
* `warning`: home chest was missing and could not be placed.
* `progress`: turtle moved or started a new row.
* `full`: inventory is full and the turtle is returning to unload.
* `fuel`: turtle needs fuel.
* `blocked`: turtle hit bedrock or an unbreakable block.
* `returning`: turtle received a fleet `return` or `stop`.
* `drop`: turtle dropped items into the home chest.
* `stopped`: quarry loop ended.
* `reset`: turtle reset its saved quarry state from a fleet command.

# Fleet Commands

Type these into the controller program:

* `start`: tells waiting turtles to begin mining.
* `return`: tells active turtles to stop the current pass, go back up, and unload at home.
* `stop`: currently behaves like `return`; turtles return home and stop the quarry loop.
* `reset`: tells waiting turtles to delete `quarry.state` and wait again for `start`.
* `clear`: clears the controller's remembered turtle list and item totals. It does not change turtles.
* `quit`: closes the controller program.
* `exit`: same as `quit`.

Important: `reset` only works while a turtle is in fleet wait mode. To force a reset manually on a turtle, run:

```lua
quarry -r
```

# Updating Existing Turtles

To update an installed turtle or controller:

```lua
setup
```

If the turtle has an old or broken setup file, replace it:

```lua
delete setup
delete quarry
delete fleet
wget run https://raw.githubusercontent.com/raf181/cc-prog/fleet-beta/mining/quarry/setup.lua
```

Use the `main` branch URL instead of `fleet-beta` if you want the basic stable version.

# Troubleshooting

`Failed to download fleet.lua: Not Found`

The turtle is using an old setup script or the wrong branch. Delete `setup`, `fleet`, and `quarry`, then run the fleet beta install command again.

`Invalid flag 'w'`

The installed `quarry` file is the basic version, not the fleet beta version. Reinstall from the `fleet-beta` URL.

Controller shows `(none reported yet)`

No turtle has reported status yet. Check that each turtle has a modem on the right side, is running `quarry -rw`, and is close enough for rednet.

No home chest message on the turtle

The turtle expects the chest on its left side. If you want the turtle to place it, put one chest in its inventory before starting.

Turtle goes down

That is normal quarry behavior. The turtle mines one 16x16 layer and then moves down three blocks to continue the next layer.

# Local Tests

The repo includes a small Node/Fengari test harness for movement and inventory logic:

```powershell
npm test
```

This is not a full Minecraft simulator, but it catches basic logic errors before in-game testing.

# Publishing Notes

Pastebin is only used as an optional bootstrap. The recommended install path is GitHub `wget run`, because updating GitHub updates future turtle installs without creating a new Pastebin paste.

Pastebin cannot edit an existing paste in place through its public API. If you use Pastebin, keep it as a tiny setup loader that downloads the current files from GitHub.
