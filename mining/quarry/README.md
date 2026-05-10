# quarry
Quarry script for ComputerCraft turtles.

This script aims to the most reliable and self-sufficient way for a mining turtle to dig a quarry with as little human supervision as possible.

# Usage
Easiest way I know of installing quarry in your turtle is to download the setup script from Pastebin:

`pastebin get dKzF3k4P setup`

and then run it. The setup script downloads the latest scripts from this repository, so pushing an update to GitHub makes future turtle installs current without republishing every script to Pastebin.
Then just run `quarry`, there are a few flags you can specify:

`quarry [-m] [-c]`

`-m` indicates to use a modem to broadcast status messages.
`-c` means to use only Charcoal as fuel, if you don't want it to consume any coal it mines.
More flags and customization to come.

# Publishing the setup paste
Pastebin's API can create and delete pastes, but it cannot edit an existing paste in place. Keep the Pastebin entry as a tiny `setup.lua` bootstrapper that downloads the latest files from GitHub.

To publish a new setup paste:

```powershell
$env:PASTEBIN_DEV_KEY = "your developer key"
.\publish-pastebin.ps1
```

If you publish from a logged-in Pastebin account, also set `PASTEBIN_USER_KEY`. The script records paste IDs in `pastebin-pastes.json` and skips publishing when the remote paste already matches the local file.

Pastebin does not expose an API for editing an existing paste in place. If a file changed, publishing still creates a new paste key. For stable update URLs, use the GitHub-backed `setup.lua` and push code changes to GitHub instead of republishing every script to Pastebin.

# Chest setup
Put a chest directly to the turtle's left at the starting position, or put one `minecraft:chest` in the turtle inventory before starting. If the left side is empty, the turtle will place the chest there the first time it returns to drop items.

# Resuming work
The quarry writes progress to `quarry.state` while it works. If the turtle restarts or the chunk unloads, run `quarry` again and it will load the saved `x`, `y`, `z`, layer direction, quarry size, and fuel-mode settings.

To intentionally start a new quarry from the current position, reset the state file:

```lua
quarry -r
```

# Local tests
This repository includes a small Node/Fengari turtle harness that runs the Lua code with mocked ComputerCraft APIs:

```powershell
npm test
```

The harness is not a full Minecraft simulator, but it is useful for checking movement and inventory logic before testing in-game.

# Updating an existing turtle
Run `setup` again to pull the latest `setup.lua`, `quarry`, `inv`, `t`, and `farmTrees` files from GitHub:

```lua
setup
```

If the turtle still has an old setup script, replace it first:

```lua
delete setup
pastebin get dKzF3k4P setup
setup
```

# Features
* Automatic refueling, using up coal as needed including coal mined from the ground.
* Inventory management such as item sorting and stacking, dropping out thrash such as cobblestone and dirt when inventory is full, and storing ores and treasures in a chest.
* Tries it's best to come back up when something goes wrong, so you don't have to jump into the pit to rescue the turtle if it gets stuck for instance.
* It digs 3 layers at once by digging forwards, up and down for fuel efficience.
* Optionally broadcasts messages over rednet, such as "Dropping thrash" or "Out of fuel", but it's currently unreliable and doesn't seem to work 100% of the time for me.

# To do
* Remember where it left off in a layer before going up to drop stuff in the chest, so when it comes back doesn't need to "restart" the layer.
* Proper rednet communication with maybe a proper monitor program that prints out a diagram of where the turtle is in real time, with options like "come back up".
* Option not to throw, or specifying what "thrash" is.
* Option to specify layer size, now hard coded as 16x16.
