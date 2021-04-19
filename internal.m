// Usefull URLs for reference:
//
// (1) https://www.x.org/releases/current/doc/libX11/libX11/libX11.html
// (2) https://specifications.freedesktop.org/wm-spec/wm-spec-latest.html
// (3) https://github.com/jichu4n/basic_wm
// (4) https://github.com/fcwu/RemoteControlLinux
// (5) https://github.com/XQuartz/quartz-wm

// TODO:
//    document
//        standard for Hammerspoon docs
//        review for differences between window and window.x11 -- a lot was just copy/pasted
//        known concerns for non-XQuartz server
//            debugging functions/methods that might help with other servers
//
//    need way to test if _winID still valid to preempt access which generates a lot of errors
//    figure out why close doesn't shift focus to next window like clicking on the "close" button does
//    raise and lower don't seem to affect stacking order (i.e. orderedWindowIDs)
//    seems like wm gets out of sync with actual windows... can we "poke" it in some way to force resync?
//        is there a message we can send?
//
//    change move/resize to protocol/wm_actions?
// *      for minimize and full screen? - no for minimize, yes for fullscreen/maximize
//         other protocol/actions to consider?
//    use XGetWMName for title (and __tostring) and parse XTextProperty as necessary
// *  switch _windowIDs to _NET_CLIENT_LIST_STACKING and simplify/remove init.lua recursion in _orderedWindowIDs
//    need to look closer at init.lua for orderedWindows, visibleWindows, and minimizedWindows return..
//
//    screens? simply moving via topLeft doesn't change the windows screen...
// -      try _NET_MOVERESIZE_WINDOW even though it isn't listed as supported? did nothing
//        maybe need to actually decode/decipher Screen type after all
//
//    code cleanup
// *      move HSX11Window into X11uicore.m
// *      move xdecoders and x helper functions in X11interface.m
// *          including X11_SYMBOL
// *          add function for window_x11_loadLibrary to call
// *      move error logger into HSX11Window class
// *      makefile should merge all .m files
//        maybe a little loosey-goosey with includes... could clean up more, but at least there is a separation of intent now
//    move _protocolList, _properties, and _attributes (others?) to X11interface and add to HSX11Window as a category?
//        X11uicore.* should mirror HSuicore.* as close as reasonablly possible in terms of order, etc.
//        init.lua and internal.m should mirror hs.window files as close as reasonablly possible in terms of order, etc.

// XQuartz supports the following; need to decide which are useful and switch to messaging where possible:
// *   _NET_ACTIVE_WINDOW                 -- root: window ID of the currently active window or None if no window has the focus
// -   _NET_CLIENT_LIST                   -- +(NSArray *)_windowIDs; root: initial mapping order of managed windows
// *   _NET_CLIENT_LIST_STACKING          -- root: bottom-to-top stacking order of managed windows
// *   _NET_CLOSE_WINDOW                  -- -(void)close; root: perform _NET_WM_ACTION_CLOSE on window
// *   _NET_SUPPORTED                     -- -(BOOL)WMsupports; root: indicate which hints it supports
//     _NET_SUPPORTING_WM_CHECK           -- see (2) url
// *   _NET_WM_ACTION_CLOSE               -- -(void)close; indicates that the window may be closed
// *   _NET_WM_ACTION_FULLSCREEN          -- indicates that the window may be brought to fullscreen state
// *   _NET_WM_ACTION_MAXIMIZE_HORZ       -- indicates that the window may be maximized horizontally
// *   _NET_WM_ACTION_MAXIMIZE_VERT       -- indicates that the window may be maximized vertically
// -   _NET_WM_ACTION_MINIMIZE            -- indicates that the window may be iconified
//  ?  _NET_WM_ACTION_MOVE                -- indicates that the window may be moved around the screen
//  ?  _NET_WM_ACTION_RESIZE              -- indicates that the window may be resized
//     _NET_WM_ACTION_SHADE               -- indicates that the window may be shaded
// *   _NET_WM_ALLOWED_ACTIONS            -- -(BOOL)supportsAction; property of all windows of available actions
//  ?  _NET_WM_NAME
// *   _NET_WM_STATE                      -- can use for toggling full screen, others? I don't think iconified (hidden)
// *   _NET_WM_STATE_FULLSCREEN           -- set when xterm full screen via menu
// -   _NET_WM_STATE_HIDDEN               -- apparently not set by XQuartz and according to (2) shouldn't be used to toggle
// *   _NET_WM_STATE_MAXIMIZED_HORZ       -- set when xterm full screen via menu
// *   _NET_WM_STATE_MAXIMIZED_VERT       -- set when xterm full screen via menu
//     _NET_WM_STATE_MODAL
//     _NET_WM_STATE_SHADED
//     _NET_WM_STATE_SKIP_PAGER
//     _NET_WM_STATE_SKIP_TASKBAR
//     _NET_WM_STATE_STICKY
// *   _NET_WM_WINDOW_TYPE                -- used by subRole
// *   _NET_WM_WINDOW_TYPE_*              -- returned by subRole; _NET_WM_WINDOW_TYPE_NORMAL is used for isStandard

