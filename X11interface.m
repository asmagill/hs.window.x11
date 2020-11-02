#import "X11interface.h"
#import "X11decoders.h"
#import "X11uicore.h"

// not null if the X11 functions have been loaded
void     *X11Lib_ = NULL;

// X11 function pointers
Display *(*XOpenDisplayRef)(char *display_name);
int      (*XCloseDisplayRef)(Display *display);
int      (*XFreeRef)(void *data);
int      (*XSetErrorHandlerRef)(int (*handler)(Display *, XErrorEvent *));
int      (*XGetErrorTextRef)(Display *display, int code, char *buffer_return, int length);
int      (*XSyncRef)(Display *display, Bool discard);
Status   (*XGetWindowAttributesRef)(Display *display, Window w, XWindowAttributes *window_attributes_return);
int      (*XGetWindowPropertyRef)(Display *display, Window w, Atom property, long long_offset, long long_length, Bool delete, Atom req_type, Atom *actual_type_return, int *actual_format_return, unsigned long *nitems_return, unsigned long *bytes_after_return, unsigned char **prop_return);
Atom     (*XInternAtomRef)(Display *display, char *atom_name, Bool only_if_exists);
Bool     (*XTranslateCoordinatesRef)(Display *display, Window src_w, Window dest_w, int src_x, int src_y, int *dest_x_return, int *dest_y_return, Window *child_return);
Atom    *(*XListPropertiesRef)(Display *display, Window w, int *num_prop_return);
char    *(*XGetAtomNameRef)(Display *display, Atom atom) ;
int      (*XMapWindowRef)(Display *display, Window w);
Status   (*XIconifyWindowRef)(Display *display, Window w, int screen_number);
int      (*XDefaultScreenRef)(Display *display);
int      (*XMoveWindowRef)(Display *display, Window w, int x, int y);
int      (*XResizeWindowRef)(Display *display, Window w, unsigned int width, unsigned int height);
int      (*XMoveResizeWindowRef)(Display *display, Window w, int x, int y, unsigned width, unsigned height);
int      (*XRaiseWindowRef)(Display *display, Window w);
int      (*XLowerWindowRef)(Display *display, Window w);
Status   (*XQueryTreeRef)(Display *display, Window w, Window *root_return, Window *parent_return, Window **children_return, unsigned int *nchildren_return);
Status   (*XGetWMProtocolsRef)(Display *display, Window w, Atom **protocols_return, int *count_return);
Status   (*XSendEventRef)(Display *display, Window w, Bool propagate, long event_mask, XEvent *event_send);
int      (*XKillClientRef)(Display *display, XID resource);
int      (*XSetInputFocusRef)(Display *display, Window focus, int revert_to, Time time);

// int      (*XDestroyWindowRef)(Display *display, Window w);
// int      (*XUnmapWindowRef)(Display *display, Window w);


// X11 symbols table
#define X11_SYMBOL(s) {&s##Ref,#s}
static void *X11Symbols_[][2] = {
    X11_SYMBOL(XCloseDisplay),
    X11_SYMBOL(XFree),
    X11_SYMBOL(XGetErrorText),
    X11_SYMBOL(XGetWindowAttributes),
    X11_SYMBOL(XGetWindowProperty),
    X11_SYMBOL(XInternAtom),
    X11_SYMBOL(XOpenDisplay),
    X11_SYMBOL(XSetErrorHandler),
    X11_SYMBOL(XSync),
    X11_SYMBOL(XTranslateCoordinates),
    X11_SYMBOL(XListProperties),
    X11_SYMBOL(XGetAtomName),
    X11_SYMBOL(XMapWindow),
    X11_SYMBOL(XIconifyWindow),
    X11_SYMBOL(XDefaultScreen),
    X11_SYMBOL(XMoveWindow),
    X11_SYMBOL(XResizeWindow),
    X11_SYMBOL(XMoveResizeWindow),
    X11_SYMBOL(XRaiseWindow),
    X11_SYMBOL(XLowerWindow),
    X11_SYMBOL(XQueryTree),
    X11_SYMBOL(XGetWMProtocols),
    X11_SYMBOL(XSendEvent),
    X11_SYMBOL(XKillClient),
    X11_SYMBOL(XSetInputFocus),

//     X11_SYMBOL(XDestroyWindow),
//     X11_SYMBOL(XUnmapWindow),
};
#undef X11_SYMBOL

