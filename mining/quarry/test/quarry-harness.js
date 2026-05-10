const fs = require("fs");
const path = require("path");
const assert = require("assert");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");

const root = path.resolve(__dirname, "..");

function luaString(value) {
  return to_luastring(value);
}

function pushString(L, value) {
  lua.lua_pushstring(L, luaString(value));
}

function getStringArg(L, index) {
  return to_jsstring(lua.lua_tostring(L, index));
}

function getNumberArg(L, index, fallback) {
  if (lua.lua_isnoneornil(L, index)) return fallback;
  return lua.lua_tointeger(L, index);
}

function stackError(L) {
  lauxlib.luaL_tolstring(L, -1);
  return to_jsstring(lua.lua_tostring(L, -1));
}

function pushBlockDetail(L, name) {
  lua.lua_newtable(L);
  pushString(L, name);
  lua.lua_setfield(L, -2, luaString("name"));
}

function pushJsValue(L, value) {
  if (value === null || value === undefined) {
    lua.lua_pushnil(L);
  } else if (typeof value === "boolean") {
    lua.lua_pushboolean(L, value);
  } else if (typeof value === "number") {
    lua.lua_pushnumber(L, value);
  } else if (typeof value === "object") {
    lua.lua_newtable(L);
    for (const [key, child] of Object.entries(value)) {
      pushJsValue(L, child);
      lua.lua_setfield(L, -2, luaString(key));
    }
  } else {
    pushString(L, String(value));
  }
}

function luaValueToJs(L, index) {
  const type = lua.lua_type(L, index);
  if (type === lua.LUA_TBOOLEAN) return Boolean(lua.lua_toboolean(L, index));
  if (type === lua.LUA_TNUMBER) return lua.lua_tonumber(L, index);
  if (type === lua.LUA_TSTRING) return to_jsstring(lua.lua_tostring(L, index));
  if (type !== lua.LUA_TTABLE) return null;

  const absolute = lua.lua_absindex(L, index);
  const result = {};
  lua.lua_pushnil(L);
  while (lua.lua_next(L, absolute) !== 0) {
    const key = luaValueToJs(L, -2);
    result[key] = luaValueToJs(L, -1);
    lua.lua_pop(L, 1);
  }
  return result;
}

function setFunction(L, tableIndex, name, fn) {
  lua.lua_pushcfunction(L, fn);
  lua.lua_setfield(L, tableIndex, luaString(name));
}

function key(pos) {
  return `${pos.x},${pos.y},${pos.z}`;
}

const dirs = [
  { x: 0, y: 1 },
  { x: 1, y: 0 },
  { x: 0, y: -1 },
  { x: -1, y: 0 },
];

