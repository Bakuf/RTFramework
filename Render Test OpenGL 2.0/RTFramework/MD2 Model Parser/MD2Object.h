//
//  MD2Object.h
//  Render Test OpenGL 2.0
//
//  Created by Bakuf on 4/12/14.
//  Copyright (c) 2014 Bakuf Soft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>
#import "Types3D.h"
#import "RTObject.h"

#define MD2_MAGIC_NUMBER	844121161
#define MD2_VERSION		8

// ---- MD2 Types ------------------------------//

typedef struct
{
	int identifier;
	int version;
	int skinWidth;
	int skinHeight;
	int frameSize;
	int skinCount;
	int vertexCount;
	int textureCoordinateCount;
	int triangleCount;
	int glCommandCount;
	int frameCount;
	int skinsOffset;
	int textureCoordinatesOffset;
	int trianglesOffset;
	int framesOffset;
	int glCommandsOffset;
	int eofOffset;
} MD2Header;

typedef float MD2Vector[3];

typedef char MD2TexturePath[64];

typedef struct
{
	unsigned char xyz[3];
	unsigned char lightnormalindex;
} MD2Vertex;

typedef struct
{
	short s;
	short t;
} MD2TextureCoordinate;

typedef struct
{
	short vertexIndices[3];
	short textureCoordinateIndices[3];
} MD2Triangle;

typedef char MD2FrameName[16];

typedef struct
{
	MD2FrameName name;
	GLVertex *vertices;
} MD2Frame;

typedef struct
{
	int firstFrame;
	int lastFrame;
	float fps;
} MD2Animation;



// ---- Standard Quake animations ---------------//

extern MD2Animation const KEMD2AnimationStand;
extern MD2Animation const KEMD2AnimationRun;
extern MD2Animation const KEMD2AnimationAttack;
extern MD2Animation const KEMD2AnimationPainA;
extern MD2Animation const KEMD2AnimationPainB;
extern MD2Animation const KEMD2AnimationPainC;
extern MD2Animation const KEMD2AnimationJump;
extern MD2Animation const KEMD2AnimationFlip;
extern MD2Animation const KEMD2AnimationSalute;
extern MD2Animation const KEMD2AnimationFallBack;
extern MD2Animation const KEMD2AnimationWave;
extern MD2Animation const KEMD2AnimationPoint;
extern MD2Animation const KEMD2AnimationCrouchStand;
extern MD2Animation const KEMD2AnimationCrouchWalk;
extern MD2Animation const KEMD2AnimationCrouchAttack;
extern MD2Animation const KEMD2AnimationCrouchPain;
extern MD2Animation const KEMD2AnimationCrouchDeath;
extern MD2Animation const KEMD2AnimationDeathFallBack;
extern MD2Animation const KEMD2AnimationDeathFallForward;
extern MD2Animation const KEMD2AnimationDeathFallBackSlow;
extern MD2Animation const KEMD2AnimationBoom;

// ---- Class Interface --------------------------//

@interface MD2Object : RTObject
{
	MD2Header _header;
	MD2TexturePath *_skins;
	MD2TextureCoordinate *_textureCoordinates;
	MD2Triangle *_triangles;
	MD2Frame *_frames;
	MD2Animation _animation;
	float _oldTime;
	float _fpsScale;
	NSInteger _currentFrame;
	NSInteger _nextFrame;
	
	GLVertex *_vertices;
    
    //Animation
    struct timeval _previousTickTimeVal;
	NSInteger _tickCount;
	float _deltaTime;
	float _timeAccumulator;
	float _fps;
	NSInteger _fpsTickCount;
	float _fpsAccumulator;
}

@property (nonatomic, readwrite, assign) MD2Animation animation;
@property (nonatomic, readwrite, assign) float fpsScale;


//Animation Properites
@property (nonatomic, readonly, assign) NSInteger tickCount;			// number of ticks so far
@property (nonatomic, readonly, assign) float deltaTime;				// number of seconds since last tick
@property (nonatomic, readonly, assign) float time;					// number of seconds so far
@property (nonatomic, readonly, assign) float fps;

//- (void) loadMD2WithContentsOfFile:(NSString *)path texturePath:(NSString*)texturePath;
//
//- (void) setupForRenderGLInContext:(EAGLContext*)currentContext;
//- (void) renderGL;
//
//- (void) setupViewProjectionToShader:(GLKMatrix4)viewProjection;
//- (void) setupModelViewMatrixToShader:(GLKMatrix4)modelViewMatrix;
//
//- (void) deallocInContext:(EAGLContext*)currentContext;

@end
