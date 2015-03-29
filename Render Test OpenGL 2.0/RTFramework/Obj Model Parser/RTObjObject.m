//
//  RTObjObject.m
//  Render Test OpenGL 2.0
//
//  Created by Bakuf on 3/28/15.
//  Copyright (c) 2015 Bakuf Soft. All rights reserved.
//

#import "RTObjObject.h"
#import "RTObjParser.h"

@interface RTObjObject (){
    RTObjParser objParser;
    NSString *theTexturePath;
    BOOL paused;
}

@property (strong, nonatomic) GLKBaseEffect *effect;

@end

@implementation RTObjObject

- (void)loadOBJWithContentsOfFile:(NSString *)path texturePath:(NSString *)texturePath{
    
    [super loadOBJWithContentsOfFile:path texturePath:texturePath];
    theTexturePath = texturePath;
    
    objParser.init();
    objParser.processObjFile(*new std::string([path UTF8String]));
    
    NSLog(@"OBJECT PARSED!!!");
    objParser.printPositionData();
    objParser.printTextureData();
    objParser.printNormalData();
}

/****************************************************************************************************
 *	dealloc
 ****************************************************************************************************/

- (void) deallocInContext:(EAGLContext*)currentContext
{
    self.effect = nil;
    
    [EAGLContext setCurrentContext:currentContext];
    
}

/****************************************************************************************************
 *	description
 ****************************************************************************************************/

- (NSString *) description
{
    NSLog(@"desc called");
    NSString *s = @"\nObj:\n\tfaces: %d\n\tvertices: %d\n\tpositions: %d\n\ttextels: %d\n\tnormals: %d\n";
    return [NSString stringWithFormat:s,
            objParser.model.faces,
            objParser.model.vertices,
            objParser.model.positions,
            objParser.model.texels,
            objParser.model.normals];
    return @"";
}

#pragma mark GLRenderable methods

/****************************************************************************************************
 *	setupForRenderGL
 ****************************************************************************************************/

- (void) setupForRenderGLInContext:(EAGLContext*)currentContext
{
    
    [EAGLContext setCurrentContext:currentContext];
    
    self.effect = [[GLKBaseEffect alloc] init];
    
    // Texture
    NSDictionary* options = @{ GLKTextureLoaderOriginBottomLeft: @YES};
    NSError* error;
    GLKTextureInfo* texture = [GLKTextureLoader textureWithContentsOfFile:theTexturePath options:options error:&error];
    
    if(texture == nil)
        NSLog(@"Error loading file: %@", [error localizedDescription]);
    
    self.effect.texture2d0.name = texture.name;
    self.effect.texture2d0.enabled = true;
    self.effect.texture2d0.envMode = GLKTextureEnvModeReplace;
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
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    glDepthMask( GL_TRUE );
    
    [self.effect prepareToDraw];
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, (const GLvoid *) &objParser.positionData[0]);
    
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, 0, (const GLvoid *) &objParser.textureData[0]);
    
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, 0, (const GLvoid *) &objParser.normalData[0]);
    
    glDrawArrays( GL_TRIANGLES, 0, objParser.model.vertices);
    
    glDisable(GL_BLEND);
}

@end
