//
//  RTVideoObject.m
//  Render Test OpenGL 2.0
//
//  Created by Bakuf on 4/15/14.
//  Copyright (c) 2014 Bakuf Soft. All rights reserved.
//

#import "RTVideoObject.h"

#define NUM_QUAD_VERTEX 4
#define NUM_QUAD_INDEX 6


static const float quadVertices[NUM_QUAD_VERTEX * 3] =
{
    -1.00f,  -1.00f,  0.0f,
    1.00f,  -1.00f,  0.0f,
    1.00f,   1.00f,  0.0f,
    -1.00f,   1.00f,  0.0f,
};

static const float quadTexCoords[NUM_QUAD_VERTEX * 2] =
{
    0, 0,
    1, 0,
    1, 1,
    0, 1,
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

// --- Data private to this unit ---
// Augmentation model scale factor
const float kObjectScale = 3.0f;

enum tagObjectIndex {
    OBJECT_PLAY_ICON,
    OBJECT_BUSY_ICON,
    OBJECT_ERROR_ICON,
};

const NSTimeInterval DOUBLE_TAP_INTERVAL = 0.3f;
const NSTimeInterval TRACKING_LOST_TIMEOUT = 2.0f;

// Playback icon scale factors
const float SCALE_ICON = 2.0f;
const float SCALE_ICON_TRANSLATION = 1.98f;

// Video quad texture coordinates
const GLfloat videoQuadTextureCoords[] = {
    0.0, 1.0,
    1.0, 1.0,
    1.0, 0.0,
    0.0, 0.0,
};

struct tagVideoData {
    // Needed to calculate whether a screen tap is inside the target
    GLKMatrix4 modelViewMatrix;
    
    // Trackable dimensions
    GLKVector2 targetPositiveDimensions;
    
    // Currently active flag
    BOOL isActive;
} videoData;

int touchedTarget = 0;

@interface RTVideoObject () {
    GLuint playIcon;
    GLuint errorIcon;
    GLuint busyIcon;
}

@property (strong, nonatomic) GLKBaseEffect *effect;

@end

@implementation RTVideoObject

@synthesize videoPlayer;

- (void) preparePlayerWithFilePath:(NSString*)filePath andRootViewController:(UIViewController*)rootViewController{
    [super preparePlayerWithFilePath:filePath andRootViewController:rootViewController];
    videoPlayer = [[VideoPlayerHelper alloc] initWithRootViewController:rootViewController];
    videoData.targetPositiveDimensions.x = ([UIScreen mainScreen].bounds.size.width/2) / 2;
    videoData.targetPositiveDimensions.y = ([UIScreen mainScreen].bounds.size.height/2) / 2;
    
    // Start video playback from the current position (the beginning)
    videoPlaybackTime = VIDEO_PLAYBACK_CURRENT_POSITION;
    
    if (NO == [videoPlayer load:filePath playImmediately:NO fromPosition:videoPlaybackTime]) {
        NSLog(@"Failed to load media");
    }

}

- (void) pauseOrUnpause{
    if ([self.videoPlayer getStatus] == PLAYING){
        [self.videoPlayer pause];
    }else{
        [self.videoPlayer play:NO fromPosition:[self.videoPlayer getCurrentPosition]];
    }
}

- (void) videoOnFullScreen{
    if (PLAYING_FULLSCREEN != [videoPlayer getStatus]) {
        // Get the state of the video player for the target the user touched
        MEDIA_STATE mediaState = [videoPlayer getStatus];
        
        // If any on-texture video is playing, pause it
        if (PLAYING == [videoPlayer getStatus]) {
            [videoPlayer pause];
        }

        // For the target the user touched
        if (ERROR != mediaState && NOT_READY != mediaState && PLAYING != mediaState) {
            // Play the video
            NSLog(@"Playing video with on-texture player");
            [videoPlayer play:NO fromPosition:VIDEO_PLAYBACK_CURRENT_POSITION];
        }
    }
}

- (void) deallocInContext:(EAGLContext*)currentContext{
    [videoPlayer unload];
    videoPlayer = nil;
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
    NSArray *icons = @[@"icon_play",@"icon_loading",@"icon_error"];
    for (int i = 0; i < icons.count; i++) {
        NSDictionary* options = @{ GLKTextureLoaderOriginBottomLeft: @NO };
        NSError* error;
        GLKTextureInfo* texture = [GLKTextureLoader textureWithContentsOfFile:[[NSBundle mainBundle] pathForResource:icons[i] ofType:@"png"] options:options error:&error];
        
        if(texture == nil) {
            NSLog(@"Error loading file: %@", [error localizedDescription]);
        }else{
            switch (i) {
                case 0:
                    playIcon = texture.name;
                    break;
                    
                case 1:
                    errorIcon = texture.name;
                    break;
                
                case 2:
                    busyIcon = texture.name;
                    break;
                    
                default:
                    break;
            }
        }
    }
    self.effect.texture2d0.enabled = true;
	
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
    
    // Mark this video (target) as active
    videoData.isActive = YES;
    
    float aspectRatio = 1.0f;
    const GLvoid* texCoords = NULL;
    GLuint frameTextureID;
    BOOL displayVideoFrame = YES;
    
    // Retain value between calls
    static GLuint videoTextureID = {0};
    
    MEDIA_STATE currentStatus = [videoPlayer getStatus];
    
    // NSLog(@"MEDIA_STATE for %d is %d", playerIndex, currentStatus);
    
    // --- INFORMATION ---
    // One could trigger automatic playback of a video at this point.  This
    // could be achieved by calling the play method of the VideoPlayerHelper
    // object if currentStatus is not PLAYING.  You should also call
    // getStatus again after making the call to play, in order to update the
    // value held in currentStatus.
    // --- END INFORMATION ---
    
    switch (currentStatus) {
        case PLAYING: {
            // Upload the decoded video data for the latest frame to OpenGL
            // and obtain the video texture ID
            GLuint videoTexID = [videoPlayer updateVideoData];
            
            if (0 == videoTextureID) {
                videoTextureID = videoTexID;
            }
            
            // Fallthrough
        }
        case PAUSED:
            if (0 == videoTextureID) {
                // No video texture available, display keyframe
                displayVideoFrame = NO;
            }
            else {
                // Display the texture most recently returned from the call
                // to [videoPlayerHelper updateVideoData]
                frameTextureID = videoTextureID;
            }
            
            break;
            
        default:
            videoTextureID = 0;
            displayVideoFrame = NO;
            break;
    }
    
    if (YES == displayVideoFrame) {
        // ---- Display the video frame -----
        aspectRatio = (float)[videoPlayer getVideoHeight] / (float)[videoPlayer getVideoWidth];
        texCoords = videoQuadTextureCoords;
    }
    
    self.effect.texture2d1.enabled = false;
    // If the current status is valid (not NOT_READY or ERROR), render the
    // video quad with the texture we've just selected
    GLKMatrix4 modelViewMatrixVideo = self.effect.transform.modelviewMatrix;
    if (NOT_READY != currentStatus) {
        
        modelViewMatrixVideo = GLKMatrix4Scale(modelViewMatrixVideo, videoData.targetPositiveDimensions.x, videoData.targetPositiveDimensions.x * aspectRatio, videoData.targetPositiveDimensions.x);
        
        self.effect.transform.modelviewMatrix = modelViewMatrixVideo;
        
        [self.effect prepareToDraw];
        
        glEnableVertexAttribArray(GLKVertexAttribPosition);
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, quadVertices);
        
        glEnableVertexAttribArray(GLKVertexAttribNormal);
        glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, 0, quadNormals);
        
        if (displayVideoFrame) {
            glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
            glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, 0, texCoords);
            
            self.effect.texture2d0.name = frameTextureID;
        }
    
        glDrawElements(GL_TRIANGLES, NUM_QUAD_INDEX, GL_UNSIGNED_SHORT, quadIndices);
        
    }
    
    // If the current status is not PLAYING, render an icon
    if (PLAYING != currentStatus) {
        GLuint iconTextureID;
        
        switch (currentStatus) {
            case READY:
            case REACHED_END:
            case PAUSED:
            case STOPPED: {
                // ----- Display play icon -----
                iconTextureID = playIcon;
                break;
            }
                
            case ERROR: {
                // ----- Display error icon -----
                iconTextureID = errorIcon;
                break;
            }
                
            default: {
                // ----- Display busy icon -----
                iconTextureID = busyIcon;
                break;
            }
        }
        
        glDepthFunc(GL_LEQUAL);
        
        // Blend the icon over the background
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        
        self.effect.transform.modelviewMatrix = modelViewMatrixVideo;
        self.effect.texture2d1.enabled = true;
        self.effect.texture2d1.name = iconTextureID;
        self.effect.texture2d1.envMode = GLKTextureEnvModeReplace;
        [self.effect prepareToDraw];
        
        glEnableVertexAttribArray(GLKVertexAttribPosition);
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, quadVertices);
        
        glEnableVertexAttribArray(GLKVertexAttribNormal);
        glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, 0, quadNormals);
        
        glEnableVertexAttribArray(GLKVertexAttribTexCoord1);
        glVertexAttribPointer(GLKVertexAttribTexCoord1, 2, GL_FLOAT, GL_FALSE, 0, quadTexCoords);
        
        glDrawElements(GL_TRIANGLES, NUM_QUAD_INDEX, GL_UNSIGNED_SHORT, quadIndices);
        
        glDisable(GL_BLEND);
        
        glDepthFunc(GL_LESS);
    }
   
}

@end
