//
//  HBNTTerminalSessionViewController.h
//  NewTerm
//
//  Created by Adam D on 12/12/2014.
//  Copyright (c) 2014 HASHBANG Productions. All rights reserved.
//

@import UIKit;
@import iTerm2;

@class HBNTServer, VT100ColorMap;

@interface HBNTTerminalSessionViewController : UIViewController <ScreenBufferRefreshDelegate>

- (instancetype)initWithServer:(HBNTServer *)server;

- (void)readInputStream:(NSData *)data;
- (void)clearScreen;

@property (strong, nonatomic, readonly) HBNTServer *server;
@property (strong, nonatomic, readonly) UITextView *textView;

@property (strong, nonatomic) UIFont *font;
@property (strong, nonatomic) VT100ColorMap *colorMap;

@property (readonly) int screenWidth;
@property (readonly) int screenHeight;

@end