NSString *decodeWindowGravity(int gravity) {
    switch(gravity) {
        case UnmapGravity:     return @"unmapGravity" ;
        case NorthWestGravity: return @"northWestGravity" ;
        case NorthGravity:     return @"northGravity" ;
        case NorthEastGravity: return @"northEastGravity" ;
        case WestGravity:      return @"westGravity" ;
        case CenterGravity:    return @"centerGravity" ;
        case EastGravity:      return @"eastGravity" ;
        case SouthWestGravity: return @"southWestGravity" ;
        case SouthGravity:     return @"southGravity" ;
        case SouthEastGravity: return @"southEastGravity" ;
        case StaticGravity:    return @"staticGravity" ;
        default: return [NSString stringWithFormat:@"unknown win_gravity:%d", gravity] ;
    }
}

NSString *decodeBitGravity(int gravity) {
    switch(gravity) {
        case UnmapGravity:     return @"forgetGravity" ;
        case NorthWestGravity: return @"northWestGravity" ;
        case NorthGravity:     return @"northGravity" ;
        case NorthEastGravity: return @"northEastGravity" ;
        case WestGravity:      return @"westGravity" ;
        case CenterGravity:    return @"centerGravity" ;
        case EastGravity:      return @"eastGravity" ;
        case SouthWestGravity: return @"southWestGravity" ;
        case SouthGravity:     return @"southGravity" ;
        case SouthEastGravity: return @"southEastGravity" ;
        case StaticGravity:    return @"staticGravity" ;
        default: return [NSString stringWithFormat:@"unknown bit_gravity:%d", gravity] ;
    }
}

