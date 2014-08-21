//
//  RTVideoObject.h
//  Render Test OpenGL 2.0
//
//  Created by Bakuf on 4/15/14.
//  Copyright (c) 2014 Bakuf Soft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>
#import "VideoPlayerHelper.h"
#import "RTObject.h"

@interface RTVideoObject : RTObject{
    float videoPlaybackTime;
}

@property (nonatomic, strong) VideoPlayerHelper* videoPlayer;

@end
