#import "X11uicore.h"
#import "X11interface.h"

@implementation HSX11Window
static int _loggerRef = LUA_NOREF ;

- (instancetype)initWithWindowRef:(Window)winID withDisplayString:(nullable NSString *)displayString {
    self = [super init] ;
    if (self) {
        _winID         = winID ;
        _displayString = displayString ? displayString : defaultDisplayString ;
        _selfRefCount  = 0 ;

        Display *dpy = XOpenDisplayRef(_displayString ? (char *)(uintptr_t)_displayString.UTF8String : NULL) ;
        if (dpy != NULL) {
            NSNumber *value = [HSX11Window _getProperty:"_NET_WM_PID" forWindow:_winID ofDisplay:dpy withDetails:NO] ;
            _pid = (value) ? value.longValue : -1l ;
            XCloseDisplayRef(dpy) ;
        } else {
            [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"initWithWindowRef:withDisplay: - unable to get X display for %@ (XOpenDisplay)", _displayString]] ;
            self = nil ;
        }
    }
    return self ;
}

// - (void)dealloc {
// }

+(int)loggerRef {
    return _loggerRef ;
}

+(void)recordLoggerRef:(int)ref {
    _loggerRef = ref ;
}

+(instancetype)rootWindow {
    HSX11Window *window = nil;

    if (X11Lib_ != NULL) {
        Display *dpy = XOpenDisplayRef(defaultDisplayString ? (char *)(uintptr_t)defaultDisplayString.UTF8String : NULL) ;
        if (dpy != NULL) {
            Window root = DefaultRootWindow(dpy) ;
            window = [[HSX11Window alloc] initWithWindowRef:root withDisplayString:defaultDisplayString] ;
            XCloseDisplayRef(dpy) ;
        } else {
            [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"rootWindow - unable to get X display for %@ (XOpenDisplay)", defaultDisplayString]] ;
        }
    }
    return window;
}

+(instancetype)focusedWindow {
    HSX11Window *window = nil;

    if (X11Lib_ != NULL) {
        Display *dpy = XOpenDisplayRef(defaultDisplayString ? (char *)(uintptr_t)defaultDisplayString.UTF8String : NULL) ;
        if (dpy != NULL) {
            Window root = DefaultRootWindow(dpy) ;
            NSNumber *winID = [HSX11Window _getProperty:"_NET_ACTIVE_WINDOW" forWindow:root ofDisplay:dpy withDetails:NO] ;
            if (winID) {
                window = [[HSX11Window alloc] initWithWindowRef:winID.unsignedLongValue withDisplayString:defaultDisplayString] ;
            }
            XCloseDisplayRef(dpy) ;
        } else {
            [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"focusedWindow - unable to get X display for %@ (XOpenDisplay)", defaultDisplayString]] ;
        }
    }
    return window;
}

+(NSArray<NSNumber *>*)orderedWindowIDs {
    NSArray *windows = [NSArray array] ;

    if (X11Lib_ != NULL) {
        Display *dpy = XOpenDisplayRef(defaultDisplayString ? (char *)(uintptr_t)defaultDisplayString.UTF8String : NULL) ;
        if (dpy != NULL) {
            Window root = DefaultRootWindow(dpy) ;
            NSArray *value = [HSX11Window _getProperty:"_NET_CLIENT_LIST_STACKING" forWindow:root ofDisplay:dpy withDetails:NO] ;
            if (value) {
                windows = value ;
                // _getProperty returns a singleton rather than an array when there is only one item
                if (![windows isKindOfClass:[NSArray class]]) windows = [NSArray arrayWithObject:windows] ;
            }
            XCloseDisplayRef(dpy) ;
        } else {
            [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"_orderedwinids - unable to get X display for %@ (XOpenDisplay)", defaultDisplayString]] ;
        }
    }

    return windows ;
}

-(NSString *)title {
    return [self _getProperty:"WM_NAME"] ;
}
-(NSString *)subRole {
// Per url (2)
//     _NET_WM_WINDOW_TYPE_NORMAL indicates that this is a normal, top-level window, either managed or override-redirect. Managed windows with neither _NET_WM_WINDOW_TYPE nor WM_TRANSIENT_FOR set MUST be taken as this type. Override-redirect windows without _NET_WM_WINDOW_TYPE, must be taken as this type, whether or not they have WM_TRANSIENT_FOR set.
//        managed = in _NET_CLIENT_LIST and/or _NET_CLIENT_LIST_STACKING
//        override_redirect = attributes.override_redirect == true
//
//     _NET_WM_WINDOW_TYPE_DIALOG indicates that this is a dialog window. If _NET_WM_WINDOW_TYPE is not set, then managed windows with WM_TRANSIENT_FOR set MUST be taken as this type. Override-redirect windows with WM_TRANSIENT_FOR, but without _NET_WM_WINDOW_TYPE must be taken as _NET_WM_WINDOW_TYPE_NORMAL.
//
//     if _NET_WM_WINDOW_TYPE set, then use it
//     else
//         override_redirect == _NET_WM_WINDOW_TYPE_NORMAL
//         managed && !WM_TRANSIENT_FOR == _NET_WM_WINDOW_TYPE_NORMAL
//         managed &&  WM_TRANSIENT_FOR == _NET_WM_WINDOW_TYPE_DIALOG
//     can there be !override_redirect and !managed other than root?
//
//     Role       = "X11Window"
//     Subrole    = _NET_WM_WINDOW_TYPE as described above
//     isStandard = Subrole == _NET_WM_WINDOW_TYPE_NORMAL
    NSString *wmType = [self _getProperty:"_NET_WM_WINDOW_TYPE"] ;
    if (!wmType) {
        wmType = @"_NET_WM_WINDOW_TYPE_NORMAL" ;
        Display *dpy = XOpenDisplayRef(_displayString ? (char *)(uintptr_t)_displayString.UTF8String : NULL) ;
        if (dpy != NULL) {
            XWindowAttributes wa ;
            if(XGetWindowAttributesRef(dpy, _winID, &wa)) {
                if (wa.override_redirect == False) {
                    BOOL isManaged = [[HSX11Window orderedWindowIDs] containsObject:@(_winID)] ;
                    if (isManaged) {
                        NSObject *transient = [self _getProperty:"WM_TRANSIENT_FOR"] ;
                        if (transient) wmType = @"_NET_WM_WINDOW_TYPE_DIALOG" ;
                    } else {
                        if (_winID == DefaultRootWindow(dpy)) {
                            wmType = @"_NET_WM_WINDOW_TYPE_ROOT" ;
                        } else {
                        // url (2) is unclear if a non-managed non-override/redirect window without _NET_WM_WINDOW_TYPE
                        // can exist (other than the root one, which I inferred through observarion), so...
                        // using a place holder until I find out otherwise or someone has a better idea.
                            wmType = @"_NET_WM_WINDOW_TYPE_UNKNOWN" ;
                        }
                    }
                }
            } else {
                [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"getTopLeft - unable to get window attributes for window %lu (XGetWindowAttributes)", _winID]] ;
            }
            XCloseDisplayRef(dpy) ;
        } else {
            [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"subrole - unable to get X display for %@ (XOpenDisplay)", _displayString]] ;
        }
    }
    return [wmType stringByReplacingOccurrencesOfString:@"_NET_WM_WINDOW_TYPE_" withString:@""] ;
}

