//
//  RTObject.h
//  Render Test OpenGL 2.0
//
//  Created by Bakuf on 4/16/14.
//  Copyright (c) 2014 Bakuf Soft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>

typedef enum {
    RTObjectTypeImage,
    RTObjectTypeVideo,
    RTObjectTypeAudio,
    RTObjectTypeMD2Model
}RTObjectType;

@interface RTObject : NSObject

@property (nonatomic, assign) RTObjectType objectType;
@property (nonatomic, assign) float objectScale;
@property (nonatomic, assign) int objectPosX;
@property (nonatomic, assign) int objectPosY;
@property (nonatomic, assign) int objectPosZ;


- (void) setupForRenderGLInContext:(EAGLContext*)currentContext;
- (void) deallocInContext:(EAGLContext*)currentContext;

- (void) setupViewProjectionToShader:(GLKMatrix4)viewProjection;
- (void) setupModelViewMatrixToShader:(GLKMatrix4)modelViewMatrix;

- (void) pauseOrUnpause;

- (void) renderGL;

//Methods for VideoObject
- (void) preparePlayerWithFilePath:(NSString*)filePath andRootViewController:(UIViewController*)rootViewController;

- (void) videoOnFullScreen;

//Methods for MD2Object
- (void) loadMD2WithContentsOfFile:(NSString *)path texturePath:(NSString*)texturePath;

//Methods for Image
- (void) prepareImageWithFilePath:(NSString*)filePath;

//Methods for Audio
- (void) prepareAudioWithFilePath:(NSString*)filePath;

@end
