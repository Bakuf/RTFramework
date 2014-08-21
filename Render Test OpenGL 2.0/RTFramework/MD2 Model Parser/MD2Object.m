//
//  MD2Object.m
//  Render Test OpenGL 2.0
//
//  Created by Bakuf on 4/12/14.
//  Copyright (c) 2014 Bakuf Soft. All rights reserved.
//

#import "MD2Object.h"
#include <sys/time.h>
#import <mach/mach.h>

#define NUMVERTEXNORMALS        162
#define SHADEDOT_QUANT          16

static MD2Vector anorms_table[ NUMVERTEXNORMALS ] = {
#include    "anorms.h"
};

MD2Animation const MD2AnimationStand = { 0,  39,  9 };
MD2Animation const MD2AnimationRun = {  40,  46, 10 };
MD2Animation const MD2AnimationAttack = {  47,  53, 10 };
MD2Animation const MD2AnimationPainA = {  54,  57,  7 };
MD2Animation const MD2AnimationPainB = {  58,  61,  7 };
MD2Animation const MD2AnimationPainC = {  62,  65,  7 };
MD2Animation const MD2AnimationJump = {  66,  71,  7 };
MD2Animation const MD2AnimationFlip = {  72,  83,  7 };
MD2Animation const MD2AnimationSalute = {  84,  94,  7 };
MD2Animation const MD2AnimationFallBack = {  95, 111, 10 };
MD2Animation const MD2AnimationWave = { 112, 122,  7 };
MD2Animation const MD2AnimationPoint = { 123, 134,  6 };
MD2Animation const MD2AnimationCrouchStand = { 135, 153, 10 };
MD2Animation const MD2AnimationCrouchWalk = { 154, 159,  7 };
MD2Animation const MD2AnimationCrouchAttack = { 160, 168, 10 };
MD2Animation const MD2AnimationCrouchPain = { 196, 172,  7 };
MD2Animation const MD2AnimationCrouchDeath = { 173, 177,  5 };
MD2Animation const MD2AnimationDeathFallBack = { 178, 183,  7 };
MD2Animation const MD2AnimationDeathFallForward = { 184, 189,  7 };
MD2Animation const MD2AnimationDeathFallBackSlow = { 190, 197,  7 };
MD2Animation const MD2AnimationBoom = { 198, 198,  5 };

@interface MD2Object () {
    NSString *theTexturePath;
    BOOL paused;
}

@property (strong, nonatomic) GLKBaseEffect *effect;

@end


@implementation MD2Object

#pragma mark Properties

@synthesize animation=_animation, fpsScale=_fpsScale, effect = _effect;

//Animation Properties
@dynamic fps;
@synthesize tickCount=_tickCount, deltaTime=_deltaTime, time=_timeAccumulator;

/****************************************************************************************************
 *	setAnimation:
 ****************************************************************************************************/

- (void) setAnimation:(MD2Animation)animation
{
	_animation = animation;
	_nextFrame = _animation.firstFrame;
}

#pragma mark Public methods

/****************************************************************************************************
 *	loadMD2:
 ****************************************************************************************************/