-(NSString *)role {
    return @"X11Window" ;
}

-(BOOL)isStandard {
    return [self.subRole isEqualToString:@"NORMAL"] ;
}

-(NSPoint)getTopLeft {
    NSPoint topLeft = NSZeroPoint ;
    Display *dpy    = XOpenDisplayRef(_displayString ? (char *)(uintptr_t)_displayString.UTF8String : NULL) ;
    if (dpy != NULL) {
        Window            root    = DefaultRootWindow(dpy) ;
        XWindowAttributes wa ;
        if(XGetWindowAttributesRef(dpy, _winID, &wa)) {
            int    x, y ;
            Window ignored ;
            if(XTranslateCoordinatesRef(dpy, _winID, root, -wa.border_width, -wa.border_width, &x, &y, &ignored)) {
//                 topLeft = NSMakePoint(x - wa.x, y - wa.y) ;
                topLeft = NSMakePoint(x, y) ;
            } else {
                [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"getTopLeft - unable to translate coordinates for window %lu (XTranslateCoordinates)", _winID]] ;
            }
        } else {
            [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"getTopLeft - unable to get window attributes for window %lu (XGetWindowAttributes)", _winID]] ;
        }
        XCloseDisplayRef(dpy) ;
    } else {
        [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"getTopLeft - unable to get X display for %@ (XOpenDisplay)", _displayString]] ;
    }
    return topLeft ;
}

-(void)setTopLeft:(NSPoint)topLeft {
    Display *dpy = XOpenDisplayRef(_displayString ? (char *)(uintptr_t)_displayString.UTF8String : NULL) ;
    if (dpy != NULL) {
        XWindowAttributes wa ;
        if(XGetWindowAttributesRef(dpy, _winID, &wa)) {
            // factor window decoration (title bar)
            XMoveWindowRef(dpy, _winID, (int)topLeft.x - wa.x, (int)topLeft.y - wa.y) ;
        } else {
            [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"setTopLeft - unable to get window attributes for window %lu (XGetWindowAttributes)", _winID]] ;
        }
        if (!XSyncRef(dpy, False)) [HSX11Window logLevel:"e" message:@"setTopLeft - unable to sync X11 (XSync)"] ;
        XCloseDisplayRef(dpy) ;
    } else {
        [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"setTopLeft - unable to get X display for %@ (XOpenDisplay)", _displayString]] ;
    }
}

-(NSSize)getSize {
    NSSize  size = NSZeroSize ;
    Display *dpy = XOpenDisplayRef(_displayString ? (char *)(uintptr_t)_displayString.UTF8String : NULL) ;
    if (dpy != NULL) {
        XWindowAttributes wa ;
        if(XGetWindowAttributesRef(dpy, _winID, &wa)) {
            // the height returned is without the window manager decoration - the OSX top bar with buttons, window label and stuff
            // so we need to add it to the height as well because the WindowSize expects the full window
            // the same might be potentially apply to the width
            size = NSMakeSize(wa.width + wa.x, wa.height + wa.y) ;
        } else {
            [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"getSize - unable to get window attributes for window %lu (XGetWindowAttributes)", _winID]] ;
        }
        XCloseDisplayRef(dpy) ;
    } else {
        [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"getSize - unable to get X display for %@ (XOpenDisplay)", _displayString]] ;
    }
    return size ;
}

-(void)setSize:(NSSize)size {
    Display *dpy = XOpenDisplayRef(_displayString ? (char *)(uintptr_t)_displayString.UTF8String : NULL) ;
    if (dpy != NULL) {
        XWindowAttributes wa ;
        if (XGetWindowAttributesRef(dpy, _winID, &wa)) {
            // getSize adds window decoration (titlebar) to size, so here we need to remove it to match what is expected
            XResizeWindowRef(dpy, _winID, (unsigned int)(size.width - wa.x), (unsigned int)(size.height - wa.y)) ;
        } else {
            [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"setSize - unable to get window attributes for window %lu (XGetWindowAttributes)", _winID]] ;
        }
        if (!XSyncRef(dpy, False)) [HSX11Window logLevel:"e" message:@"setSize - unable to sync X11 (XSync)"] ;
        XCloseDisplayRef(dpy) ;
    } else {
        [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"setSize - unable to get X display for %@ (XOpenDisplay)", _displayString]] ;
    }
}

