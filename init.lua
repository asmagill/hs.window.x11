--- === hs.window.x11 ===
---
--- Add support for X11 windows to Hamemrspoon. This is a work in progress and will likely be limited in comparison to the full gamut of `hs.window` functions and methods.
---
--- Based partially on the ShiftIt code found at https://github.com/fikovnik/ShiftIt/blob/master/ShiftIt/X11WindowDriver.m

local USERDATA_TAG = "hs.window.x11"
local module       = require(USERDATA_TAG..".internal")
local objectMT     = hs.getObjectMetatable(USERDATA_TAG)

local basePath = package.searchpath(USERDATA_TAG, package.path)
if basePath then
    basePath = basePath:match("^(.+)/init.lua$")
    if require"hs.fs".attributes(basePath .. "/docs.json") then
        require"hs.doc".registerJSONFile(basePath .. "/docs.json")
    end
end

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
local settings     = require("hs.settings")
local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

local window   = require("hs.window")
local inspect  = require("hs.inspect")
local geometry = require("hs.geometry")
local timer    = require("hs.timer")

local _X11LibPaths = {
    "/opt/X11/lib/libX11.6.dylib",    -- XQuartz
    "/opt/local/lib/libX11.6.dylib",  -- MacPorts
    "/sw/X11/lib/libX11.6.dylib",     -- Fink
    "/opt/sw/X11/lib/libX11.6.dylib", -- Fink 0.45.2+
}
local _savedX11LibPath = settings.get(SETTINGS_TAG .. "_libPath")
if _savedX11LibPath then table.insert(_X11LibPaths, 1, _savedX11LibPath) end

local libraryLoaded = false
for _, path in ipairs(_X11LibPaths) do
    local ok, msg = module._loadLibrary(path)
    if ok then
        log.f("X11 library loaded from %s", path)
        libraryLoaded = ok
        break
    else
        log.f("error loading %s: %s", path, msg)
    end
end
if not libraryLoaded then
    log.wf("No valid X11 library found in search paths: %s", inspect(_X11LibPaths))
end
module._setLoggerRef(log)

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

--- hs.window.x11:focus() -> hs.window object
--- Method
--- Focuses the window
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `hs.window.x11` object
objectMT.focus = objectMT.becomeMain

--- hs.window.x11.get(hint) -> hs.window.x11 object
--- Constructor
--- Gets a specific window
---
--- Parameters:
---  * hint - search criterion for the desired window; it can be:
---    - an id number as per `hs.window.x11:id()`
---    - a window title string as per `hs.window.x11:title()`
---
--- Returns:
---  * the first hs.window.x11 object that matches the supplied search criterion, or `nil` if not found
---
--- Notes:
---  * see also `hs.window.x11.find`
module.get = function(hint)
  return table.pack(module.find(hint, true), nil)[1] -- just to be sure, discard extra results
end
module.windowForID = module.get