function makeHarness() {
  const world = new Map();
  const files = new Map();
  const chest = [];
  const state = {
    pos: { x: 0, y: 0, z: 0 },
    dir: 0,
    selected: 1,
    fuel: 2000,
    inventory: Array.from({ length: 16 }, () => null),
    log: [],
    moves: 0,
    maxMoves: 420,
  };

  for (let x = -1; x < 20; x++) {
    for (let y = -1; y < 20; y++) {
      for (let z = -9; z <= -1; z++) {
        world.set(key({ x, y, z }), "minecraft:stone");
      }
    }
  }

  function frontPos() {
    const dir = dirs[state.dir];
    return { x: state.pos.x + dir.x, y: state.pos.y + dir.y, z: state.pos.z };
  }

  function inspectAt(pos) {
    const block = world.get(key(pos));
    return block ? { success: true, name: block } : { success: false, name: null };
  }

  function moveTo(pos, action) {
    state.moves += 1;
    state.log.push(action);
    if (state.moves > state.maxMoves) throw new Error("simulation move limit reached");
    if (world.has(key(pos))) return false;
    state.pos = pos;
    state.fuel -= 1;
    return true;
  }

  function digAt(pos, action) {
    state.log.push(action);
    world.delete(key(pos));
    return true;
  }

  function selectedItem() {
    return state.inventory[state.selected - 1];
  }

  function addItem(name, count) {
    const existing = state.inventory.find((item) => item && item.name === name && item.count < 64);
    if (existing) {
      const moved = Math.min(count, 64 - existing.count);
      existing.count += moved;
      count -= moved;
    }

    while (count > 0) {
      const slot = state.inventory.findIndex((item) => item === null);
      if (slot < 0) return false;
      const moved = Math.min(count, 64);
      state.inventory[slot] = { name, count: moved };
      count -= moved;
    }

    return true;
  }

  function removeSelected(count) {
    const item = selectedItem();
    if (!item) return null;
    const moved = Math.min(count == null ? item.count : count, item.count);
    const movedItem = { name: item.name, count: moved };
    item.count -= moved;
    if (item.count <= 0) state.inventory[state.selected - 1] = null;
    return movedItem;
  }

  function install(L) {
    lua.lua_newtable(L);
    const turtleIndex = lua.lua_gettop(L);

    setFunction(L, turtleIndex, "turnLeft", () => {
      state.dir = (state.dir + 3) % 4;
      state.log.push("turnLeft");
      return 0;
    });
    setFunction(L, turtleIndex, "turnRight", () => {
      state.dir = (state.dir + 1) % 4;
      state.log.push("turnRight");
      return 0;
    });
    setFunction(L, turtleIndex, "forward", () => {
      lua.lua_pushboolean(L, moveTo(frontPos(), "forward"));
      return 1;
    });
    setFunction(L, turtleIndex, "back", () => {
      const dir = dirs[(state.dir + 2) % 4];
      lua.lua_pushboolean(L, moveTo({ x: state.pos.x + dir.x, y: state.pos.y + dir.y, z: state.pos.z }, "back"));
      return 1;
    });
    setFunction(L, turtleIndex, "up", () => {
      lua.lua_pushboolean(L, moveTo({ x: state.pos.x, y: state.pos.y, z: state.pos.z + 1 }, "up"));
      return 1;
    });
    setFunction(L, turtleIndex, "down", () => {
      lua.lua_pushboolean(L, moveTo({ x: state.pos.x, y: state.pos.y, z: state.pos.z - 1 }, "down"));
      return 1;
    });
    setFunction(L, turtleIndex, "detect", () => {
      lua.lua_pushboolean(L, inspectAt(frontPos()).success);
      return 1;
    });
    setFunction(L, turtleIndex, "detectUp", () => {
      lua.lua_pushboolean(L, inspectAt({ x: state.pos.x, y: state.pos.y, z: state.pos.z + 1 }).success);
      return 1;
    });
    setFunction(L, turtleIndex, "detectDown", () => {
      lua.lua_pushboolean(L, inspectAt({ x: state.pos.x, y: state.pos.y, z: state.pos.z - 1 }).success);
      return 1;
    });
    setFunction(L, turtleIndex, "inspect", () => {
      const block = inspectAt(frontPos());
      lua.lua_pushboolean(L, block.success);
      if (block.success) pushBlockDetail(L, block.name);
      else pushString(L, "No block to inspect");
      return 2;
    });
    setFunction(L, turtleIndex, "inspectUp", () => {
      const block = inspectAt({ x: state.pos.x, y: state.pos.y, z: state.pos.z + 1 });
      lua.lua_pushboolean(L, block.success);
      if (block.success) pushBlockDetail(L, block.name);
      else pushString(L, "No block to inspect");
      return 2;
    });
    setFunction(L, turtleIndex, "inspectDown", () => {
      const block = inspectAt({ x: state.pos.x, y: state.pos.y, z: state.pos.z - 1 });
      lua.lua_pushboolean(L, block.success);
      if (block.success) pushBlockDetail(L, block.name);
      else pushString(L, "No block to inspect");
      return 2;
    });
    setFunction(L, turtleIndex, "dig", () => {
      lua.lua_pushboolean(L, digAt(frontPos(), "dig"));
      return 1;
    });
    setFunction(L, turtleIndex, "digUp", () => {
      lua.lua_pushboolean(L, digAt({ x: state.pos.x, y: state.pos.y, z: state.pos.z + 1 }, "digUp"));
      return 1;
    });
    setFunction(L, turtleIndex, "digDown", () => {
      lua.lua_pushboolean(L, digAt({ x: state.pos.x, y: state.pos.y, z: state.pos.z - 1 }, "digDown"));
      return 1;
    });
    setFunction(L, turtleIndex, "attack", () => 0);
    setFunction(L, turtleIndex, "attackUp", () => 0);
    setFunction(L, turtleIndex, "attackDown", () => 0);
    setFunction(L, turtleIndex, "select", () => {
      state.selected = lua.lua_tointeger(L, 1);
      return 0;
    });
    setFunction(L, turtleIndex, "getSelectedSlot", () => {
      lua.lua_pushinteger(L, state.selected);
      return 1;
    });
    setFunction(L, turtleIndex, "getItemCount", () => {
      const slot = getNumberArg(L, 1, state.selected);
      const item = state.inventory[slot - 1];
      lua.lua_pushinteger(L, item ? item.count : 0);
      return 1;
    });
    setFunction(L, turtleIndex, "getItemSpace", () => {
      const slot = getNumberArg(L, 1, state.selected);
      const item = state.inventory[slot - 1];
      lua.lua_pushinteger(L, item ? 64 - item.count : 64);
      return 1;
    });
    setFunction(L, turtleIndex, "getItemDetail", () => {
      const slot = getNumberArg(L, 1, state.selected);
      const item = state.inventory[slot - 1];
      if (!item) {
        lua.lua_pushnil(L);
        return 1;
      }
      lua.lua_newtable(L);
      pushString(L, item.name);
      lua.lua_setfield(L, -2, luaString("name"));
      lua.lua_pushinteger(L, item.count);
      lua.lua_setfield(L, -2, luaString("count"));
      if (item.damage != null) {
        lua.lua_pushinteger(L, item.damage);
        lua.lua_setfield(L, -2, luaString("damage"));
      }
      return 1;
    });
    setFunction(L, turtleIndex, "transferTo", () => {
      const toSlot = lua.lua_tointeger(L, 1);
      const count = getNumberArg(L, 2, null);
      const item = removeSelected(count);
      if (!item) {
        lua.lua_pushboolean(L, false);
        return 1;
      }
      const dest = state.inventory[toSlot - 1];
      if (!dest) state.inventory[toSlot - 1] = item;
      else dest.count += item.count;
      lua.lua_pushboolean(L, true);
      return 1;
    });
    setFunction(L, turtleIndex, "drop", () => {
      const block = inspectAt(frontPos());
      const item = removeSelected(getNumberArg(L, 1, null));
      if (item && block.name === "minecraft:chest") chest.push(item);
      lua.lua_pushboolean(L, Boolean(item));
      return 1;
    });
    setFunction(L, turtleIndex, "place", () => {
      const item = selectedItem();
      if (!item || world.has(key(frontPos()))) {
        lua.lua_pushboolean(L, false);
        return 1;
      }
      world.set(key(frontPos()), item.name);
      removeSelected(1);
      state.log.push(`place:${item.name}`);
      lua.lua_pushboolean(L, true);
      return 1;
    });
    setFunction(L, turtleIndex, "refuel", () => {
      const item = selectedItem();
      if (!item || (item.name !== "minecraft:coal" && item.name !== "minecraft:charcoal")) {
        lua.lua_pushboolean(L, false);
        return 1;
      }
      removeSelected(getNumberArg(L, 1, 1));
      state.fuel += 80;
      lua.lua_pushboolean(L, true);
      return 1;
    });
    setFunction(L, turtleIndex, "getFuelLevel", () => {
      lua.lua_pushinteger(L, state.fuel);
      return 1;
    });

    lua.lua_setglobal(L, luaString("turtle"));

    lua.lua_newtable(L);
    const rednetIndex = lua.lua_gettop(L);
    setFunction(L, rednetIndex, "open", () => 0);
    setFunction(L, rednetIndex, "close", () => 0);
    setFunction(L, rednetIndex, "broadcast", () => 0);
    setFunction(L, rednetIndex, "receive", () => {
      lua.lua_pushnil(L);
      return 1;
    });
    lua.lua_setglobal(L, luaString("rednet"));

    lua.lua_newtable(L);
    const fsIndex = lua.lua_gettop(L);
    setFunction(L, fsIndex, "exists", () => {
      lua.lua_pushboolean(L, files.has(getStringArg(L, 1)));
      return 1;
    });
    setFunction(L, fsIndex, "delete", () => {
      files.delete(getStringArg(L, 1));
      return 0;
    });
    setFunction(L, fsIndex, "open", () => {
      const filePath = getStringArg(L, 1);
      const mode = getStringArg(L, 2);
      let buffer = "";

      if (mode === "r" && !files.has(filePath)) {
        lua.lua_pushnil(L);
        return 1;
      }

      lua.lua_newtable(L);
      const handleIndex = lua.lua_gettop(L);
      setFunction(L, handleIndex, "write", () => {
        buffer += getStringArg(L, 1);
        return 0;
      });
      setFunction(L, handleIndex, "readAll", () => {
        pushString(L, files.get(filePath) || "");
        return 1;
      });
      setFunction(L, handleIndex, "close", () => {
        if (mode === "w") files.set(filePath, buffer);
        return 0;
      });
      return 1;
    });
    lua.lua_setglobal(L, luaString("fs"));

    lua.lua_newtable(L);
    const textutilsIndex = lua.lua_gettop(L);
    setFunction(L, textutilsIndex, "serialize", () => {
      pushString(L, JSON.stringify(luaValueToJs(L, 1)));
      return 1;
    });
    setFunction(L, textutilsIndex, "unserialize", () => {
      const raw = getStringArg(L, 1);
      try {
        pushJsValue(L, JSON.parse(raw));
      } catch (_) {
        lua.lua_pushnil(L);
      }
      return 1;
    });
    lua.lua_setglobal(L, luaString("textutils"));

    lua.lua_pushcfunction(L, () => 0);
    lua.lua_setglobal(L, luaString("sleep"));
  }

  function newLuaState() {
    const L = lauxlib.luaL_newstate();
    lualib.luaL_openlibs(L);
    install(L);

    const bootstrap = `
      local realLoadfile = loadfile
      os.loadAPI = function(name)
        local env = setmetatable({}, { __index = _G })
        local chunk, err = realLoadfile(name .. ".lua", "t", env)
        if not chunk then error(err, 2) end
        chunk()
        _G[name] = env
        return true
      end
      print = function(...) end
      write = function(...) end
      printError = function(...) end
    `;

    if (lauxlib.luaL_dostring(L, luaString(bootstrap)) !== lua.LUA_OK) {
      throw new Error(stackError(L));
    }

    return L;
  }

  function loadLua(L, file, args = [], options = {}) {
    let source = fs.readFileSync(path.join(root, file), "utf8");
    if (options.truncateBefore) {
      const index = source.indexOf(options.truncateBefore);
      if (index < 0) throw new Error(`truncate marker not found: ${options.truncateBefore}`);
      source = source.slice(0, index);
    }

    const wrapped = `local arg = {...}\n${source}`;
    const status = lauxlib.luaL_loadbuffer(L, luaString(wrapped), null, luaString(file));
    if (status !== lua.LUA_OK) throw new Error(stackError(L));
    for (const arg of args) pushString(L, arg);
    const result = lua.lua_pcall(L, args.length, 0, 0);
    if (result !== lua.LUA_OK) throw new Error(stackError(L));
  }

  function runLua(file, args = []) {
    const L = newLuaState();
    loadLua(L, file, args);
    return L;
  }

  function loadQuarryDefinitions() {
    const L = newLuaState();
    loadLua(L, "quarry.lua", [], { truncateBefore: 'out("\\n\\n\\n-- WELCOME TO THE MINING TURTLE --\\n\\n")' });
    return L;
  }

  function callGlobal(L, name) {
    lua.lua_getglobal(L, luaString(name));
    const result = lua.lua_pcall(L, 0, 1, 0);
    if (result !== lua.LUA_OK) throw new Error(stackError(L));
    const returnValue = lua.lua_tointeger(L, -1);
    lua.lua_pop(L, 1);
    return returnValue;
  }

  return { state, world, files, chest, addItem, runLua, loadQuarryDefinitions, callGlobal };
}