- (void) loadMD2WithContentsOfFile:(NSString *)path texturePath:(NSString*)texturePath
{
    [super loadMD2WithContentsOfFile:path texturePath:texturePath];
    NSData *data = [NSData dataWithContentsOfFile:path];
	theTexturePath = texturePath;
    _oldTime = 0;
    _currentFrame = 0;
    _nextFrame = 1;
    _fpsScale = 1;
    
    [data getBytes:&_header length:sizeof(MD2Header)];
    
    if( _header.identifier != MD2_MAGIC_NUMBER || _header.version != MD2_VERSION)
        return;
    
    size_t skinsSize = _header.skinCount * sizeof(MD2TexturePath);
    size_t textureCoordinatesSize = _header.textureCoordinateCount * sizeof(MD2TextureCoordinate);
    size_t trianglesSize = _header.triangleCount * sizeof(MD2Triangle);
    size_t framesSize = _header.frameCount * sizeof(MD2Frame);
    
    _skins = malloc( skinsSize);
    _textureCoordinates = malloc( textureCoordinatesSize);
    _triangles = malloc( trianglesSize);
    _frames = malloc( framesSize);
    MD2Vertex *vertexBuffer = malloc( _header.vertexCount * sizeof(MD2Vertex));
    
    if( !_skins || !_textureCoordinates || !_triangles || !_frames || !vertexBuffer)
    {
        if( _skins) free( _skins);
        if( _textureCoordinates) free( _textureCoordinates);
        if( _triangles) free( _triangles);
        if( _frames) free( _frames);
        if( vertexBuffer) free( vertexBuffer);
        NSLog(@"Couldn't allocate memory");
        return;
    }
    
    [data getBytes:_skins range:(NSRange){ _header.skinsOffset, skinsSize}];
    [data getBytes:_textureCoordinates range:(NSRange){ _header.textureCoordinatesOffset, textureCoordinatesSize}];
    [data getBytes:_triangles range:(NSRange){ _header.trianglesOffset, trianglesSize}];
    
    size_t verticesSize = _header.triangleCount * sizeof(GLVertex) * 3;
    NSRange range = { _header.framesOffset, sizeof(MD2Vector)};
    BOOL couldntAllocateFrame = NO;
    MD2Vector frameScale;
    MD2Vector frameTranslate;
    MD2Vertex *md2Vertex;
    GLVertex *glVertex;
    MD2TextureCoordinate *textureCoordinate;
    NSInteger i, j, k;
    NSInteger frameLimit = _header.frameCount;
    for( i=0; i<_header.frameCount; i++)
    {
        _frames[i].vertices = malloc( verticesSize);
        if( !_frames[i].vertices) //|| get_current_memory() > 70)
        {
            frameLimit = i;
            couldntAllocateFrame = YES;
            break;
        }
        
        range.length = sizeof(MD2Vector);
        [data getBytes:&frameScale range:range];
        range.location += range.length;
        
        [data getBytes:&frameTranslate range:range];
        range.location += range.length;
        
        range.length = sizeof(MD2FrameName);
        [data getBytes:_frames[ i].name range:range];
        range.location += range.length;
        
        range.length = _header.vertexCount * sizeof(MD2Vertex);
        [data getBytes:vertexBuffer range:range];
        range.location += range.length;
        
        for( j=0; j<_header.triangleCount; j++)
        {
            for( k=0; k<3; k++)
            {
                md2Vertex = &vertexBuffer[ _triangles[j].vertexIndices[k]];
                textureCoordinate = &_textureCoordinates[ _triangles[j].textureCoordinateIndices[k]];
                
                glVertex = &_frames[i].vertices[j*3+k];
                glVertex->position.x = (frameScale[0] * md2Vertex->xyz[0]) + frameTranslate[0];
                glVertex->position.y = (frameScale[1] * md2Vertex->xyz[1]) + frameTranslate[1];
                glVertex->position.z = (frameScale[2] * md2Vertex->xyz[2]) + frameTranslate[2];
                glVertex->textureCoords.x = (GLfloat) textureCoordinate->s / _header.skinWidth;
                glVertex->textureCoords.y = (GLfloat) textureCoordinate->t / _header.skinHeight;
                glVertex->normal.x = anorms_table[ md2Vertex->lightnormalindex][0];
                glVertex->normal.y = anorms_table[ md2Vertex->lightnormalindex][1];
                glVertex->normal.z = anorms_table[ md2Vertex->lightnormalindex][2];
            }
        }
    }
    free( vertexBuffer);
    
    _vertices = malloc( verticesSize);
    
    if( couldntAllocateFrame || !_vertices)
    {
        for( i=0; i<_header.frameCount; i++)
        {
            if( _frames[i].vertices && i < frameLimit)
                free( _frames[i].vertices);
        }
        free( _skins);
        free( _textureCoordinates);
        free( _triangles);
        free( _frames);
        NSLog(@"Couldn't allocate memory");
        return;
    }
    
    memcpy( _vertices, _frames[0].vertices, verticesSize);
    
    MD2Animation const MD2AnimationFull = { 0, _header.frameCount, 10};
    self.animation = MD2AnimationFull;
    
    //Animation Method
    [self reset];
}

int get_current_memory(void) {
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(),
                                   TASK_BASIC_INFO,
                                   (task_info_t)&info,
                                   &size);
    if( kerr == KERN_SUCCESS ) {
        NSLog(@"Memory in use (in bytes): %u (in MB): %u", info.resident_size,(info.resident_size / (1024*1024)));
    } else {
        NSLog(@"Error with task_info(): %s", mach_error_string(kerr));
    }
    return (info.resident_size / (1024*1024));
}

void report_memory(void) {
    static unsigned last_resident_size=0;
    static unsigned greatest = 0;
    static unsigned last_greatest = 0;
    
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(),
                                   TASK_BASIC_INFO,
                                   (task_info_t)&info,
                                   &size);
    if( kerr == KERN_SUCCESS ) {
        int diff = (int)info.resident_size - (int)last_resident_size;
        unsigned latest = info.resident_size;
        if( latest > greatest   )   greatest = latest;  // track greatest mem usage
        int greatest_diff = greatest - last_greatest;
        int latest_greatest_diff = latest - greatest;
        NSLog(@"Mem: %10u (%10d) : %10d :   greatest: %10u (%d)", info.resident_size, diff,latest_greatest_diff, greatest, greatest_diff  );
    } else {
        NSLog(@"Error with task_info(): %s", mach_error_string(kerr));
    }
    last_resident_size = info.resident_size;
    last_greatest = greatest;
}

/****************************************************************************************************
 *	doTick:
 ****************************************************************************************************/