NSObject *decodeEventMask(long mask) {
    NSMutableArray *events  = [NSMutableArray array] ;

    if (mask == NoEventMask) {
        [events addObject:@"NoEvents"] ;
    } else {
        if ((mask & KeyPressMask) == KeyPressMask)                         [events addObject:@"keyPress"] ;
        if ((mask & KeyReleaseMask) == KeyReleaseMask)                     [events addObject:@"keyRelease"] ;
        if ((mask & ButtonPressMask) == ButtonPressMask)                   [events addObject:@"buttonPress"] ;
        if ((mask & ButtonReleaseMask) == ButtonReleaseMask)               [events addObject:@"buttonRelease"] ;
        if ((mask & EnterWindowMask) == EnterWindowMask)                   [events addObject:@"enterWindow"] ;
        if ((mask & LeaveWindowMask) == LeaveWindowMask)                   [events addObject:@"leaveWindow"] ;
        if ((mask & PointerMotionMask) == PointerMotionMask)               [events addObject:@"pointerMotion"] ;
        if ((mask & PointerMotionHintMask) == PointerMotionHintMask)       [events addObject:@"pointerMotionHint"] ;
        if ((mask & Button1MotionMask) == Button1MotionMask)               [events addObject:@"button1Motion"] ;
        if ((mask & Button2MotionMask) == Button2MotionMask)               [events addObject:@"button2Motion"] ;
        if ((mask & Button3MotionMask) == Button3MotionMask)               [events addObject:@"button3Motion"] ;
        if ((mask & Button4MotionMask) == Button4MotionMask)               [events addObject:@"button4Motion"] ;
        if ((mask & Button5MotionMask) == Button5MotionMask)               [events addObject:@"button5Motion"] ;
        if ((mask & ButtonMotionMask) == ButtonMotionMask)                 [events addObject:@"buttonMotion"] ;
        if ((mask & KeymapStateMask) == KeymapStateMask)                   [events addObject:@"keymapState"] ;
        if ((mask & ExposureMask) == ExposureMask)                         [events addObject:@"exposure"] ;
        if ((mask & VisibilityChangeMask) == VisibilityChangeMask)         [events addObject:@"visibilityChange"] ;
        if ((mask & StructureNotifyMask) == StructureNotifyMask)           [events addObject:@"structureNotify"] ;
        if ((mask & ResizeRedirectMask) == ResizeRedirectMask)             [events addObject:@"resizeRedirect"] ;
        if ((mask & SubstructureNotifyMask) == SubstructureNotifyMask)     [events addObject:@"substructureNotify"] ;
        if ((mask & SubstructureRedirectMask) == SubstructureRedirectMask) [events addObject:@"substructureRedirect"] ;
        if ((mask & FocusChangeMask) == FocusChangeMask)                   [events addObject:@"focusChange"] ;
        if ((mask & PropertyChangeMask) == PropertyChangeMask)             [events addObject:@"propertyChange"] ;
        if ((mask & ColormapChangeMask) == ColormapChangeMask)             [events addObject:@"colormapChange"] ;
        if ((mask & OwnerGrabButtonMask) == OwnerGrabButtonMask)           [events addObject:@"ownerGrabButton"] ;
    }
    long remainingMasks = mask & ~(NoEventMask              | KeyPressMask             |
                                   KeyReleaseMask           | ButtonPressMask          |
                                   ButtonReleaseMask        | EnterWindowMask          |
                                   LeaveWindowMask          | PointerMotionMask        |
                                   PointerMotionHintMask    | Button1MotionMask        |
                                   Button2MotionMask        | Button3MotionMask        |
                                   Button4MotionMask        | Button5MotionMask        |
                                   ButtonMotionMask         | KeymapStateMask          |
                                   ExposureMask             | VisibilityChangeMask     |
                                   StructureNotifyMask      | ResizeRedirectMask       |
                                   SubstructureNotifyMask   | SubstructureRedirectMask |
                                   FocusChangeMask          | PropertyChangeMask       |
                                   ColormapChangeMask       | OwnerGrabButtonMask) ;
    if (remainingMasks == 0) {
        return [events copy] ; // convert mutable to immutable
    } else {
        return @{
            @"raw"          : @(mask),
            @"expanded"     : [events copy],
            @"unrecognized" : @(remainingMasks)
        } ;
    }
}

void freeDataForDecodeARGBImage(__unused void *info, const void *data, __unused size_t size) {
    free((void *)(uintptr_t)data) ;
}

NSImage *decodeARGBImage(unsigned char *data) {
    size_t pixelSize = sizeof(long) ;

    unsigned long width, height ;
    memcpy(&width, data, pixelSize) ;
    memcpy(&height, data + pixelSize, pixelSize) ;

    size_t bufferLength = width * height * pixelSize ;
    void *imageData = malloc(bufferLength) ;
    memcpy(imageData, data + pixelSize * 2, bufferLength) ;

    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, imageData, bufferLength, &freeDataForDecodeARGBImage) ;
    size_t channels         = 4 ; // A R G B
    size_t bitsPerComponent = pixelSize * 8 / channels ;
    size_t bitsPerPixel     = bitsPerComponent * channels ;
    size_t bytesPerRow      = pixelSize * width ;

    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageByteOrderDefault | kCGImageAlphaFirst ;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;

    CGImageRef iref = CGImageCreate(width,
                                    height,
                                    bitsPerComponent,
                                    bitsPerPixel,
                                    bytesPerRow,
                                    colorSpaceRef,
                                    bitmapInfo,
                                    provider,   // data provider
                                    NULL,       // decode
                                    YES,        // should interpolate
                                    renderingIntent);

    NSImage *asImage = [[NSImage alloc] initWithCGImage:iref size:NSMakeSize(width, height)] ;
    CGImageRelease(iref) ;
    CGColorSpaceRelease(colorSpaceRef) ;
    CGDataProviderRelease(provider) ;
    return asImage ;
}