function testGoDownDoesNotPredrillWhenGrounded() {
  const h = makeHarness();
  const L = h.loadQuarryDefinitions();
  h.callGlobal(L, "goDown");

  assert.equal(h.state.pos.z, 0, "goDown should not move down through solid ground");
  assert(!h.state.log.includes("digDown"), "goDown should not dig a starting shaft");
}

function testPlacesChestOnLeftAtOrigin() {
  const h = makeHarness();
  h.addItem("minecraft:chest", 1);
  const L = h.loadQuarryDefinitions();
  h.callGlobal(L, "ensureHomeChest");

  assert.equal(h.world.get(key({ x: -1, y: 0, z: 0 })), "minecraft:chest");
}

function testPlacesModdedChestOnLeftAtOrigin() {
  const h = makeHarness();
  h.addItem("ironchest:chest", 1);
  const L = h.loadQuarryDefinitions();
  h.callGlobal(L, "ensureHomeChest");

  assert.equal(h.world.get(key({ x: -1, y: 0, z: 0 })), "ironchest:chest");
}

function testSaveAndLoadQuarryState() {
  const h = makeHarness();
  let L = h.loadQuarryDefinitions();
  h.callGlobal(L, "saveState");
  assert(h.files.has("quarry.state"), "saveState should create quarry.state");

  h.files.set("quarry.state", JSON.stringify({
    x: 4,
    y: 7,
    z: -3,
    max: 16,
    deep: 64,
    facingfw: false,
    charcoalOnly: true,
    useModem: false,
  }));

  L = h.loadQuarryDefinitions();
  h.callGlobal(L, "loadState");
  h.callGlobal(L, "saveState");
  const state = JSON.parse(h.files.get("quarry.state"));
  assert.equal(state.x, 4);
  assert.equal(state.y, 7);
  assert.equal(state.z, -3);
  assert.equal(state.facingfw, false);
  assert.equal(state.charcoalOnly, true);
}

const tests = [
  testGoDownDoesNotPredrillWhenGrounded,
  testPlacesChestOnLeftAtOrigin,
  testPlacesModdedChestOnLeftAtOrigin,
  testSaveAndLoadQuarryState,
];

for (const test of tests) {
  test();
  console.log(`ok ${test.name}`);
}
