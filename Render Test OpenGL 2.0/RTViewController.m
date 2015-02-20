//
//  RTViewController.m
//  Render Test OpenGL 2.0
//
//  Created by Bakuf on 4/16/14.
//  Copyright (c) 2014 Bakuf Soft. All rights reserved.
//

#import "RTViewController.h"
//#import "CameraViewController.h"
#import "RTRenderVC.h"
#import "MD2Object.h"
#import "RTVideoObject.h"
#import "RTImageObject.h"
#import "RTAudioObject.h"


@interface RTViewController () <UIGestureRecognizerDelegate>

@property (weak, nonatomic) IBOutlet UIView *cameraView;
@property (weak, nonatomic) IBOutlet UIView *contentView;

//@property (strong, nonatomic) CameraViewController *cameraVC;
@property (strong, nonatomic) RTRenderVC *renderVC;

@end

@implementation RTViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    
//    _cameraVC = [[CameraViewController alloc] init];
//    _cameraVC.view.frame = _cameraView.frame;
//    [_cameraView addSubview:_cameraVC.view];
    
    // Do any additional setup after loading the view from its nib.
    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureDetected:)];
    [tapGestureRecognizer setDelegate:self];
    tapGestureRecognizer.numberOfTapsRequired = 1;
    [self.view addGestureRecognizer:tapGestureRecognizer];
    
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(targetDetected:) name:@"vuforiaDetectedTarget" object:nil];
}

- (void)tapGestureDetected:(UITapGestureRecognizer*)recognizer{
    //[_cameraVC enterScanningMode];
    [self targetDetected:nil];
}

- (void)targetDetected:(NSNotification*)notif{
    if (!_renderVC) {
        
        NSMutableArray *objectArray = [[NSMutableArray alloc] init];
        
        MD2Object *md2Blade = [[MD2Object alloc] init];
        NSString *modelPath = [[NSBundle mainBundle] pathForResource:@"Blade.md2" ofType:nil inDirectory:@"RTResources/Md2 Models"];
        NSString *modelTexture = [[NSBundle mainBundle] pathForResource:@"Blade.jpg" ofType:nil inDirectory:@"RTResources/Md2 Models"];
        [md2Blade loadMD2WithContentsOfFile:modelPath texturePath:modelTexture];
        [objectArray addObject:md2Blade];
        
        _renderVC = [[RTRenderVC alloc] initWithObjectsArray:objectArray];
        [_contentView addSubview:_renderVC.view];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