NSObject *decodeWM_HINTS_flags(long flags) {
    NSMutableArray *hints = [NSMutableArray array] ;

    if ((flags & InputHint) == InputHint)               [hints addObject:@"input"] ;
    if ((flags & StateHint) == StateHint)               [hints addObject:@"state"] ;
    if ((flags & IconPixmapHint) == IconPixmapHint)     [hints addObject:@"iconPixmap"] ;
    if ((flags & IconWindowHint) == IconWindowHint)     [hints addObject:@"iconWindow"] ;
    if ((flags & IconPositionHint) == IconPositionHint) [hints addObject:@"iconPosition"] ;
    if ((flags & IconMaskHint) == IconMaskHint)         [hints addObject:@"iconMask"] ;
    if ((flags & WindowGroupHint) == WindowGroupHint)   [hints addObject:@"windowGroup"] ;
    if ((flags & XUrgencyHint) == XUrgencyHint)         [hints addObject:@"urgency"] ;


    if ((flags & ~(InputHint|StateHint|IconPixmapHint|IconWindowHint|IconPositionHint|IconMaskHint|WindowGroupHint|XUrgencyHint)) == 0) {
        return [hints copy] ; // convert mutable to immutable
    } else {
        return @{
            @"raw"           : @(flags),
            @"fieldsDefined" : [hints copy],
            @"unrecognized"  : @(flags & ~(InputHint|StateHint|IconPixmapHint|IconWindowHint|IconPositionHint|IconMaskHint|WindowGroupHint|XUrgencyHint))
        } ;
    }
}

NSString *decodeWM_HINTS_initialState(int state) {
    switch(state) {
        case WithdrawnState: return @"withdrawn" ;
        case NormalState:    return @"normal" ;
        case IconicState:    return @"iconic" ;
        // Obsolete states no longer defined by ICCCM, but include just in case
//         case DontCareState: // shares value with WithdrawnState, so ignoring
        case ZoomState:      return @"zoomed" ;
        case InactiveState:  return @"inactive" ;
        default:
            return [NSString stringWithFormat:@"unknown state: %d", state] ;
    }
}

NSDictionary *decodeWM_HINTS(long *asPropertyReturn, XWMHints *asDirectQuery) {
    NSMutableDictionary *results = [NSMutableDictionary dictionary] ;
    if (asPropertyReturn != NULL) {
        results[@"flags"]        = decodeWM_HINTS_flags(asPropertyReturn[0]) ;
        results[@"input"]        = asPropertyReturn[1] == True ? @(YES) : @(NO) ;
        results[@"initialState"] = decodeWM_HINTS_initialState((int)asPropertyReturn[2]) ;
        results[@"iconPixmap"]   = @(asPropertyReturn[3]) ;
        results[@"iconWindow"]   = @(asPropertyReturn[4]) ;
        results[@"iconPosition"] = [NSValue valueWithPoint:NSMakePoint(asPropertyReturn[5], asPropertyReturn[6])] ;
        results[@"iconMask"]     = @(asPropertyReturn[7]) ;
        results[@"windowGroup"]  = @(asPropertyReturn[8]) ;
    } else if (asDirectQuery != NULL) {
        results[@"flags"]        = decodeWM_HINTS_flags(asDirectQuery->flags) ;
        results[@"input"]        = asDirectQuery->input == True ? @(YES) : @(NO) ;
        results[@"initialState"] = decodeWM_HINTS_initialState(asDirectQuery->initial_state) ;
        results[@"iconPixmap"]   = @(asDirectQuery->icon_pixmap) ;
        results[@"iconWindow"]   = @(asDirectQuery->icon_window) ;
        results[@"iconPosition"] = [NSValue valueWithPoint:NSMakePoint(asDirectQuery->icon_x, asDirectQuery->icon_y)] ;
        results[@"iconMask"]     = @(asDirectQuery->icon_mask) ;
        results[@"windowGroup"]  = @(asDirectQuery->window_group) ;
    }
    return [results copy] ; // convert mutable to immutable
}

/* Size hints mask bits */

