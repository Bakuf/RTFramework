//
//  RTRenderVC.m
//  Render Test OpenGL 2.0
//
//  Created by Bakuf on 4/12/14.
//  Copyright (c) 2014 Bakuf Soft. All rights reserved.
//

#import "RTRenderVC.h"
#import "RTMatrixData.h"

@interface RTRenderVC (){
    float _rotationX;
    float _rotationZ;
    float _lastRotationX;
    float _lastRotationZ;
    
    CGFloat _scale;
    CGFloat _lastScale;
    
    GLKView *glView;
    
    NSArray *objectArray;
    
    RTMatrixData *matrixData;
    
    BOOL clearable;
    BOOL withTouches;
    BOOL allreadyclear;
}

@property (nonatomic, strong) EAGLContext *context;

@end

@implementation RTRenderVC

- (id)initWithObjectsArray:(NSArray*)theObjectsArray{
    self = [super init];
    if (self) {
        objectArray = theObjectsArray;
    }
    return self;
}

- (void)loadView{
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    glView = [[GLKView alloc] initWithFrame:[[UIScreen mainScreen] bounds] context:self.context];
    glView.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    glView.drawableMultisample = GLKViewDrawableMultisample4X;
    
    [self setView:glView];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor clearColor];
    self.view.opaque = NO;
    
    for (int i = 0; i < objectArray.count; i++) {
        RTObject *object = objectArray[i];
        [object setupForRenderGLInContext:self.context];
    }
    
    [self clearAllData];
    
    [self initGestureRecognizers];
    
    
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                          selector:@selector(orientationChanged:)name:@"UIDeviceOrientationDidChangeNotification"
                                               object:nil ];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateMatrixs:) name:@"vuforiaMatrix" object:nil];
    
}

-(void)orientationChanged:(NSNotification *)object{
    //UIDeviceOrientation deviceOrientation = [[object object] orientation];
    [self.view setNeedsDisplay];
}

- (void)viewDidUnload
{
    [super viewDidUnload];

    [self removeAllGestures];
    
    
    for (int i = 0; i < objectArray.count; i++) {
        RTObject *object = objectArray[i];
        [object deallocInContext:self.context];
    }
    objectArray = nil;
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
    self.context = nil;
}


- (void)updateMatrixs:(NSNotification*)notif{
    if (notif.userInfo[@"matrixData"]) {
        matrixData = notif.userInfo[@"matrixData"];
        clearable = YES;
    }else{
        if (clearable) {
            [self clearAllData];
        }
    }
}

- (void)clearAllData{
    matrixData = nil;
    _scale = 1.0f;
    _lastScale = 0.0f;
    _rotationX = 0;
    _rotationZ = 0;
    _lastRotationX = 0;
    _lastRotationZ = 0;
    clearable = NO;
}

#pragma mark - GLKViewDelegate

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {

    //[glView bindDrawable];
    //glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    for (int i = 0; i < objectArray.count; i++) {
        RTObject *object = objectArray[i];
        [object renderGL];
    }

}

#pragma mark - GLKViewControllerDelegate

- (void)update {
   
    if (matrixData) {
        for (int i = 0; i < objectArray.count; i++) {
            RTObject *object = objectArray[i];
            [object setupViewProjectionToShader:matrixData.projectionMatrix];
            [object setupModelViewMatrixToShader:matrixData.modelViewMatrix];
        }
    }else{
        //Projection Matrix
        float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
        GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(45.0f), aspect, 2.0f, 5000.0f);
        
        for (int i = 0; i < objectArray.count; i++) {
            RTObject *object = objectArray[i];
            [object setupViewProjectionToShader:projectionMatrix];
            
            // ModelView Matrix
            GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
             modelViewMatrix = GLKMatrix4Translate(modelViewMatrix, object.objectPosX, object.objectPosY, object.objectPosZ);
            modelViewMatrix = GLKMatrix4Scale(modelViewMatrix, 1.0f * _scale,1.0f * _scale, 1.0f * _scale);
            modelViewMatrix = GLKMatrix4RotateX(modelViewMatrix, GLKMathDegreesToRadians(_rotationX));
            modelViewMatrix = GLKMatrix4RotateZ(modelViewMatrix, GLKMathDegreesToRadians(_rotationZ));
           
            [object setupModelViewMatrixToShader:modelViewMatrix];
        }
        
    }
    
}

#pragma mark gesture recornizer methods

- (void)initGestureRecognizers{
    UITapGestureRecognizer *doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapGestureDetected:)];
    [doubleTapGestureRecognizer setDelegate:self];
    doubleTapGestureRecognizer.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:doubleTapGestureRecognizer];
    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureDetected:)];
    [tapGestureRecognizer setDelegate:self];
    tapGestureRecognizer.numberOfTapsRequired = 1;
    [tapGestureRecognizer requireGestureRecognizerToFail:doubleTapGestureRecognizer];
    [self.view addGestureRecognizer:tapGestureRecognizer];
    
    UIPinchGestureRecognizer *pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchGestureDetected:)];
    [pinchGestureRecognizer setDelegate:self];
    [self.view addGestureRecognizer:pinchGestureRecognizer];
    
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureDetected:)];
    [panGestureRecognizer setDelegate:self];
    [self.view addGestureRecognizer:panGestureRecognizer];
    
}

- (void)removeAllGestures{
    for (UIGestureRecognizer *gest in self.view.gestureRecognizers) {
        [self.view removeGestureRecognizer:gest];
    }
}

- (void)tapGestureDetected:(UITapGestureRecognizer*)recognizer{
    for (int i = 0; i < objectArray.count; i++) {
        RTObject *object = objectArray[i];
        [object pauseOrUnpause];
    }
}

- (void)doubleTapGestureDetected:(UITapGestureRecognizer*)recognizer{
    for (int i = 0; i < objectArray.count; i++) {
        RTObject *object = objectArray[i];
        if (object.objectType == RTObjectTypeVideo) {
            [object videoOnFullScreen];
        }
    }
}

- (void)pinchGestureDetected:(UIPinchGestureRecognizer *)recognizer
{
    UIGestureRecognizerState state = [recognizer state];
    
    if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged)
    {
        _scale = [recognizer scale] + _lastScale;
        //NSLog(@"current scale : %f",_scale);
    }
    if (state == UIGestureRecognizerStateEnded) {
        if (_scale < 1.0f) {
            _lastScale = - 1.0 + _scale;
        }
        if (_scale > 1.0f) {
            _lastScale = _scale - 1.0;
        }
    }
}

- (void)panGestureDetected:(UIPanGestureRecognizer *)recognizer
{
    UIGestureRecognizerState state = [recognizer state];
    
    if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged)
    {
        CGPoint translation = [recognizer translationInView:recognizer.view];
        _rotationZ = translation.x + _lastRotationZ;
        _rotationX = translation.y + _lastRotationX;
        
        //NSLog(@"rotation X : %f",_rotationX);
        //NSLog(@"rotation Z : %f",_rotationZ);
    }
    if (state == UIGestureRecognizerStateEnded) {
        _lastRotationX = _rotationX;
        _lastRotationZ = _rotationZ;
    }
}

@end
