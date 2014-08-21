//
//  RTRenderVC.h
//  Render Test OpenGL 2.0
//
//  Created by Bakuf on 4/12/14.
//  Copyright (c) 2014 Bakuf Soft. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import "RTObject.h"

@interface RTRenderVC : GLKViewController <UIGestureRecognizerDelegate>

- (id)initWithObjectsArray:(NSArray*)theObjectsArray;

@end