-(void)setFullscreen:(BOOL)fullscreen {
    if ([self WMsupports:"_NET_WM_STATE"]) {
        if ([self supportsAction:"_NET_WM_ACTION_FULLSCREEN"]) {
            Display *dpy = XOpenDisplayRef(_displayString ? (char *)(uintptr_t)_displayString.UTF8String : NULL) ;
            if (dpy != NULL) {
                Window rootWindow = DefaultRootWindow(dpy) ;
                XEvent msg ;
                memset(&msg, 0, sizeof(msg)) ;
                msg.xclient.type = ClientMessage ;
                msg.xclient.message_type = XInternAtomRef(dpy, "_NET_WM_STATE", True) ;
                msg.xclient.window = _winID ;
                msg.xclient.format = 32 ;
                msg.xclient.data.l[0] = fullscreen ? _NET_WM_STATE_ADD : _NET_WM_STATE_REMOVE ;
                msg.xclient.data.l[1] = (long)XInternAtomRef(dpy, "_NET_WM_STATE_FULLSCREEN", True) ;
                msg.xclient.data.l[2] = 0l ;
                msg.xclient.data.l[3] = 2l ; // pagers or other clients that represent direct user actions
                if (!XSendEventRef(dpy, rootWindow, false, SubstructureRedirectMask | SubstructureNotifyMask, &msg)) {
                    [HSX11Window logLevel:"w" message:@"setFullScreen - unable to send _NET_WM_STATE to X11 root window"] ;
                }
                if (!XSyncRef(dpy, False)) [HSX11Window logLevel:"e" message:@"setFullScreen - unable to sync X11 (XSync)"] ;
                XCloseDisplayRef(dpy) ;
            } else {
                [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"setFullScreen - unable to get X display for %@ (XOpenDisplay)", _displayString]] ;
            }
        } else {
            [HSX11Window logLevel:"i" message:[NSString stringWithFormat:@"setFullScreen - window id %lu does not support _NET_WM_ACTION_FULLSCREEN", _winID]] ;
        }
    } else {
        [HSX11Window logLevel:"w" message:@"setFullScreen - window manager does not support _NET_WM_STATE"] ;
    }
}

-(BOOL)isFullscreen {
    BOOL fullscreen = NO;
    if ([self supportsAction:"_NET_WM_ACTION_FULLSCREEN"]) {
        NSArray *states = [self _getProperty:"_NET_WM_STATE"] ;
        if (states) {
            // _getProperty returns a singleton rather than an array when there is only one item
            if (![states isKindOfClass:[NSArray class]]) states = [NSArray arrayWithObject:states] ;
            fullscreen = [states containsObject:@"_NET_WM_STATE_FULLSCREEN"] ;
        }
    }
    return fullscreen;
}

-(BOOL)isMinimized {
    BOOL    result = NO ;
    Display *dpy   = XOpenDisplayRef(_displayString ? (char *)(uintptr_t)_displayString.UTF8String : NULL) ;
    if (dpy != NULL) {
        XWindowAttributes wa ;
        if(XGetWindowAttributesRef(dpy, _winID, &wa)) {
            result = !(wa.map_state == IsViewable) ;
        } else {
            [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"isMinimized - unable to get window attributes for window %lu (XGetWindowAttributes)", _winID]] ;
        }
        XCloseDisplayRef(dpy) ;
    } else {
        [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"isMinimized - unable to get X display for %@ (XOpenDisplay)", _displayString]] ;
    }
    return result ;
}

-(void)setMinimized:(BOOL)minimize {
    Display *dpy = XOpenDisplayRef(_displayString ? (char *)(uintptr_t)_displayString.UTF8String : NULL) ;
    if (dpy != NULL) {
        if (minimize) {
    //         XUnmapWindowRef(dpy, _winID) ; // doesn't put in Dock, just vanishes
            XIconifyWindowRef(dpy, _winID, XDefaultScreenRef(dpy)) ;
        } else {
            XMapWindowRef(dpy, _winID) ;
        }
        if (!XSyncRef(dpy, False)) [HSX11Window logLevel:"e" message:@"setMinimized - unable to sync X11 (XSync)"] ;
        XCloseDisplayRef(dpy) ;
    } else {
        [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"setMinimized - unable to get X display for %@ (XOpenDisplay)", _displayString]] ;
    }
}

-(void)becomeMain {
    Display *dpy = XOpenDisplayRef(_displayString ? (char *)(uintptr_t)_displayString.UTF8String : NULL) ;
    if (dpy != NULL) {
        if ([self WMsupports:"_NET_ACTIVE_WINDOW"]) {
            Window rootWindow = DefaultRootWindow(dpy) ;
            XEvent msg ;
            memset(&msg, 0, sizeof(msg)) ;
            msg.xclient.type = ClientMessage ;
            msg.xclient.message_type = XInternAtomRef(dpy, "_NET_ACTIVE_WINDOW", True) ;
            msg.xclient.window = _winID ;
            msg.xclient.format = 32 ;
            msg.xclient.data.l[0] = 2l ; // pagers or other clients that represent direct user actions
            msg.xclient.data.l[1] = CurrentTime ;
            msg.xclient.data.l[2] = 0 ;
            if (!XSendEventRef(dpy, rootWindow, false, SubstructureRedirectMask | SubstructureNotifyMask, &msg)) {
                [HSX11Window logLevel:"w" message:@"becomeMain - unable to send _NET_ACTIVE_WINDOW to X11 root window"] ;
            }
        } else {
            XSetInputFocusRef(dpy, _winID, RevertToPointerRoot, CurrentTime) ;
        }
        if (!XSyncRef(dpy, False)) [HSX11Window logLevel:"e" message:@"becomeMain - unable to sync X11 (XSync)"] ;
        XCloseDisplayRef(dpy) ;
    } else {
        [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"becomeMain - unable to get X display for %@ (XOpenDisplay)", _displayString]] ;
    }
}