--- hs.window.x11.find(hint) -> hs.window.x11 object(s)
--- Constructor
--- Finds windows
---
--- Parameters:
---  * hint - search criterion for the desired window(s); it can be:
---    - an id number as per `hs.window.x11:id()`
---    - a string pattern that matches (via `string.find`) the window title as per `hs.window.x11:title()` (for convenience, the matching will be done on lowercased strings)
---
--- Returns:
---  * one or more hs.window.x11 objects that match the supplied search criterion, or `nil` if none found
---
--- Notes:
---  * for convenience you can call this as `hs.window.x11(hint)`
---  * see also `hs.window.x11.get`
module.find = function(hint, exact, wins)
  if hint == nil then return end
  local typ, r = type(hint), {}
  wins = wins or module.allWindows()
  if typ == 'number' then for _, w in ipairs(wins) do if w:id() == hint then return w end end return
  elseif typ ~= 'string' then error('hint must be a number or string', 2) end
  if exact then for _, w in ipairs(wins) do if w:title() == hint then r[#r + 1] = w end end
  else hint = hint:lower() for _, w in ipairs(wins) do local wtitle = w:title() if wtitle and wtitle:lower():find(hint) then r[#r + 1] = w end end end
  if #r > 0 then return table.unpack(r) end
end

--- hs.window.x11._specifyLibraryPath(path) -> boolean[, msg]
--- Function
--- Manually specify the preferred path to libX11.6.dylib for runtime linking
---
--- Parameters:
---  `path` - a string specifying the full path to the libX11.6.dylib library of the X11 installation you want this module to link against.
---
--- Returns:
---  * true if the library is valid (correct architecture and includes the necessary functions), or false and an error message if the library is not usable.
---
--- Notes:
---  * if the library is valid, it will be saved via `hs.settings` under the key "hs_window_x11_libPath" for use on subsequent launches.
---  * if a previously loaded library succeeded, then you will need to restart Hammerspoon for the new library to take its place.
---
---  * Default paths for XQuartz, MacPorts, and Fink are already tried, so this function should only be required if you're installing in a different location or using another package manager.
module._specifyLibraryPath = function(path)
    assert(type(path) == "string", "path must be specified as a string")
    -- this will be true if a library is already loaded
    local testOnly = module._loadLibrary()
    local ok, msg = module._loadLibrary(path, testOnly)
    if ok then
        hs.printf("%s specifies valid library, saving as default", path)
        settings.set(SETTINGS_TAG .. "_libPath", path)
        if testOnly then
            print("You will need to restart Hammerspoon for the new library to be loaded.")
        else
            libraryLoaded = ok
            print("The new library has been loaded and the module is now fully functional.")
        end
        return true
    else
        return false, msg
    end
end

--- hs.window.x11.orderedWindows() -> list of hs.window.x11 objects
--- Function
--- Returns all visible windows, ordered from front to back
---
--- Parameters:
---  * None
---
--- Returns:
---  * A list of `hs.window.x11` objects representing all visible windows, ordered from front to back
module.orderedWindows = function()
  local r = {}
  for _,v in ipairs(module._orderedwinids()) do table.insert(r, module._windowForID(v)) end
  return r
end

--- hs.window.x11.allWindows() -> list of hs.window.x11 objects
--- Function
--- Returns all windows
---
--- Parameters:
---  * None
---
--- Returns:
---  * A list of `hs.window.x11` objects representing all open windows
---
--- Notes:
---  * This function does not include the X11 root window; use `hs.window.x11.desktop()` to access it.

-- -  * `visibleWindows()`, `orderedWindows()`, `get()`, `find()`, and several more functions and methods in this and other modules make use of this function, so it is important to understand its limitations
module.allWindows = function()
  local r = {}
  for _,v in ipairs(module._orderedwinids()) do table.insert(r, module._windowForID(v)) end
  return r
end

--- hs.window.x11.frontmostWindow() -> hs.window.x11 object
--- Constructor
--- Returns the focused window or, if no window has focus, the frontmost one
---
--- Parameters:
---  * None
---
--- Returns:
--- * An `hs.window.x11` object representing the frontmost window, or `nil` if there are no visible windows
module.frontmostWindow = function()
  local w = module.focusedWindow()
  if w then return w end
  return module.orderedWindows()[1]
end

-- mimicing the definitions in `hs.window` in case someone wants to try and apply the same animation stuff

objectMT.size = function(self, ...)
    return geometry(self:_size(...))
end
objectMT.topLeft = function(self, ...)
    return geometry(self:_topLeft(...))
end
objectMT.setSize = function(self, ...)
    return self:_setSize(geometry.size(...))
end
objectMT.setTopLeft = function(self, ...)
    return self:_setTopLeft(geometry.point(...))
end
objectMT.minimize = function(self, ...)
    return self:_minimize(...)
end
objectMT.unminimize = function(self, ...)
    return self:_unminimize(...)
end
objectMT.close = function(self, ...)
    return self:_close(...)
end

objectMT.frame = function(self, ...)
    return geometry(self:_topLeft(...),self:_size(...))
end

objectMT.setFrame = function(self, ...)
    self:_setTopLeft(...)
    return self:_setSize(...)
end

objectMT.setFullScreen = function(self, ...)
  return self:_setFullScreen(...)
end

--- hs.window.x11:toggleFullScreen() -> hs.window.x11 object
--- Method
--- Toggles the fullscreen state of the window
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `hs.window.x11` object
---
--- Notes:
---  * Not all windows support being full-screened
objectMT.toggleFullScreen = function(self, ...)
  return self:setFullScreen(not self:isFullScreen(...))
end
-- aliases
objectMT.toggleFullscreen=objectMT.toggleFullScreen
objectMT.isFullscreen=objectMT.isFullScreen
objectMT.setFullscreen=objectMT.setFullScreen

-- need to figure out screen first...
--
-- --- hs.window.x11:maximize() -> hs.window.x11 object
-- --- Method
-- --- Maximizes the window
-- ---
-- --- Parameters:
-- ---  * None
-- ---
-- --- Returns:
-- ---  * The `hs.window.x11` object
-- ---
-- --- Notes:
-- ---  * The window.x11 will be resized as large as possible, without obscuring the dock/menu
-- ---  * This attempts to resize the window by setting its frame equal to the screen's visible frame, ignoring any X11 hints or window manager functionality for managing windows -- it is not reversible unless you have saved the current frame and use [hs.window.x11:setFrame](#setFrame) to change it back.
-- ---  * See also [hs.window.x11:toggleZoom](#toggleZoom).
-- function objectMT.maximize(self, duration)
--   return self:setFrame(self:screen():frame(), duration)
-- end

function objectMT.toggleZoom(self, ...)
  return self:_toggleZoom(...)
end

--- hs.window.x11:sendToBack() -> hs.window object
--- Method
--- Sends the window to the back
---
--- This method works by focusing all overlapping windows behind this one, front to back.
--- If called on the focused window, this method will switch focus to the topmost window under this one; otherwise, the
--- currently focused window will regain focus after this window has been sent to the back.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `hs.window.x11` object
---
--- Notes:
---  * Due to the way this method works and XQuartz limitations, calling this method when you have a lot of randomly overlapping
---   (as opposed to neatly tiled) windows might be visually jarring, and take a noticable amount of time to complete.
local WINDOW_ROLES = { NORMAL = true, DIALOG = true }
function objectMT.sendToBack(self)
  local id, frame=self:id(),self:frame()
  local fw = module.focusedWindow()
  local wins = module.orderedWindows()
  for z = #wins, 1, -1 do
      local w = wins[z]
      if id == w:id() or not WINDOW_ROLES[w:subrole()] then table.remove(wins, z) end
  end
  local toRaise, topz, didwork={}
  repeat
      for z = #wins, 1, -1 do
          didwork = nil
          local wf = wins[z]:frame()
          if frame:intersect(wf).area > 0 then
              topz = z
              if not toRaise[z] then
                  didwork = true
                  toRaise[z] = true
                  frame = frame:union(wf)
                  break
              end
          end
      end
  until not didwork
  if topz then
      for z = #wins, 1, -1 do
          if toRaise[z] then
              wins[z]:focus()
              timer.usleep(80000)
          end
      end
      wins[topz]:focus()
      if fw and fw:id() ~= id then fw:focus() end
  end
  return self
end

--[=[ <-- So they don't trip up doc generation when I start doing that for real

- hs.window.x11.visibleWindows() -> list of hs.window.x11 objects
- hs.window.x11.minimizedWindows() -> list of hs.window.x11 objects
- hs.window.x11.get(hint) -> hs.window.x11 object
- hs.window.x11.find(hint) -> hs.window.x11 object(s)
- hs.window.x11.frontmostWindow() -> hs.window.x11 object
- hs.window.x11:focus() -> hs.window.x11 object

- hs.window.x11:screen() -> hs.screen object
- hs.window.x11:centerOnScreen([screen][, ensureInScreenBounds][, duration]) --> hs.window.x11 object

- hs.window.x11.invisibleWindows() -> list of hs.window.x11 objects
- hs.window.x11:isVisible() -> boolean
- hs.window.x11:otherWindowsSameScreen() -> list of hs.window.x11 objects
- hs.window.x11:otherWindowsAllScreens() -> list of hs.window.x11 objects

- hs.window.x11:move(rect[, screen][, ensureInScreenBounds][, duration]) --> hs.window.x11 object
- hs.window.x11:moveToUnit(unitrect[, duration]) -> hs.window.x11 object
- hs.window.x11:moveToScreen(screen[, noResize, ensureInScreenBounds][, duration]) -> hs.window.x11 object
- hs.window.x11:windowsToEast([candidateWindows[, frontmost[, strict]]]) -> list of hs.window.x11 objects
- hs.window.x11:windowsToWest([candidateWindows[, frontmost[, strict]]]) -> list of hs.window.x11 objects
- hs.window.x11:windowsToNorth([candidateWindows[, frontmost[, strict]]]) -> list of hs.window.x11 objects
- hs.window.x11:windowsToSouth([candidateWindows[, frontmost[, strict]]]) -> list of hs.window.x11 objects
- hs.window.x11:focusWindowEast([candidateWindows[, frontmost[, strict]]]) -> boolean
- hs.window.x11:focusWindowWest([candidateWindows[, frontmost[, strict]]]) -> boolean
- hs.window.x11:focusWindowNorth([candidateWindows[, frontmost[, strict]]]) -> boolean
- hs.window.x11:focusWindowSouth([candidateWindows[, frontmost[, strict]]]) -> boolean
- hs.window.x11:moveOneScreenEast([noResize, ensureInScreenBounds][, duration]) -> hs.window.x11 object
- hs.window.x11:moveOneScreenWest([noResize, ensureInScreenBounds][, duration]) -> hs.window.x11 object
- hs.window.x11:moveOneScreenNorth([noResize, ensureInScreenBounds][, duration]) -> hs.window.x11 object
- hs.window.x11:moveOneScreenSouth([noResize, ensureInScreenBounds][, duration]) -> hs.window.x11 object


Probably Not:
- hs.window.x11.animationDuration (number)
- hs.window.x11.setFrameCorrectness
- hs.window.x11:setFrameWithWorkarounds(rect[, duration]) -> hs.window.x11 object
- hs.window.x11:setFrameInScreenBounds([rect][, duration]) -> hs.window.x11 object
--]=]

-- Return Module Object --------------------------------------------------

module._dump = function(win, tree, props, attrs, indent)
    indent = indent or 0
    if tree  == nil then tree  = true  end
    if props == nil then props = false end
    if attrs == nil then attrs = false end

    local children = win and win:_queryTree().children or { module.desktop():id() }
    local indString = string.rep("    ", indent)

    for i,v in ipairs(children) do
        local w = module._windowForID(v, true)
        print(string.format("%s%d %s", indString, v, w))
        if tree then
            local ins = inspect(w:_queryTree())
            print(string.format("%sTree: %s", indString, ins:gsub("\n", "\n" .. indString)))
        end
        if props then
            local ins = inspect(w:_attributes())
            print(string.format("%sAttributes: %s", indString, ins:gsub("\n", "\n" .. indString)))
        end
        if attrs then
            local ins = inspect(w:_properties())
            print(string.format("%sProperties: %s", indString, ins:gsub("\n", "\n" .. indString)))
        end

        module._dump(w, tree, props, attrs, indent + 1)
    end
end

return setmetatable(module, {
    __call = function(t, ...) return t.find(...) end
})
