//
//  RTImageObject.m
//  Render Test OpenGL 2.0
//
//  Created by Bakuf on 4/16/14.
//  Copyright (c) 2014 Bakuf Soft. All rights reserved.
//

#import "RTImageObject.h"

#define NUM_QUAD_VERTEX 4
#define NUM_QUAD_INDEX 6


static const float quadVertices[NUM_QUAD_VERTEX * 3] =
{
    -1.00f,  -1.00f,  0.0f,
    1.00f,  -1.00f,  0.0f,
    1.00f,   1.00f,  0.0f,
    -1.00f,   1.00f,  0.0f,
};

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

const GLfloat imageQuadTextureCoords[] = {
    0.0, 1.0,
    1.0, 1.0,
    1.0, 0.0,
    0.0, 0.0,
};

@interface RTImageObject(){
    NSString *imagePath;
    
    float aspectRatioX;
    float aspectRatioY;
    
    GLKVector2 targetPositiveDimensions;
}

@property (strong, nonatomic) GLKBaseEffect *effect;

@end

@implementation RTImageObject

- (void) prepareImageWithFilePath:(NSString*)filePath{
    [super prepareImageWithFilePath:filePath];
    imagePath = filePath;
}

- (void) deallocInContext:(EAGLContext*)currentContext{
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
    GLKTextureInfo* texture = [GLKTextureLoader textureWithContentsOfFile:imagePath options:options error:&error];
    
    self.effect.texture2d0.name = texture.name;
    self.effect.texture2d0.enabled = true;
    self.effect.texture2d0.envMode = GLKTextureEnvModeReplace;
    
    
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
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    GLKMatrix4 modelViewMatrixImage = self.effect.transform.modelviewMatrix;
    
    modelViewMatrixImage = GLKMatrix4Scale(modelViewMatrixImage, targetPositiveDimensions.x, targetPositiveDimensions.x * aspectRatioY, targetPositiveDimensions.x);
        
    self.effect.transform.modelviewMatrix = modelViewMatrixImage;
        
    [self.effect prepareToDraw];
        
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, quadVertices);
        
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, 0, quadNormals);
    
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, 0, imageQuadTextureCoords);
       
    glDrawElements(GL_TRIANGLES, NUM_QUAD_INDEX, GL_UNSIGNED_SHORT, quadIndices);
    
    glDisable(GL_BLEND);
}


@end