-(void)raise {
    Display *dpy = XOpenDisplayRef(_displayString ? (char *)(uintptr_t)_displayString.UTF8String : NULL) ;
    if (dpy != NULL) {
        XRaiseWindowRef(dpy, _winID) ;
        // won't update _NET_CLIENT_LIST_STACKING if we don't do this...
        if ([self WMsupports:"_NET_ACTIVE_WINDOW"]) {
            Window rootWindow = DefaultRootWindow(dpy) ;
            XEvent msg ;
            memset(&msg, 0, sizeof(msg)) ;
            msg.xclient.type = ClientMessage ;
            msg.xclient.message_type = XInternAtomRef(dpy, "_NET_ACTIVE_WINDOW", True) ;
            msg.xclient.window = _winID ;
            msg.xclient.format = 32 ;
            msg.xclient.data.l[0] = 2l ; // pagers or other clients that represent direct user actions
            msg.xclient.data.l[1] = CurrentTime ;
            msg.xclient.data.l[2] = 0 ;
            if (!XSendEventRef(dpy, rootWindow, false, SubstructureRedirectMask | SubstructureNotifyMask, &msg)) {
                [HSX11Window logLevel:"w" message:@"raise - unable to send _NET_ACTIVE_WINDOW to X11 root window"] ;
            }
        } else {
            [self becomeMain] ;
        }
        if (!XSyncRef(dpy, False)) [HSX11Window logLevel:"e" message:@"raise - unable to sync X11 (XSync)"] ;
        XCloseDisplayRef(dpy) ;
    } else {
        [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"raise - unable to get X display for %@ (XOpenDisplay)", _displayString]] ;
    }
}

// -(void)lower {
//     Display *dpy = XOpenDisplayRef(_displayString ? (char *)(uintptr_t)_displayString.UTF8String : NULL) ;
//     if (dpy != NULL) {
//         XLowerWindowRef(dpy, _winID) ;
//         if (!XSyncRef(dpy, False)) [HSX11Window logLevel:"e" message:@"lower - unable to sync X11 (XSync)"] ;
//         XCloseDisplayRef(dpy) ;
//     } else {
//         [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"lower - unable to get X display for %@ (XOpenDisplay)", _displayString]] ;
//     }
// }

-(void)toggleZoom {
    if ([self WMsupports:"_NET_WM_STATE"]) {
        BOOL canZoomHorizontal = [self supportsAction:"_NET_WM_ACTION_MAXIMIZE_HORZ"] ;
        BOOL canZoomVertical   = [self supportsAction:"_NET_WM_ACTION_MAXIMIZE_VERT"] ;
        if (canZoomHorizontal || canZoomVertical) {
            BOOL isZoomed = NO ;
            NSArray *states = [self _getProperty:"_NET_WM_STATE"] ;
            if (states) {
                // _getProperty returns a singleton rather than an array when there is only one item
                if (![states isKindOfClass:[NSArray class]]) states = [NSArray arrayWithObject:states] ;
                isZoomed = [states containsObject:@"_NET_WM_STATE_MAXIMIZED_HORZ"] ||
                           [states containsObject:@"_NET_WM_STATE_MAXIMIZED_HORZ"] ;
            }
            Display *dpy = XOpenDisplayRef(_displayString ? (char *)(uintptr_t)_displayString.UTF8String : NULL) ;
            if (dpy != NULL) {
                Window rootWindow = DefaultRootWindow(dpy) ;
                XEvent msg ;
                memset(&msg, 0, sizeof(msg)) ;
                msg.xclient.type = ClientMessage ;
                msg.xclient.message_type = XInternAtomRef(dpy, "_NET_WM_STATE", True) ;
                msg.xclient.window = _winID ;
                msg.xclient.format = 32 ;
                msg.xclient.data.l[0] = isZoomed ? _NET_WM_STATE_REMOVE : _NET_WM_STATE_ADD ;
                if (canZoomHorizontal && canZoomVertical) {
                    msg.xclient.data.l[1] = (long)XInternAtomRef(dpy, "_NET_WM_STATE_MAXIMIZED_HORZ", True) ;
                    msg.xclient.data.l[2] = (long)XInternAtomRef(dpy, "_NET_WM_STATE_MAXIMIZED_VERT", True) ;
                } else {
                    msg.xclient.data.l[1] = (long)XInternAtomRef(dpy, canZoomHorizontal ? "_NET_WM_STATE_MAXIMIZED_HORZ" : "_NET_WM_STATE_MAXIMIZED_VERT", True) ;
                    msg.xclient.data.l[2] = 0l ;
                }
                msg.xclient.data.l[3] = 2l ; // pagers or other clients that represent direct user actions
                if (!XSendEventRef(dpy, rootWindow, false, SubstructureRedirectMask | SubstructureNotifyMask, &msg)) {
                    [HSX11Window logLevel:"w" message:@"toggleZoom - unable to send _NET_WM_STATE to X11 root window"] ;
                }
                if (!XSyncRef(dpy, False)) [HSX11Window logLevel:"e" message:@"toggleZoom - unable to sync X11 (XSync)"] ;
                 XCloseDisplayRef(dpy) ;
            } else {
                [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"toggleZoom - unable to get X display for %@ (XOpenDisplay)", _displayString]] ;
            }
        } else {
            [HSX11Window logLevel:"i" message:[NSString stringWithFormat:@"toggleZoom - window id %lu does not support _NET_WM_ACTION_MAXIMIZE_HORZ or _NET_WM_ACTION_MAXIMIZE_VERT", _winID]] ;
        }
    } else {
        [HSX11Window logLevel:"w" message:@"toggleZoom - window manager does not support _NET_WM_STATE"] ;
    }

}

