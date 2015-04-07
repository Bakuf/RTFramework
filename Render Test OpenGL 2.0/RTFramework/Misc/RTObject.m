//
//  RTObject.m
//  Render Test OpenGL 2.0
//
//  Created by Bakuf on 4/16/14.
//  Copyright (c) 2014 Bakuf Soft. All rights reserved.
//

#import "RTObject.h"

@implementation RTObject

@synthesize objectType;

- (void) setupForRenderGLInContext:(EAGLContext*)currentContext{
    
}

- (void) deallocInContext:(EAGLContext*)currentContext{
    
}

- (void) setupViewProjectionToShader:(GLKMatrix4)viewProjection{
    
}

- (void) setupModelViewMatrixToShader:(GLKMatrix4)modelViewMatrix{
    
}

- (void) pauseOrUnpause{
    
}

- (void) renderGL{
    
}

//Methods for VideoObject
- (void) preparePlayerWithFilePath:(NSString*)filePath andRootViewController:(UIViewController*)rootViewController{
    objectType = RTObjectTypeVideo;
    [self resetPositionAndScale];
}

- (void) videoOnFullScreen{
    
}

//Methods for MD2Object
- (void) loadMD2WithContentsOfFile:(NSString *)path texturePath:(NSString*)texturePath{
    objectType = RTObjectTypeMD2Model;
    [self resetPositionAndScale];
}

//Methods for OBJObject
- (void) loadOBJWithContentsOfFile:(NSString *)path texturePath:(NSString*)texturePath{ 
    objectType = RTObjectTypeOBJModel;
    [self resetPositionAndScale];
}

//Methods for ImageObject
- (void) prepareImageWithFilePath:(NSString*)filePath{
    objectType = RTObjectTypeImage;
    [self resetPositionAndScale];
}

//Methods for AudioObject
- (void) prepareAudioWithFilePath:(NSString*)filePath;{
    objectType = RTObjectTypeAudio;
    [self resetPositionAndScale];
}


- (void)resetPositionAndScale{
    self.objectPosX = 0;
    self.objectPosY = 0;
    self.objectPosZ = -100;
    self.objectScale = 1.0;
}

@end
