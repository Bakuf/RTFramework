//
//  RTImageObject.m
//  Render Test OpenGL 2.0
//
//  Created by Bakuf on 4/16/14.
//  Copyright (c) 2014 Bakuf Soft. All rights reserved.
//

#import "RTAudioObject.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#define NUM_QUAD_VERTEX 4
#define NUM_QUAD_INDEX 6


static const float quadVertices[NUM_QUAD_VERTEX * 3] =
{
    -1.00f,  -1.00f,  0.0f,
    1.00f,  -1.00f,  0.0f,
    1.00f,   1.00f,  0.0f,
    -1.00f,   1.00f,  0.0f,
};

//static const float quadTexCoords[NUM_QUAD_VERTEX * 2] =
//{
//    0, 0,
//    1, 0,
//    1, 1,
//    0, 1,
//};

static const float quadNormals[NUM_QUAD_VERTEX * 3] =
{
    0, 0, 1,
    0, 0, 1,
    0, 0, 1,
    0, 0, 1,
    
};

static const unsigned short quadIndices[NUM_QUAD_INDEX] =
{
    0,  1,  2,  0,  2,  3,
};


// Image quad texture coordinates
const GLfloat musicImageQuadTextureCoords[] = {
    0.0, 1.0,
    1.0, 1.0,
    1.0, 0.0,
    0.0, 0.0,
};

@interface RTAudioObject(){
    float aspectRatioX;
    float aspectRatioY;
    
    GLKVector2 targetPositiveDimensions;
    
    AVAudioPlayer *player;
}

@property (strong, nonatomic) GLKBaseEffect *effect;

@end

@implementation RTAudioObject

- (void) prepareAudioWithFilePath:(NSString *)filePath{
    [super prepareAudioWithFilePath:filePath];
    
    NSURL *soundFileURL = [NSURL fileURLWithPath:filePath];
    
    player = [[AVAudioPlayer alloc] initWithContentsOfURL:soundFileURL error:nil];
    player.numberOfLoops = 1;
    [player play];
}

- (void)pause{
    if ([player isPlaying]){
        [player pause];
    }
}

- (void) pauseOrUnpause{
    if ([player isPlaying]){
        [player pause];
    }else{
        [player play];
    }
}

- (void) deallocInContext:(EAGLContext*)currentContext{
    NSLog(@"dealloc in image object");
    self.effect = nil;
}

/****************************************************************************************************
 *	setupForRenderGL
 ****************************************************************************************************/

- (void) setupForRenderGLInContext:(EAGLContext*)currentContext
{
    [EAGLContext setCurrentContext:currentContext];
    
    self.effect = [[GLKBaseEffect alloc] init];
    
    // Texture
    NSDictionary* options = @{ GLKTextureLoaderOriginBottomLeft: @NO };
    NSError* error;
    GLKTextureInfo* texture = [GLKTextureLoader textureWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Music-Note" ofType:@"png"] options:options error:&error];
    
    self.effect.texture2d0.name = texture.name;
    self.effect.texture2d0.enabled = true;
    
    
    targetPositiveDimensions.x = ([UIScreen mainScreen].bounds.size.width/2) / 2;
    targetPositiveDimensions.y = ([UIScreen mainScreen].bounds.size.height/2) / 2;
    
    aspectRatioX = (float)texture.width / (float)texture.height;
    aspectRatioY = (float)texture.height / (float)texture.width;
	
}

- (void)setupViewProjectionToShader:(GLKMatrix4)viewProjection{
    self.effect.transform.projectionMatrix = viewProjection;
}

- (void)setupModelViewMatrixToShader:(GLKMatrix4)modelViewMatrix{
    self.effect.transform.modelviewMatrix = modelViewMatrix;
}

/****************************************************************************************************
 *	renderGL
 ****************************************************************************************************/

- (void) renderGL
{
    
    glEnable(GL_DEPTH_TEST);
    
    // If the current status is valid (not NOT_READY or ERROR), render the
    // video quad with the texture we've just selected
    GLKMatrix4 modelViewMatrixImage = self.effect.transform.modelviewMatrix;
    
    modelViewMatrixImage = GLKMatrix4Scale(modelViewMatrixImage, targetPositiveDimensions.x, targetPositiveDimensions.x * aspectRatioY, targetPositiveDimensions.x);
        
    self.effect.transform.modelviewMatrix = modelViewMatrixImage;
        
    [self.effect prepareToDraw];
        
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, quadVertices);
        
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, 0, quadNormals);
    
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, 0, musicImageQuadTextureCoords);
       
    glDrawElements(GL_TRIANGLES, NUM_QUAD_INDEX, GL_UNSIGNED_SHORT, quadIndices);
    
}


@end