#import "X11uicore.h"

static LSRefTable refTable  = LUA_NOREF;

const char * const USERDATA_TAG = "hs.window.x11" ;
NSString *defaultDisplayString = nil ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

#pragma mark - Module Functions

/// hs.window.x11.focusedWindow() -> x11Window
/// Constructor
/// Returns the X11 Window that has keyboard/mouse focus
///
/// Parameters:
///  * None
///
/// Returns:
///  * An `hs.window.x11` object representing the currently focused window
static int window_x11_focusedwindow(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];
    [skin pushNSObject:[HSX11Window focusedWindow]];
    return 1;
}

/// hs.window.x11.desktop() -> hs.window.x11 object
/// Constructor
/// Returns the X11 root window
///
/// Paramters:
///  * None
///
/// Returns:
///  *  hs.window.x11 object for the X11 root window, or nil if there was an error
///
/// Notes:
///  * The X11 root window is the parent window of all X11 windows and covers the entire screen, much like the macOS Desktop window which is managed by the Finder.
///    * Some window managers, including XQuartz, allow the root window to be transparent so X11 applications can better mix with macOS applications. Even when transparent, the window still exists.
///  * The desktop is not included in `hs.window.x11.allWindows()` (and downstream uses)
static int window_x11_rootWindow(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];
    [skin pushNSObject:[HSX11Window rootWindow]];
    return 1;
}

#pragma mark - Internal or Debugging Functions

static int window_x11_orderedwinids(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];
    [skin pushNSObject:[HSX11Window orderedWindowIDs]];
    return 1;
}

static int window_x11_displayString(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;

    if (lua_gettop(L) == 1) {
        if (lua_type(L, 1) == LUA_TSTRING) {
            defaultDisplayString = [skin toNSObjectAtIndex:1] ;
        } else {
            defaultDisplayString = nil ;
        }
    }

    if (defaultDisplayString == nil) {
        lua_pushnil(L) ;
    } else {
        [skin pushNSObject:defaultDisplayString] ;
    }
    return 1 ;
 }

// static int window_x11_loadLibrary(lua_State *L) {
//     defined in X11interfaces.m
// }

static int window_x11_setLoggerRef(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;
    [skin luaUnref:LUA_REGISTRYINDEX ref:HSX11Window.loggerRef] ;
    [HSX11Window recordLoggerRef:[skin luaRef:LUA_REGISTRYINDEX atIndex:1]] ;
    return 0 ;
}

static int window_x11_windowForID(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    Window winID = (Window)lua_tointeger(L, 1) ;
    BOOL bypass = lua_gettop(L) > 1 ? (BOOL)(lua_toboolean(L, 2)) : NO ;

    HSX11Window *window = nil ;
    NSArray *windowIDs = [HSX11Window orderedWindowIDs] ;
    if (bypass || [windowIDs containsObject:@(winID)]) {
        char *displayName = defaultDisplayString ? (char *)(uintptr_t)defaultDisplayString.UTF8String : NULL ;
        Display *dpy = XOpenDisplayRef(displayName) ;
        if (dpy != NULL) {
            window = [[HSX11Window alloc] initWithWindowRef:winID withDisplayString:defaultDisplayString] ;
            XCloseDisplayRef(dpy) ;
        } else {
            [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"_windowForID - unable to get X display for %@ (XOpenDisplay)", defaultDisplayString]] ;
        }
    }

    [skin pushNSObject:window] ;
    return 1 ;
}

#pragma mark - Module Methods

/// hs.window.x11:subrole() -> string
/// Method
/// Gets the subrole of the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the subrole of the window
///
/// Notes:
///  * This typically helps to determine if a window is a special kind of window - such as a modal window, or a floating window
static int window_x11_subrole(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *win = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:win.subRole];
    return 1;
}

