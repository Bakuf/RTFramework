//
//  RTMatrixData.h
//  Render Test OpenGL 2.0
//
//  Created by Bakuf on 4/16/14.
//  Copyright (c) 2014 Bakuf Soft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>

@interface RTMatrixData : NSObject

@property (nonatomic) GLKMatrix4 modelViewMatrix;
@property (nonatomic) GLKMatrix4 projectionMatrix;

@end