NSObject *decodeWM_SIZE_HINTS_flags(long flags) {
    NSMutableArray *hints = [NSMutableArray array] ;

    if ((flags & USPosition) == USPosition)   [hints addObject:@"userPosition"] ;
    if ((flags & USSize) == USSize)           [hints addObject:@"userSize"] ;
    if ((flags & PPosition) == PPosition)     [hints addObject:@"programmedPosition"] ;
    if ((flags & PSize) == PSize)             [hints addObject:@"programmedSize"] ;
    if ((flags & PMinSize) == PMinSize)       [hints addObject:@"programmedMinimumSize"] ;
    if ((flags & PMaxSize) == PMaxSize)       [hints addObject:@"programmedMaximumSize"] ;
    if ((flags & PResizeInc) == PResizeInc)   [hints addObject:@"programmedResizeIncrements"] ;
    if ((flags & PAspect) == PAspect)         [hints addObject:@"programmedAspectRatios"] ;
    if ((flags & PBaseSize) == PBaseSize)     [hints addObject:@"baseSize"] ;
    if ((flags & PWinGravity) == PWinGravity) [hints addObject:@"windowGravity"] ;


    if ((flags & ~(PPosition|PSize|PMinSize|PMaxSize|PResizeInc|PAspect)) == 0) {
        return [hints copy] ; // convert mutable to immutable
    } else {
        return @{
            @"raw"           : @(flags),
            @"fieldsDefined" : [hints copy],
            @"unrecognized"  : @(flags & ~(PPosition|PSize|PMinSize|PMaxSize|PResizeInc|PAspect))
        } ;
    }
}

NSDictionary *decodeWM_SIZE_HINTS(long *asPropertyReturn, XSizeHints *asDirectQuery) {
    NSMutableDictionary *results = [NSMutableDictionary dictionary] ;
    if (asPropertyReturn != NULL) {
        results[@"flags"]              = decodeWM_SIZE_HINTS_flags(asPropertyReturn[0]) ;
        results[@"obsoletePosition"]   = [NSValue valueWithPoint:NSMakePoint(asPropertyReturn[1], asPropertyReturn[2])] ;
        results[@"obsoleteSize"]       = [NSValue valueWithSize:NSMakeSize(asPropertyReturn[3], asPropertyReturn[4])] ;
        results[@"minimumSize"]        = [NSValue valueWithSize:NSMakeSize(asPropertyReturn[5], asPropertyReturn[6])] ;
        results[@"maximumSize"]        = [NSValue valueWithSize:NSMakeSize(asPropertyReturn[7], asPropertyReturn[8])] ;
        results[@"sizeIncrements"]     = [NSValue valueWithSize:NSMakeSize(asPropertyReturn[9], asPropertyReturn[10])] ;
        results[@"minimumAspectRatio"] = @{ @"numerator":@(asPropertyReturn[11]), @"denominator":@(asPropertyReturn[12]) } ;
        results[@"maximumAspectRatio"] = @{ @"numerator":@(asPropertyReturn[13]), @"denominator":@(asPropertyReturn[14]) } ;
        results[@"baseSize"]           = [NSValue valueWithSize:NSMakeSize(asPropertyReturn[15], asPropertyReturn[16])] ;
        results[@"windowGravity"]      = decodeWindowGravity((int)asPropertyReturn[17]) ;
    } else if (asDirectQuery != NULL) {
        results[@"flags"]              = decodeWM_SIZE_HINTS_flags(asDirectQuery->flags) ;
        results[@"obsoletePosition"]   = [NSValue valueWithPoint:NSMakePoint(asDirectQuery->x, asDirectQuery->y)] ;
        results[@"obsoleteSize"]       = [NSValue valueWithSize:NSMakeSize(asDirectQuery->width, asDirectQuery->height)] ;
        results[@"minimumSize"]        = [NSValue valueWithSize:NSMakeSize(asDirectQuery->min_width, asDirectQuery->min_height)] ;
        results[@"maximumSize"]        = [NSValue valueWithSize:NSMakeSize(asDirectQuery->max_width, asDirectQuery->max_height)] ;
        results[@"sizeIncrements"]     = [NSValue valueWithSize:NSMakeSize(asDirectQuery->width_inc, asDirectQuery->height_inc)] ;
        results[@"minimumAspectRatio"] = @{ @"numerator":@(asDirectQuery->min_aspect.x), @"denominator":@(asDirectQuery->min_aspect.y) } ;
        results[@"maximumAspectRatio"] = @{ @"numerator":@(asDirectQuery->max_aspect.x), @"denominator":@(asDirectQuery->max_aspect.y) } ;
        results[@"baseSize"]           = [NSValue valueWithSize:NSMakeSize(asDirectQuery->base_width, asDirectQuery->base_height)] ;
        results[@"windowGravity"]      = decodeWindowGravity(asDirectQuery->win_gravity) ;
    }
    return [results copy] ; // convert mutable to immutable
}