// This is an approximation based on the titlebar used by XQuartz and will probably be completely wrong for any other
// macOS X11 implementation. Feel free to provide fixes or tweaks if you know of another macOS implementation that this
// can be tailored for, especially if you have an idea on how we can differentiate between the two.
-(NSRect)getZoomButtonRect {
    NSRect  rect = NSZeroRect ;
    Display *dpy = XOpenDisplayRef(_displayString ? (char *)(uintptr_t)_displayString.UTF8String : NULL) ;
    if (dpy != NULL) {
        Window            root    = DefaultRootWindow(dpy) ;
        XWindowAttributes wa ;
        if(XGetWindowAttributesRef(dpy, _winID, &wa)) {
            int    x, y ;
            Window ignored ;
            if(XTranslateCoordinatesRef(dpy, _winID, root, -wa.border_width, -wa.border_width, &x, &y, &ignored)) {
                  // XQuartz title bar has a height of 22 when it's showing...
                  if (wa.y == 22) {
                      // these coordinates are based on calculations made by taking the frame of the Hammerspoon console
                      // and comparing it to the zoom button rect for the Hammerspoon console... it's a "best guess"
                      // approximation of something we can't get directly at
                      rect = NSMakeRect(x + 47, y + 3, 14, 16) ;
                  }
            } else {
                [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"zoomButtonRect - unable to translate coordinates for window %lu (XTranslateCoordinates)", _winID]] ;
            }
        } else {
            [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"zoomButtonRect - unable to get window attributes for window %lu (XGetWindowAttributes)", _winID]] ;
        }
        XCloseDisplayRef(dpy) ;
    } else {
        [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"zoomButtonRect - unable to get X display for %@ (XOpenDisplay)", _displayString]] ;
    }

    return rect;
}

// FIXME: Works, but doesn't auto shift focused window to next window, so subsequent window.x11.focusedWindow() generates error
-(BOOL)close {
    BOOL result = NO ;
    Display *dpy = XOpenDisplayRef(_displayString ? (char *)(uintptr_t)_displayString.UTF8String : NULL) ;
    if (dpy != NULL) {
        Window rootWindow = DefaultRootWindow(dpy) ;
        if (_winID != rootWindow) {
            if ([self WMsupports:"_NET_CLOSE_WINDOW"] && [self supportsAction:"_NET_WM_ACTION_CLOSE"]) {
                XEvent msg ;
                memset(&msg, 0, sizeof(msg)) ;
                msg.xclient.type = ClientMessage ;
                msg.xclient.message_type = XInternAtomRef(dpy, "_NET_CLOSE_WINDOW", True) ;
                msg.xclient.window = _winID ;
                msg.xclient.format = 32 ;
                msg.xclient.data.l[0] = CurrentTime ;
                msg.xclient.data.l[1] = 2l ; // pagers or other clients that represent direct user actions
                if (XSendEventRef(dpy, rootWindow, false, SubstructureRedirectMask | SubstructureNotifyMask, &msg)) {
                    result = YES ;
                } else {
                    [HSX11Window logLevel:"w" message:@"close - unable to send _NET_CLOSE_WINDOW to X11 root window"] ;
                }
            } else
            if ([self supportsProtocol:"WM_DELETE_WINDOW"]) {
                // WM doesn't support _NET_CLOSE_WINDOW or window doesn't support _NET_WM_ACTION_CLOSE, but
                // the window does support WM_DELETE_WINDOW protocol, so use it instead.
                XEvent msg ;
                memset(&msg, 0, sizeof(msg)) ;
                msg.xclient.type = ClientMessage ;
                msg.xclient.message_type = XInternAtomRef(dpy, "WM_PROTOCOLS", True) ;
                msg.xclient.window = _winID ;
                msg.xclient.format = 32 ;
                msg.xclient.data.l[0] = (long)XInternAtomRef(dpy, "WM_DELETE_WINDOW", True) ;
                if (XSendEventRef(dpy, _winID, false, NoEventMask, &msg)) {
                    result = YES ;
                } else {
                    [HSX11Window logLevel:"w" message:[NSString stringWithFormat:@"close - unable to send WM_DELETE_WINDOW to window %lu", _winID]] ;
                }
            } else {
                // WM doesn't support _NET_CLOSE_WINDOW or window doesn't support _NEW_WM_ACTION_CLOSE, nor
                // does it support the WM_DELETE_WINDOW protocol. We tried to play nice, but noooo... so kill
                // it the old fashioned way.
                XKillClientRef(dpy, _winID) ;
                result = YES ;
            }
        }
        if (!XSyncRef(dpy, False)) [HSX11Window logLevel:"e" message:@"close - unable to sync X11 (XSync)"] ;
        XCloseDisplayRef(dpy) ;
    } else {
        [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"close - unable to get X display for %@ (XOpenDisplay)", _displayString]] ;
    }
    return result ;
}