- (void) doTick:(float)time
{
    
    if (_header.frameCount <= 1 || paused) {
        return;
    }
    
	MD2Animation anim = self.animation;
	float fps = anim.fps * self.fpsScale;
	
	if( time - _oldTime > 1.0 / fps)
	{
		_currentFrame = _nextFrame;
		_nextFrame++;
		_oldTime = time;
	}
	
	if( _currentFrame >= anim.lastFrame)
		_currentFrame = anim.firstFrame;
    
	if( _nextFrame >= anim.lastFrame)
		_nextFrame = anim.firstFrame;
	
	float alpha = fps * (time - _oldTime);
	GLVertex *currentVertices = _frames[_currentFrame].vertices;
	GLVertex *nextVertices = _frames[_nextFrame].vertices;
	
	NSInteger vertexCount = _header.triangleCount * 3;
	for( NSInteger i=0; i<vertexCount; i++)
	{
		_vertices[i].position.x = currentVertices[i].position.x + alpha * (nextVertices[i].position.x - currentVertices[i].position.x);
		_vertices[i].position.y = currentVertices[i].position.y + alpha * (nextVertices[i].position.y - currentVertices[i].position.y);
		_vertices[i].position.z = currentVertices[i].position.z + alpha * (nextVertices[i].position.z - currentVertices[i].position.z);
		_vertices[i].normal.x = currentVertices[i].normal.x + alpha * (nextVertices[i].normal.x - currentVertices[i].normal.x);
		_vertices[i].normal.y = currentVertices[i].normal.y + alpha * (nextVertices[i].normal.y - currentVertices[i].normal.y);
		_vertices[i].normal.z = currentVertices[i].normal.z + alpha * (nextVertices[i].normal.z - currentVertices[i].normal.z);
	}
}

- (void) pauseOrUnpause{
    if (paused){
        paused = NO;
    }else{
        paused = YES;
    }
}

/****************************************************************************************************
 *	dealloc
 ****************************************************************************************************/

- (void) deallocInContext:(EAGLContext*)currentContext
{
	for( NSInteger i=0; i<_header.frameCount; i++)
		free( _frames[i].vertices);
	free( _skins);
	free( _textureCoordinates);
	free( _triangles);
	free( _frames);
	free( _vertices);
    self.effect = nil;
    
    [EAGLContext setCurrentContext:currentContext];
	
}

/****************************************************************************************************
 *	description
 ****************************************************************************************************/

- (NSString *) description
{
	NSLog(@"desc called");
	NSString *s = @"\nMD2:\n\tskin width: %d\n\tskin height: %d\n\tframes: %d\n\tskins: %d\n\tvertices: %d\n\ttex coords: %d\n\ttris: %d\n\tgl commands: %d";
	return [NSString stringWithFormat:s, _header.skinWidth,
										_header.skinHeight,
										_header.frameCount,
										_header.skinCount,
										_header.vertexCount,
										_header.textureCoordinateCount,
										_header.triangleCount,
										_header.glCommandCount];
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
    NSDictionary* options = @{ GLKTextureLoaderOriginBottomLeft: @NO , GLKTextureLoaderApplyPremultiplication : @YES};
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
    [self tick];
    [self doTick:self.time];

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    glDepthMask( GL_TRUE );
    
    [self.effect prepareToDraw];
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLVertex), (const GLvoid *) &_vertices[0].position);
    
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(GLVertex), (const GLvoid *) &_vertices[0].textureCoords);
    
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, sizeof(GLVertex), (const GLvoid *) &_vertices[0].normal);
    
    glDrawArrays( GL_TRIANGLES, 0, _header.triangleCount * 3);
    
    glDisable(GL_BLEND);
}


#pragma mark Animation Methods

/****************************************************************************************************
 *	fps
 ****************************************************************************************************/

- (float) fps
{
	if ( _fpsAccumulator > 0.25)
	{
		_fps = _fpsTickCount/_fpsAccumulator;
		_fpsTickCount = 0;
		_fpsAccumulator = 0.0f;
	}
	
	return _fps;
}

/****************************************************************************************************
 *	reset
 ****************************************************************************************************/

- (void) reset
{
	_tickCount = 0;
	_deltaTime = 0.0f;
	_timeAccumulator = 0.0f;
	_fps = 0.0f;
	_fpsTickCount = 0;
	_fpsAccumulator = 0.0f;
	
	NSAssert( gettimeofday( &_previousTickTimeVal, NULL) == 0, @"gettimeofday error");
}

/****************************************************************************************************
 *	tick
 ****************************************************************************************************/

- (void) tick
{
	struct timeval now;
	NSAssert( gettimeofday( &now, NULL) == 0, @"gettimeofday error");
	
	_deltaTime = (now.tv_sec - _previousTickTimeVal.tv_sec) + (now.tv_usec - _previousTickTimeVal.tv_usec) / 1000000.0f;
	_deltaTime = MAX( 0, _deltaTime);
	_timeAccumulator += _deltaTime;
	
	_fpsTickCount++;
	_fpsAccumulator += _deltaTime;
	
	_previousTickTimeVal = now;
	_tickCount++;
}

@end