/// hs.window.x11:role() -> string
/// Method
/// Gets the role of the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the role of the window
static int window_x11_role(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *win = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:win.role];
    return 1;
}

/// hs.window.x11:isStandard() -> bool
/// Method
/// Determines if the window is a standard window
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if the window is standard, otherwise false
///
/// Notes:
///  * "Standard window" means that this is not an unusual popup window, a modal dialog, a floating window, etc.
static int window_x11_isstandard(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *win = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, win.isStandard);
    return 1;
}

/// hs.window.x11:topLeft() -> point
/// Method
/// Gets the absolute co-ordinates of the top left of the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * A point-table containing the absolute co-ordinates of the top left corner of the window
static int window_x11_topLeft(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *win = [skin toNSObjectAtIndex:1] ;
    [skin pushNSPoint:win.topLeft];
    return 1;
}

/// hs.window.x11:size() -> size
/// Method
/// Gets the size of the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * A size-table containing the width and height of the window
static int window_x11_size(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *win = [skin toNSObjectAtIndex:1] ;
    [skin pushNSSize:win.size];
    return 1;
}

/// hs.window.x11:setTopLeft(point) -> window
/// Method
/// Moves the window to a given point
///
/// Parameters:
///  * point - A point-table containing the absolute co-ordinates the window should be moved to
///
/// Returns:
///  * The `hs.window.x11` object
static int window_x11_setTopLeft(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK];
    HSX11Window *win = [skin toNSObjectAtIndex:1] ;
    win.topLeft = [skin tableToPointAtIndex:2];
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.window.x11:setSize(size) -> window
/// Method
/// Resizes the window
///
/// Parameters:
///  * size - A size-table containing the width and height the window should be resized to
///
/// Returns:
///  * The `hs.window.x11` object
static int window_x11_setSize(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK];
    HSX11Window *win = [skin toNSObjectAtIndex:1] ;
    win.size = [skin tableToSizeAtIndex:2];
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.window.x11:becomeMain() -> window
/// Method
/// Makes the window the main window of its application
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.window.x11` object
static int window_x11_becomemain(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *win = [skin toNSObjectAtIndex:1];
    [win becomeMain];
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.window.x11:raise() -> window
/// Method
/// Brings a window to the front of the screen
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.window.x11` object
static int window_x11_raise(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *win = [skin toNSObjectAtIndex:1] ;
    [win raise];
    lua_pushvalue(L, 1);
    return 1;
}

// /// hs.window.x11:sendToBack() -> window
// /// Method
// /// Sends the window to the back
// ///
// /// Parameters:
// ///  * None
// ///
// /// Returns:
// ///  * The `hs.window.x11` object
// static int window_x11_lower(lua_State* L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L];
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
//     HSX11Window *win = [skin toNSObjectAtIndex:1] ;
//     [win lower];
//     lua_pushvalue(L, 1);
//     return 1;
// }

/// hs.window.x11:close() -> bool
/// Method
/// Closes the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if the operation succeeded, false if not
static int window_x11_close(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *win = [skin toNSObjectAtIndex:1];
    lua_pushboolean(L, [win close]);
    return 1;
}

/// hs.window.x11:minimize() -> window
/// Method
/// Minimizes the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.window.x11` object
static int window_x11_minimize(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *win = [skin toNSObjectAtIndex:1] ;
    win.minimized = YES;
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.window.x11:unminimize() -> window
/// Method
/// Un-minimizes the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.window.x11` object
static int window_x11_unminimize(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *win = [skin toNSObjectAtIndex:1] ;
    win.minimized = NO;
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.window.x11:isMinimized() -> bool
/// Method
/// Gets the minimized state of the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if the window is minimized, otherwise false
static int window_x11_isminimized(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *win = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, win.minimized);
    return 1;
}

/// hs.window.x11:id() -> number
/// Method
/// Gets the unique identifier of the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the unique identifier of the window
static int window_x11_id(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *win = [skin toNSObjectAtIndex:1] ;
    lua_pushinteger(L, (lua_Integer)win.winID) ;
    return 1 ;
}

/// hs.window.x11:setFullScreen(fullscreen) -> window
/// Method
/// Sets the fullscreen state of the window
///
/// Parameters:
///  * fullscreen - A boolean, true if the window should be set fullscreen, false if not
///
/// Returns:
///  * The `hs.window.x11` object
static int window_x11_setfullscreen(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN, LS_TBREAK];
    HSX11Window *win = [skin toNSObjectAtIndex:1] ;
    win.fullscreen = (BOOL)(lua_toboolean(L, 2));
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.window.x11:isFullScreen() -> bool or nil
/// Method
/// Gets the fullscreen state of the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if the window is fullscreen, false if not. Nil if an error occurred
static int window_x11_isfullscreen(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *win = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, win.fullscreen);
    return 1;
}

