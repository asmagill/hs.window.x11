#pragma once

@import Cocoa ;
@import LuaSkin ;

#import "X11interface.h"
#import "X11decoders.h"

NS_ASSUME_NONNULL_BEGIN

@interface HSX11Window : NSObject
@property (nonatomic, readonly) long pid;
// @property (nonatomic, readonly) AXUIElementRef elementRef;
@property (nonatomic, readonly) Window winID;
// @property (nonatomic, readonly) HSuielement *uiElement;
@property (nonatomic) int selfRefCount ;

@property (nonatomic, readonly, getter=title) NSString *title;
@property (nonatomic, readonly, getter=role) NSString *role;
@property (nonatomic, readonly, getter=subRole) NSString *subRole;
@property (nonatomic, readonly, getter=isStandard) BOOL isStandard;
@property (nonatomic, getter=getTopLeft, setter=setTopLeft:) NSPoint topLeft;
@property (nonatomic, getter=getSize, setter=setSize:) NSSize size;
@property (nonatomic, getter=isFullscreen, setter=setFullscreen:) BOOL fullscreen;
@property (nonatomic, getter=isMinimized, setter=setMinimized:) BOOL minimized;
// @property (nonatomic, getter=getApplication) id application;
@property (nonatomic, readonly, getter=getZoomButtonRect) NSRect zoomButtonRect;
// @property (nonatomic, readonly, getter=getTabCount) int tabCount;

// Properties not in HSUICore
@property (class, nonatomic, readonly) int loggerRef ;
@property (nonatomic, nullable, readonly) NSString *displayString ;

// Class methods
+(NSArray<NSNumber *>*)orderedWindowIDs;
// +(NSImage *)snapshotForID:(int)windowID keepTransparency:(BOOL)keepTransparency;
+(instancetype)focusedWindow;

// Class methods not in HSUICore
+(int)loggerRef;
+(void)recordLoggerRef:(int)ref;
+(void)logLevel:(const char *)lvl message:(NSString *)message;
+(instancetype)rootWindow;
+(id)_getProperty:(nullable const char *)atomString forWindow:(Window)winID ofDisplay:(Display *)dpy withDetails:(BOOL)details;

// Initialiser
-(instancetype)initWithWindowRef:(Window)winID withDisplayString:(nullable NSString *)displayString;

// Destructor
// -(void)dealloc;

// Instance methods
-(NSString *)title;
-(NSString *)subRole;
-(NSString *)role;
-(BOOL)isStandard;
-(NSPoint)getTopLeft;
-(void)setTopLeft:(NSPoint)topLeft;
-(NSSize)getSize;
-(void)setSize:(NSSize)size;
// -(BOOL)pushButton:(CFStringRef)buttonId; // n/a
-(void)toggleZoom;
// -(NSRect)getZoomButtonRect;
-(BOOL)close;
// -(BOOL)focusTab:(int)index;
// -(int)getTabCount;
-(BOOL)isFullscreen;
-(void)setFullscreen:(BOOL)fullscreen;
-(BOOL)isMinimized;
-(void)setMinimized:(BOOL)minimize;
// -(id)getApplication;
-(void)becomeMain;
-(void)raise;
// -(NSImage *)snapshot:(BOOL)keepTransparency;

// Instance methods not in HSUICore
// -(void)lower;
-(id)_getProperty:(nullable const char *)atomString;
-(NSDictionary *)_getPropertyList;
-(NSDictionary *)_getWindowAttributes;
-(NSDictionary *)_queryTree;
-(NSArray *)_getProtocolList;
-(BOOL)WMsupports:(const char *)hintName;
-(BOOL)supportsAction:(const char *)actionName;
-(BOOL)supportsProtocol:(const char *)protocolName;
@end

NS_ASSUME_NONNULL_END
