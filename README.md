hs.window.x11
-------------

*While this will now compile as a universal library as described at https://github.com/asmagill/hammerspoon_asm/blob/master/README.md, it will not work unless Hammerspoon is running on an Intel mac or in Rosetta mode. This is because XQuartz (and other macos X11 window environments?) have not been compiled as universal binaries yet. There is nothing that can be done about this until they are converted and/or rebuilt by their maintainers.*

- - -

This is a proof of concept module for Hammerspoon which attempts to mirror the `hs.window` module for X11 windows. It has only been tested with [XQuartz](https://www.xquartz.org) though it may work with other macOS X11 implementations.

This is experimental and incomplete, and I make no promises about its usability or when it may be completed, if ever.

Known Issues (though I'm certain there are more...)
* `hs.window.x11:close()` - unlike clicking on the close button provided by the XQuartz window manager, focus does not switch to another window. The currently focused window and window ordering as reported by the window manager will still include the id of the closed window, which may lead to numerous errors being reported until you manually select another X11 window.
* `hs.window.x11:raise()`, `hs.window.x11:becomeMain` - These will update `hs.window.x11.focusedWindow()` immediately, but the selected window will not be actually moved to the front until after you manually activate XQuartz, either by clicking on the icon in the Dock, Cmd-Tabing to it, or clicking on another X11 window; similarly `hs.window.x11.orderedWindows` will not reflect the new order until reentering XQuartz.
* At present, `hs.window.x11.orderedWindows` simply reports the windows that XQuartz reports that it is managing -- no distinction between minimized or visible is made yet (in addition, the other more limited sets of window groups supported by `hs.window` have not been replicated yet)
* Multiple screen support is buggy. While methods like `hs.window.x11:frame`, etc will report window positions on other monitors relative to your primary screen, moving a window to similar coordinates basically "hides" the window -- it doesn't appear on the new screen. It is suspected that exploring the Xinerama library may provide the necessary pointers, but this has not been researched yet.
* Probably others I'm forgetting... check the comments at the top of `internal.m` for more "todo" and "known limitations".

- - -

This is based on code and examples found online from many sources, but esspecially:

1. https://github.com/fikovnik/ShiftIt/blob/master/ShiftIt/X11WindowDriver.m
2. https://www.x.org/releases/current/doc/libX11/libX11/libX11.html
3. https://specifications.freedesktop.org/wm-spec/wm-spec-latest.html
4. https://github.com/jichu4n/basic_wm
5. https://github.com/fcwu/RemoteControlLinux
6. https://github.com/XQuartz/quartz-wm

- - -

My experience programming for X11 begins and ends with this module, so any bug reports, suggestions, updates, pull requests, etc. will be appreciated. This is basically a proof of concept at the moment and may never be finished, so if someone wants to take it and run with it, please feel free.

- - -

### License

> The MIT License (MIT)
> Copyright (c) 2020 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