static int X11ErrorHandler(Display *dpy, XErrorEvent *err) {
    char msg[1024] ;
    XGetErrorTextRef(dpy, err->error_code, msg, sizeof(msg)) ;
    const char *lvl = "w" ;
    // as I discover which errors we can truly ignore, I'll reduce their level
    if (err->request_code == 17) { // BadAtom, usually from getProperty and we return nothing for value key
        lvl = "v" ;
    }
    [HSX11Window logLevel:lvl message:[NSString stringWithFormat:@"X11Error: %s (code: %d)", msg, err->request_code]] ;
    return 0 ;
}

int window_x11_loadLibrary(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    // if no args, just return whether or not the library has been loaded yet
    if (lua_gettop(L) == 0) {
        if (X11Lib_ != NULL) {
            lua_pushboolean(L, YES) ;
            return 1 ;
        } else {
            lua_pushboolean(L, NO) ;
            lua_pushstring(L, "no library currently loaded") ;
            return 2 ;
        }
    }

    [skin checkArgs:LS_TSTRING, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *libPath = [skin toNSObjectAtIndex:1] ;
    BOOL     testOnly = lua_gettop(L) > 1 ? (BOOL)(lua_toboolean(L, 2)) : NO ;

    // if not testing a new path, and we've already loaded a library, bail
    if (X11Lib_ != NULL && !testOnly) {
        lua_pushboolean(L, NO) ;
        lua_pushstring(L, "valid library already loaded") ;
        return 2 ;
    }

    // if library isn't accessible to user, bail
    if (access(libPath.UTF8String, X_OK) != 0) {
        lua_pushboolean(L, NO) ;
        lua_pushstring(L, strerror(errno)) ;
        return 2 ;
    }

    // if library can't be loaded, bail
    void *libBlob = dlopen(libPath.UTF8String, RTLD_LOCAL | RTLD_NOW) ;
    if (!libBlob) {
        lua_pushboolean(L, NO) ;
        lua_pushstring(L, dlerror()) ;
        return 2 ;
    }

    // now check symbols
    char *err = NULL;
    for (size_t i=0; i<sizeof(X11Symbols_)/sizeof(X11Symbols_[0]); i++) {
        void *func = dlsym(libBlob, X11Symbols_[i][1]) ;
        if ((err = dlerror()) != NULL) {
            dlclose(libBlob) ;
            lua_pushboolean(L, NO) ;
            lua_pushfstring(L, "unable to resolve symbol %s: %s",  X11Symbols_[i][1], err) ;
            return 2 ;
        } else if (!testOnly) {
            *(void **)(X11Symbols_[i][0]) = func ;
        }
    }

    // we made it this far, so it's a valid library; cleanup and return true
    if (testOnly) {
        dlclose(libBlob) ;
    } else {
        // actually unnecessary, but maybe someday we'll allow swapping them out?
        if (X11Lib_ != NULL) dlclose(X11Lib_) ;
        X11Lib_ = libBlob ;
        XSetErrorHandlerRef(&X11ErrorHandler) ;
    }
    lua_pushboolean(L, YES) ;
    return 1 ;
}
