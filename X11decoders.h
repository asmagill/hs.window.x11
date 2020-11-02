#pragma once

@import Cocoa ;

#import "X11interface.h"

extern NSString *decodeWindowGravity(int gravity) ;
extern NSString *decodeBitGravity(int gravity) ;
extern NSObject *decodeEventMask(long mask) ;
extern NSImage *decodeARGBImage(unsigned char *data) ;
extern NSObject *decodeWM_HINTS_flags(long flags) ;
extern NSString *decodeWM_HINTS_initialState(int state) ;
extern NSDictionary *decodeWM_HINTS(long *asPropertyReturn, XWMHints *asDirectQuery) ;
extern NSObject *decodeWM_SIZE_HINTS_flags(long flags) ;
extern NSDictionary *decodeWM_SIZE_HINTS(long *asPropertyReturn, XSizeHints *asDirectQuery) ;