+(id)_getProperty:(nullable const char *)atomString forWindow:(Window)winID ofDisplay:(Display *)dpy withDetails:(BOOL)details {
    if (atomString == NULL) return nil ;

    NSDictionary  *results             = nil ;
    Atom          atom                 = XInternAtomRef(dpy, (char *)(uintptr_t)atomString, True) ;

    Atom          actual_type_return   = 0 ;
    int           actual_format_return = 0 ;
    unsigned long nitems_return        = 0l ;
    unsigned long bytes_after_return   = 0l ;
    unsigned char *prop_return         = NULL ;
    if (XGetWindowPropertyRef(dpy, winID, atom, 0, 0x7fffffff, False, AnyPropertyType, &actual_type_return, &actual_format_return, &nitems_return, &bytes_after_return, &prop_return) == Success) {

        char     *type_name = XGetAtomNameRef(dpy, actual_type_return) ;
        NSString *type      = (type_name == NULL) ? @"BadAtom" : @(type_name) ;
        XFreeRef(type_name) ;

        size_t size = nitems_return * (actual_format_return == 16 ? sizeof(short) : (actual_format_return == 32 ? sizeof(long) : 1)) ;
        NSMutableArray *raw = [NSMutableArray arrayWithCapacity:size] ;
        for (unsigned long i = 0 ; i < size ; i++) [raw addObject:[NSNumber numberWithUnsignedChar:prop_return[i]]] ;

        NSObject *value = NULL ;
        if (actual_format_return == 8) {
            value = [NSString stringWithUTF8String:(const char *)prop_return] ;
        } else if (actual_format_return == 16) {
            if (nitems_return == 0) {
                value = [NSNull null] ;
            } else {
                short *numbers = malloc(size) ;
                memcpy(numbers, prop_return, size) ;
                if (nitems_return == 1) {
                    value = [NSNumber numberWithShort:numbers[0]] ;
                } else {
                    NSMutableArray *tmp = [NSMutableArray arrayWithCapacity:nitems_return] ;
                    for (unsigned long i = 0 ; i < nitems_return ; i++) [tmp addObject:[NSNumber numberWithShort:numbers[i]]] ;
                    value = [tmp copy] ; // convert mutable to immutable
                }
                free(numbers) ;
            }
        } else if (actual_format_return == 32) {
            if (nitems_return == 0) {
                value = [NSNull null] ;
            } else {
                long *numbers = malloc(size) ;
                memcpy(numbers, prop_return, size) ;
                if (nitems_return == 1) {
                    value = [NSNumber numberWithLong:numbers[0]] ;
                } else {
                    if (!strcmp("_NET_WM_ICON", atomString)) {
                        value = decodeARGBImage(prop_return) ;
                        raw   = nil ;
                    } else if ([type isEqualToString:@"WM_HINTS"] && nitems_return >= 9) {
                        value = decodeWM_HINTS(numbers, NULL) ;
                        raw   = nil ;
                    } else if ([type isEqualToString:@"WM_SIZE_HINTS"] && nitems_return >= 18) {
                        value = decodeWM_SIZE_HINTS(numbers, NULL) ;
                        raw   = nil ;
                    } else {
                        NSMutableArray *tmp = [NSMutableArray arrayWithCapacity:nitems_return] ;
                        for (unsigned long i = 0 ; i < nitems_return ; i++) [tmp addObject:[NSNumber numberWithLong:numbers[i]]] ;
                        value = [tmp copy] ; // convert mutable to immutable
                    }
                }
                free(numbers) ;
            }
        } else if (actual_type_return == None && actual_format_return == 0) {
            value = [NSNull null] ;
        } else {
            [HSX11Window logLevel:"i" message:[NSString stringWithFormat:@"_getProperty:forWindow:ofDisplay: - %s of type %@ has a return format of %d", atomString, type, actual_format_return]] ;
            value = @"unknown" ;
        }

        if (value) {
            if (value == [NSNull null]) {
                results = @{
                    @"type"         : type,
                    @"typeNumber"   : @(actual_type_return),
                    @"formatNumber" : @(actual_format_return),
                    @"raw"          : [raw copy], // convert mutable to immutable
                    @"size"         : @(nitems_return),
                    @"extra"        : @(bytes_after_return)
                } ;
            } else {
                if ([type isEqualToString:@"ATOM"]) {
                    if ([value isKindOfClass:[NSNumber class]]) {
                        Atom individual_atom  = ((NSNumber *)value).unsignedLongValue ;
                        char *individual_name = XGetAtomNameRef(dpy, individual_atom) ;
                        if (individual_name == NULL) {
                            value = [NSString stringWithFormat:@"ATOM #%lu", individual_atom] ;
                        } else {
                            value = @(individual_name) ;
                            XFreeRef(individual_name) ;
                        }
                    } else {
                        NSMutableArray *tmp = [NSMutableArray arrayWithCapacity:nitems_return] ;
                        for (NSNumber *item in (NSArray *)value) {
                            Atom individual_atom  = item.unsignedLongValue ;
                            char *individual_name = XGetAtomNameRef(dpy, individual_atom) ;
                            if (individual_name == NULL) {
                                [tmp addObject:[NSString stringWithFormat:@"ATOM #%lu", individual_atom]] ;
                            } else {
                                NSString *tmpString = @(individual_name) ;
                                [tmp addObject:tmpString] ;
                                XFreeRef(individual_name) ;
                            }
                        }
                        value = [tmp copy] ; // convert mutable to immutable
                    }
                    raw = nil ;
                }
                results = @{
                    @"value"        : value,
                    @"type"         : type,
                    @"typeNumber"   : @(actual_type_return),
                    @"formatNumber" : @(actual_format_return),
                    @"raw"          : raw ? [raw copy] : [NSNull null], // convert mutable to immutable
                    @"size"         : @(nitems_return),
                    @"extra"        : @(bytes_after_return)
                } ;
            }
        }

        if (!details) results = results[@"value"] ;
        if (prop_return != NULL) XFreeRef(prop_return) ;
    } else {
        [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"_getProperty:forWindow:ofDisplay: - unable to get %s (%lu) for window %lu (XGetWindowProperty)", atomString, atom, winID]] ;
    }

    return results ;
}

