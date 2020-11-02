#pragma once

@import Cocoa ;
@import LuaSkin ;

// make sure this does not collide with the Cursor from Carbon/Cocoa
#define Cursor X11Cursor

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wreserved-id-macro"
#pragma clang diagnostic ignored "-Wauto-import"
#import <X11/Xlib.h>
#import <X11/Xatom.h>
#import <X11/Xutil.h>

// see https://specifications.freedesktop.org/wm-spec/wm-spec-latest.html
#pragma clang diagnostic ignored "-Wunused-macros"
#define _NET_WM_STATE_REMOVE 0
#define _NET_WM_STATE_ADD    1
#define _NET_WM_STATE_TOGGLE 2
#pragma clang diagnostic pop

#undef Cursor

extern const char * const USERDATA_TAG ;
extern NSString *defaultDisplayString ;

// not null if the X11 functions have been loaded
extern void     *X11Lib_ ;

// X11 function pointers
extern Display *(*XOpenDisplayRef)(char *display_name);
extern int      (*XCloseDisplayRef)(Display *display);
extern int      (*XFreeRef)(void *data);
extern int      (*XSetErrorHandlerRef)(int (*handler)(Display *, XErrorEvent *));
extern int      (*XGetErrorTextRef)(Display *display, int code, char *buffer_return, int length);
extern int      (*XSyncRef)(Display *display, Bool discard);
extern Status   (*XGetWindowAttributesRef)(Display *display, Window w, XWindowAttributes *window_attributes_return);
extern int      (*XGetWindowPropertyRef)(Display *display, Window w, Atom property, long long_offset, long long_length, Bool delete, Atom req_type, Atom *actual_type_return, int *actual_format_return, unsigned long *nitems_return, unsigned long *bytes_after_return, unsigned char **prop_return);
extern Atom     (*XInternAtomRef)(Display *display, char *atom_name, Bool only_if_exists);
extern Bool     (*XTranslateCoordinatesRef)(Display *display, Window src_w, Window dest_w, int src_x, int src_y, int *dest_x_return, int *dest_y_return, Window *child_return);
extern Atom    *(*XListPropertiesRef)(Display *display, Window w, int *num_prop_return);
extern char    *(*XGetAtomNameRef)(Display *display, Atom atom) ;
extern int      (*XMapWindowRef)(Display *display, Window w);
extern Status   (*XIconifyWindowRef)(Display *display, Window w, int screen_number);
extern int      (*XDefaultScreenRef)(Display *display);
extern int      (*XMoveWindowRef)(Display *display, Window w, int x, int y);
extern int      (*XResizeWindowRef)(Display *display, Window w, unsigned int width, unsigned int height);
extern int      (*XMoveResizeWindowRef)(Display *display, Window w, int x, int y, unsigned width, unsigned height);
extern int      (*XRaiseWindowRef)(Display *display, Window w);
extern int      (*XLowerWindowRef)(Display *display, Window w);
extern Status   (*XQueryTreeRef)(Display *display, Window w, Window *root_return, Window *parent_return, Window **children_return, unsigned int *nchildren_return);
extern Status   (*XGetWMProtocolsRef)(Display *display, Window w, Atom **protocols_return, int *count_return);
extern Status   (*XSendEventRef)(Display *display, Window w, Bool propagate, long event_mask, XEvent *event_send);
extern int      (*XKillClientRef)(Display *display, XID resource);
extern int      (*XSetInputFocusRef)(Display *display, Window focus, int revert_to, Time time);

// extern int      (*XDestroyWindowRef)(Display *display, Window w);
// extern int      (*XUnmapWindowRef)(Display *display, Window w);

extern int window_x11_loadLibrary(lua_State *L) ;