static int window_x11_pid(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window  *win   = [skin toNSObjectAtIndex:1] ;
    if (win.pid < 0) {
        lua_pushnil(L) ;
    } else {
        lua_pushinteger(L, win.pid);
    }
    return 1;
}

/// hs.window.x11:title() -> string
/// Method
/// Gets the title of the window
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the title of the window or nil if there was an error
static int window_x11_title(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window  *win = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:win.title];
    return 1;
}

/// hs.window.x11:toggleZoom() -> window
/// Method
/// Toggles the zoom state of the window (this is effectively equivalent to clicking the green maximize/fullscreen button at the top left of a window)
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.window.x11` object
static int window_x11_togglezoom(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window  *win = [skin toNSObjectAtIndex:1] ;
    [win toggleZoom];
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.window.x11:zoomButtonRect() -> rect-table or nil
/// Method
/// Gets a rect-table for the location of the zoom button (the green button typically found at the top left of a window)
///
/// Parameters:
///  * None
///
/// Returns:
///  * A rect-table containing the bounding frame of the zoom button, or nil if an error occured
///
/// Notes:
///  * The co-ordinates in the rect-table (i.e. the `x` and `y` values) are in absolute co-ordinates, not relative to the window the button is part of, or the screen the window is on
///  * Although not perfect as such, this method can provide a useful way to find a region of the titlebar suitable for simulating mouse click events on, with `hs.eventtap`
static int window_x11_getZoomButtonRect(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window  *win = [skin toNSObjectAtIndex:1] ;
    [skin pushNSRect:win.zoomButtonRect];
    return 1;
}

/// hs.window.x11:isMaximizable() -> bool or nil
/// Method
/// Determines if a window is maximizable
///
/// Paramters:
///  * None
///
/// Returns:
///  * True if the window is maximizable, False if it isn't, or nil if an error occurred
static int window_x11_isMaximizable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window  *win = [skin toNSObjectAtIndex:1] ;

    if ([win WMsupports:"_NET_WM_STATE"]) {
        BOOL canZoomHorizontal = [win supportsAction:"_NET_WM_ACTION_MAXIMIZE_HORZ"] ;
        BOOL canZoomVertical   = [win supportsAction:"_NET_WM_ACTION_MAXIMIZE_VERT"] ;
        lua_pushboolean(L, canZoomHorizontal || canZoomVertical) ;
    } else {
        [HSX11Window logLevel:"w" message:@"isMaximizable - window manager does not support _NET_WM_STATE"] ;
        lua_pushnil(L);
    }
    return 1;
}

#pragma mark - Internal or Debugging Methods

static int window_x11_propertyList(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *win = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[win _getPropertyList]];
    return 1;
}

static int window_x11_attributes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *win = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[win _getWindowAttributes]];
    return 1;
}

static int window_x11_getProperty(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK];
    HSX11Window *win      = [skin toNSObjectAtIndex:1] ;
    NSString    *atomName = [skin toNSObjectAtIndex:2] ;
    [skin pushNSObject:[win _getProperty:atomName.UTF8String]] ;
    return 1 ;
}

static int window_x11_queryTree(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *win = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[win _queryTree]];
    return 1;
}

static int window_x11_protocolList(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSX11Window *win = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[win _getProtocolList]];
    return 1;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSX11Window(lua_State *L, id obj) {
    HSX11Window *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSX11Window *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSX11WindowFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSX11Window *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSX11Window, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSX11Window *obj = [skin luaObjectAtIndex:1 toClass:"HSX11Window"] ;
    NSString *title = obj.title ;
    if (!title) title = @"<unknown>" ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSX11Window *obj1 = [skin luaObjectAtIndex:1 toClass:"HSX11Window"] ;
        HSX11Window *obj2 = [skin luaObjectAtIndex:2 toClass:"HSX11Window"] ;
        NSString *obj1DisplayString = obj1.displayString ;
        NSString *obj2DisplayString = obj2.displayString ;
        BOOL equal = [obj1 isEqualTo:obj2] ||
                     (
                         (obj1.winID == obj2.winID) &&
                         (obj1.pid == obj2.pid) &&
                         (
                             (!obj1DisplayString && !obj2DisplayString) ||
                             (obj1DisplayString && obj2DisplayString && [obj1DisplayString isEqualToString:obj2DisplayString])
                         )
                     ) ;
        lua_pushboolean(L, equal) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSX11Window *obj = get_objectFromUserdata(__bridge_transfer HSX11Window, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj. selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            obj = nil ;
        }

    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(lua_State* L) {
    if (X11Lib_ != NULL) {
        dlclose(X11Lib_) ;
        X11Lib_ = NULL ;
    }
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [HSX11Window recordLoggerRef:[skin luaUnref:LUA_REGISTRYINDEX ref:HSX11Window.loggerRef]] ;
    defaultDisplayString = nil ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"title",          window_x11_title}, // change to XGetWMName or XFetchName
    {"subrole",        window_x11_subrole},
    {"role",           window_x11_role},
    {"isStandard",     window_x11_isstandard},
    {"_topLeft",       window_x11_topLeft},
    {"_size",          window_x11_size},
    {"_setTopLeft",    window_x11_setTopLeft},
    {"_setSize",       window_x11_setSize},
    {"_minimize",      window_x11_minimize},
    {"_unminimize",    window_x11_unminimize},
    {"isMinimized",    window_x11_isminimized},
    {"isMaximizable",  window_x11_isMaximizable},
    {"pid",            window_x11_pid},
//     {"application",    window_x11_application},              // can we programtically determine app providing Xserver?
//     {"focusTab",       window_x11_focustab},                   // probably n/a
//     {"tabCount",       window_x11_tabcount},                   // probably n/a
    {"becomeMain",     window_x11_becomemain},               // XSetInputFocus
    {"raise",          window_x11_raise},
    {"id",             window_x11_id},
    {"_toggleZoom",    window_x11_togglezoom},
    {"zoomButtonRect", window_x11_getZoomButtonRect},
    {"_close",         window_x11_close},
    {"_setFullScreen", window_x11_setfullscreen},
    {"isFullScreen",   window_x11_isfullscreen},
//     {"snapshot",       window_x11_snapshot},                 // xwd creates "XWD" type file in XY or Z format... can we convert his to NSImage?

//     {"sendToBack",     window_x11_lower},

//     // hs.uielement methods
//     {"isApplication",  window_x11_uielement_isApplication},    // probably n/a
//     {"isWindow",       window_x11_uielement_isWindow},         // probably n/a
//     {"role",           window_x11_uielement_role},             // probably n/a
//     {"selectedText",   window_x11_uielement_selectedText},   // CUT_BUFFER0 property of root window
//     {"newWatcher",     window_x11_uielement_newWatcher},     // I think we need to write our own "X11 client" to receive events

    {"_getProperty",   window_x11_getProperty},
    {"_properties",    window_x11_propertyList},
    {"_attributes",    window_x11_attributes},
    {"_queryTree",     window_x11_queryTree},
    {"_protocolList",  window_x11_protocolList},

    {"__tostring",     userdata_tostring},
    {"__eq",           userdata_eq},
    {"__gc",           userdata_gc},
    {NULL,             NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"focusedWindow",  window_x11_focusedwindow},
    {"_orderedwinids", window_x11_orderedwinids},
//     {"setShadows",     window_x11_setShadows},       // probably n/a and actually no longer works in hs.window
//     {"snapshotForID",  window_x11_snapshotForID},  // xwd creates "XWD" type file in XY or Z format... can we convert his to NSImage?
//     {"timeout",        window_x11_timeout},          // probably n/a
//     {"list",           window_x11_list},           // some combination of _queryTree, _attributes, _properties, probably handle in init.lua

    {"desktop",        window_x11_rootWindow},

    {"_loadLibrary",   window_x11_loadLibrary},
    {"_setLoggerRef",  window_x11_setLoggerRef},
    {"_windowForID",   window_x11_windowForID},
    {"_displayString", window_x11_displayString},

    {NULL,             NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs_window_x11_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSX11Window         forClass:"HSX11Window"];
    [skin registerLuaObjectHelper:toHSX11WindowFromLua forClass:"HSX11Window"
                                            withUserdataMapping:USERDATA_TAG];

    return 1;
}