-(id)_getProperty:(nullable const char *)atomString {
    NSDictionary *result = nil ;
    Display *dpy = XOpenDisplayRef(_displayString ? (char *)(uintptr_t)_displayString.UTF8String : NULL) ;
    if (dpy != NULL) {
        result = [HSX11Window _getProperty:atomString forWindow:_winID ofDisplay:dpy withDetails:NO] ;
        XCloseDisplayRef(dpy) ;
    } else {
        [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"_getProperty - unable to get X display for %@ (XOpenDisplay)", _displayString]] ;
    }
    return result ;
}

-(NSDictionary *)_getPropertyList {
    NSMutableDictionary *results = [NSMutableDictionary dictionary] ;
    Display             *dpy     = XOpenDisplayRef(_displayString ? (char *)(uintptr_t)_displayString.UTF8String : NULL) ;
    if (dpy != NULL) {
        int num_prop_return ;
        Atom *windowProperties = XListPropertiesRef(dpy, _winID, &num_prop_return) ;
        for (int idx = 0 ; idx < num_prop_return ; idx++) {
            char     *atom_name = XGetAtomNameRef(dpy, windowProperties[idx]) ;
            NSString *key       = @(atom_name) ;
            NSDictionary *value = [HSX11Window _getProperty:atom_name forWindow:_winID ofDisplay:dpy withDetails:YES] ;
            XFreeRef(atom_name) ;
            if (value) results[key] = value ;
        }
        XFreeRef(windowProperties) ;
        XCloseDisplayRef(dpy) ;
    } else {
        [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"_getPropertyList - unable to get X display for %@ (XOpenDisplay)", _displayString]] ;
    }
    return [results copy] ; // convert mutable to immutable
}

-(NSDictionary *)_getWindowAttributes {
    NSMutableDictionary *results = [NSMutableDictionary dictionary] ;
    Display             *dpy     = XOpenDisplayRef(_displayString ? (char *)(uintptr_t)_displayString.UTF8String : NULL) ;
    if (dpy != NULL) {
        XWindowAttributes   wa ;
        if(XGetWindowAttributesRef(dpy, _winID, &wa)) {
            results[@"x"]            = @(wa.x) ;
            results[@"y"]            = @(wa.y) ;
            results[@"width"]        = @(wa.width) ;
            results[@"height"]       = @(wa.height) ;
            results[@"border_width"] = @(wa.border_width) ;
            results[@"depth"]        = @(wa.depth) ;
            results[@"visual"]       = [NSString stringWithFormat:@"%p", (void *)wa.visual] ;
            results[@"rootID"]       = @(wa.root) ;
            switch(wa.class) {
                case InputOutput: results[@"class"] = @"inputOutput" ; break ;
                case InputOnly:   results[@"class"] = @"inputOnly" ; break ;
                default: results[@"class"] = [NSString stringWithFormat:@"unknown class:%d", wa.class] ;
            }
            results[@"bit_gravity"] = decodeBitGravity(wa.bit_gravity) ;
            results[@"win_gravity"] = decodeWindowGravity(wa.win_gravity) ;
            results[@"backing_store"]  = @(wa.backing_store) ;
            results[@"backing_planes"] = @(wa.backing_planes) ;
            results[@"backing_pixel"]  = @(wa.backing_pixel) ;
            results[@"save_under"]     = wa.save_under == True ? @(YES) : @(NO) ;
            results[@"colormap"]       = @(wa.colormap) ;
            results[@"map_installed"]  = wa.map_installed == True ? @(YES) : @(NO) ;
            switch(wa.map_state) {
                case IsUnmapped:   results[@"map_state"] = @"isUnmapped" ; break ;
                case IsUnviewable: results[@"map_state"] = @"isUnviewable" ; break ;
                case IsViewable:   results[@"map_state"] = @"isViewable" ; break ;
                default: results[@"map_state"] = [NSString stringWithFormat:@"unknown map_state:%d", wa.map_state] ;
            }
            results[@"all_event_masks"]       = decodeEventMask(wa.all_event_masks) ;
            results[@"your_event_mask"]       = decodeEventMask(wa.your_event_mask) ;
            results[@"do_not_propagate_mask"] = decodeEventMask(wa.do_not_propagate_mask) ;
            results[@"override_redirect"]     = wa.override_redirect == True ? @(YES) : @(NO) ;
            results[@"screen"]                = [NSString stringWithFormat:@"%p", (void *)wa.screen] ;
        } else {
            [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"_getWindowAttributes - unable to get window attributes for window %lu (XGetWindowAttributes)", _winID]] ;
        }
        XCloseDisplayRef(dpy) ;
    } else {
        [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"_getWindowAttributes - unable to get X display for %@ (XOpenDisplay)", _displayString]] ;
    }
    return [results copy] ; // convert mutable to immutable
}

-(NSDictionary *)_queryTree {
    NSDictionary *results = nil ;
    Display      *dpy     = XOpenDisplayRef(_displayString ? (char *)(uintptr_t)_displayString.UTF8String : NULL) ;
    if (dpy != NULL) {
        Window       root_return ;
        Window       parent_return ;
        Window       *children_return ;
        unsigned int nchildren_return ;
        if (XQueryTreeRef(dpy, _winID, &root_return, &parent_return, &children_return, &nchildren_return)) {
            NSMutableArray *children = [NSMutableArray arrayWithCapacity:nchildren_return] ;
            for (unsigned int i = 0 ; i < nchildren_return ; i++) [children addObject:@(children_return[i])] ;
            results = @{
                @"parent"   : @(parent_return),
                @"root"     : @(root_return),
                @"children" : [children copy] // convert mutable to immutable
            } ;
            if (children_return) XFreeRef(children_return) ;
        } else {
            [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"_queryTree - unable to get tree for window %lu (XQueryTree)", _winID]] ;
        }
        XCloseDisplayRef(dpy) ;
    } else {
        [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"_queryTree - unable to get X display for %@ (XOpenDisplay)", _displayString]] ;
    }
    return results ;
}

-(NSArray *)_getProtocolList {
    NSMutableArray *results = [NSMutableArray array] ;
    Display        *dpy     = XOpenDisplayRef(_displayString ? (char *)(uintptr_t)_displayString.UTF8String : NULL) ;
    if (dpy != NULL) {
        Atom *protocols_return = NULL ;
        int  count_return      = 0 ;
        if (XGetWMProtocolsRef(dpy, _winID, &protocols_return, &count_return)) {
            for (int i = 0 ; i < count_return ; i++) {
                char *atom_name = XGetAtomNameRef(dpy, protocols_return[i]) ;
                if (atom_name != NULL) {
                    NSString *tmpString = @(atom_name) ;
                    [results addObject:tmpString] ;
                    XFreeRef(atom_name) ;
                } else {
                    [results addObject:[NSString stringWithFormat:@"ATOM #%lu", protocols_return[i]]] ;
                }
            }
            XFreeRef(protocols_return) ;
        } else {
            [HSX11Window logLevel:"i" message:[NSString stringWithFormat:@"_getProtocolList - unable to get protocol list for window %lu (XGetWindowAttributes)", _winID]] ;
        }
        XCloseDisplayRef(dpy) ;
    } else {
        [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"_getProtocolList - unable to get X display for %@ (XOpenDisplay)", _displayString]] ;
    }
    return [results copy] ; // convert mutable to immutable
}

-(BOOL)WMsupports:(const char *)hintName {
    BOOL    result = NO ;
    Display *dpy   = XOpenDisplayRef(_displayString ? (char *)(uintptr_t)_displayString.UTF8String : NULL) ;
    if (dpy != NULL) {
        Window  root = DefaultRootWindow(dpy) ;
        NSArray *value = [HSX11Window _getProperty:"_NET_SUPPORTED" forWindow:root ofDisplay:dpy withDetails:NO] ;
        if (value) {
            // _getProperty returns singleton for value if only one object is present, so check
            if (![value isKindOfClass:[NSArray class]]) value = [NSArray arrayWithObject:value] ;
            NSString *tmpString = @(hintName) ;
            result = [value containsObject:tmpString] ;
        }
        XCloseDisplayRef(dpy) ;
    } else {
        [HSX11Window logLevel:"e" message:[NSString stringWithFormat:@"WMsupports - unable to get X display for %@ (XOpenDisplay)", _displayString]] ;
    }
    return result ;
}

-(BOOL)supportsAction:(const char *)actionName {
    BOOL result = NO ;
    NSArray *value = [self _getProperty:"_NET_WM_ALLOWED_ACTIONS"] ;
    if (value) {
        // _getProperty returns singleton for value if only one object is present, so check
        if (![value isKindOfClass:[NSArray class]]) value = [NSArray arrayWithObject:value] ;
        NSString *tmpString = @(actionName) ;
        result = [value containsObject:tmpString] ;
    }
    return result ;
}

-(BOOL)supportsProtocol:(const char *)protocolName {
    NSString *tmpString = @(protocolName) ;
    return [[self _getProtocolList] containsObject:tmpString] ;
}

+(void)logLevel:(const char *)lvl message:(NSString *)message {
    if (HSX11Window.loggerRef == LUA_NOREF) {
        NSString *taggedMessage = [NSString stringWithFormat:@"%s - %@", USERDATA_TAG, message] ;
        if (strlen(lvl) == 1) {
            if        (strncmp(lvl, "d", 1) == 0) {
                [LuaSkin logDebug:taggedMessage] ;
            } else if (strncmp(lvl, "e", 1) == 0) {
                [LuaSkin logError:taggedMessage] ;
            } else if (strncmp(lvl, "i", 1) == 0) {
                [LuaSkin logInfo:taggedMessage] ;
            } else if (strncmp(lvl, "v", 1) == 0) {
                [LuaSkin logVerbose:taggedMessage] ;
            } else if (strncmp(lvl, "w", 1) == 0) {
                [LuaSkin logWarn:taggedMessage] ;
            }
        }
        [LuaSkin logError:[NSString stringWithFormat:@"%s.moduleLogger invalid specifier '%s'. Message: %@", USERDATA_TAG, lvl, message]] ;
    } else {
        LuaSkin   *skin = [LuaSkin sharedWithState:NULL] ;
        lua_State *L    = skin.L ;
        [skin pushLuaRef:LUA_REGISTRYINDEX ref:HSX11Window.loggerRef] ;
        lua_getfield(L, -1, lvl) ;
        [skin pushNSObject:message] ;
        [skin protectedCallAndError:[NSString stringWithFormat:@"%s.moduleLogger callback", USERDATA_TAG] nargs:1 nresults:0] ;
        lua_pop(L, 1) ; // remove loggerRef
    }
}

@end
