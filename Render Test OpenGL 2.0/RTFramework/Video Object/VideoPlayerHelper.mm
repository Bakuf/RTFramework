/*==============================================================================
 Copyright (c) 2012-2013 Qualcomm Connected Experiences, Inc.
 All Rights Reserved.
 ==============================================================================*/

#import "VideoPlayerHelper.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AudioServices.h>

#ifdef DEBUG
#define DEBUGLOG(x) NSLog(x)
#else
#define DEBUGLOG(x)
#endif
#define DEBUGLOG(x) NSLog(x)

// Constants
static const int TIMESCALE = 1000;  // 1 millisecond granularity for time

static const float PLAYER_CURSOR_POSITION_MEDIA_START = 0.0f;
static const float PLAYER_CURSOR_REQUEST_COMPLETE = -1.0f;

static const float PLAYER_VOLUME_DEFAULT = 1.0f;

// The number of bytes per texel (when using kCVPixelFormatType_32BGRA)
static const int BYTES_PER_TEXEL = 4;


// Key-value observation contexts
static void* AVPlayerItemStatusObservationContext = &AVPlayerItemStatusObservationContext;
static void* AVPlayerRateObservationContext = &AVPlayerRateObservationContext;

// String constants
static NSString* const kStatusKey = @"status";
static NSString* const kTracksKey = @"tracks";
static NSString* const kRateKey = @"rate";


@interface VideoPlayerHelper (PrivateMethods)
- (void)resetData;
- (BOOL)loadLocalMediaFromURL:(NSURL*)url;
- (BOOL)prepareAssetForPlayback;
- (BOOL)prepareAssetForReading:(CMTime)startTime;
- (void)prepareAVPlayer;
- (void)createFrameTimer;
- (void)getNextVideoFrame;
- (void)updatePlayerCursorPosition:(float)position;
- (void)frameTimerFired:(NSTimer*)timer;
- (BOOL)setVolumeLevel:(float)volume;
- (GLuint)createVideoTexture;
- (void)doSeekAndPlayAudio;
- (void)waitForFrameTimerThreadToEnd;
- (void)moviePlayerLoadStateChanged:(NSNotification*)notification;
- (void)moviePlayerPlaybackDidFinish:(NSNotification*)notification;
- (void)moviePlayerDidExitFullscreen:(NSNotification*)notification;
- (void)moviePlayerExitAtPosition:(NSTimeInterval)position;
@end


//------------------------------------------------------------------------------
#pragma mark - MovieViewController

@implementation MovieViewController

//------------------------------------------------------------------------------
#pragma mark - Lifecycle

- (id)init
{
    self = [super init];
    
    if (nil != self) {
        _moviePlayer = [[MPMoviePlayerController alloc] init];
    }
    
    return self;
}


- (void)dealloc
{
//    [_moviePlayer release];
//    
//    [super dealloc];
}


- (void)loadView
{
    [self setView:_moviePlayer.view];
}


//------------------------------------------------------------------------------
#pragma mark - Autorotation
- (NSUInteger)supportedInterfaceOrientations
{
    // iOS >= 6
    return UIInterfaceOrientationMaskAll;
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    // iOS < 6
    return YES;
}

@end


//------------------------------------------------------------------------------
#pragma mark - VideoPlayerHelper

@implementation VideoPlayerHelper

//------------------------------------------------------------------------------
#pragma mark - Lifecycle
- (id)initWithRootViewController:(UIViewController *) viewController
{
    self = [super init];
    
    if (nil != self) {
        // Set up app's audio session
        rootViewController = viewController;

        // **********************************************************************
        // *** MUST DO THIS TO BE ABLE TO GET THE VIDEO SAMPLES WITHOUT ERROR ***
        // **********************************************************************
        AudioSessionInitialize(NULL, NULL, NULL, NULL);
        UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
        OSStatus status = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory);
        assert(kAudioSessionNoError == status);
        UInt32 setProperty = 1;
        status = AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryMixWithOthers, sizeof(setProperty), &setProperty);
        assert(kAudioSessionNoError == status);
        
        // Initialise data
        [self resetData];
        
        // Video sample buffer lock
        latestSampleBufferLock = [[NSLock alloc] init];
        latestSampleBuffer = NULL;
        currentSampleBuffer = NULL;
        
        // Class data lock
        dataLock = [[NSLock alloc] init];
        
    }
    
    return self;
}


- (void)dealloc
{
    // Stop playback
    (void)[self stop];
    [self resetData];
//    [latestSampleBufferLock release];
//    [dataLock release];
//    [super dealloc];
}


//------------------------------------------------------------------------------
#pragma mark - Class API
// Load a movie
- (BOOL)load:(NSString*)filename playImmediately:(BOOL)playOnTextureImmediately fromPosition:(float)seekPosition
{
//    (void)AudioSessionSetActive(true);
    BOOL ret = NO;
    
    // Load only if there is no media currently loaded
    if (NOT_READY != mediaState && ERROR != mediaState) {
        NSLog(@"Media already loaded.  Unload current media first.");
    }
    else {
        // ----- Info: additional player threads not running at this point -----
        
        // Determine the type of file that has been requested (simply checking
        // for the presence of a "://" in filename for remote files)
        if (NSNotFound == [filename rangeOfString:@"://"].location) {
            // For on texture rendering, we need a local file
            localFile = YES;
            NSString* fullPath = nil;
            
            // If filename is an absolute path (starts with a '/'), use it as is
            if (0 == [filename rangeOfString:@"/"].location) {
                fullPath = [NSString stringWithString:filename];
            }
            else {
                // filename is a relative path, play media from this app's
                // resources folder
                fullPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:filename];
            }
            
            mediaURL = [[NSURL alloc] initFileURLWithPath:fullPath];
            
            if (YES == playOnTextureImmediately) {
                playImmediately = playOnTextureImmediately;
            }
            
            if (0.0f <= seekPosition) {
                // If a valid position has been requested, update the player
                // cursor, which will allow playback to begin from the
                // correct position
                [self updatePlayerCursorPosition:seekPosition];
            }
            
            ret = [self loadLocalMediaFromURL:mediaURL];
        }
        else {
            // FULLSCREEN only
            localFile = NO;
            
            mediaURL = [[NSURL alloc] initWithString:filename];
            
            // The media is actually loaded when we initialise the
            // MPMoviePlayerController, which happens when we start playback
            mediaState = READY;
            
            ret = YES;
        }
    }
    
    if (NO == ret) {
        // Some error occurred
        mediaState = ERROR;
    }
    
    return ret;
}


// Unload the movie
- (BOOL)unload
{
//    (void)AudioSessionSetActive(false);
    
    // Stop playback
    [self stop];
    [self resetData];
    
    return YES;
}


// Indicates whether the movie is playable on texture
- (BOOL)isPlayableOnTexture
{
    // We can render local files on texture
    return localFile;
}


// Indicates whether the movie is playable in fullscreen mode
- (BOOL)isPlayableFullscreen
{
    // We can play both local and remote files in fullscreen mode
    return YES;
}


// Get the current player state
- (MEDIA_STATE)getStatus
{
    return mediaState;
}


// Get the height of the video (on-texture player only)
- (int)getVideoHeight
{
    int ret = -1;
    
    // Return information only for local files
    if ([self isPlayableOnTexture]) {
        if (NOT_READY > mediaState) {
            ret = videoSize.height;
        }
        else {
            NSLog(@"Video height not available in current state");
        }
    }
    else {
        NSLog(@"Video height available only for video that is playable on texture");
    }
    
    return ret;
}


// Get the width of the video (on-texture player only)
- (int)getVideoWidth
{
    int ret = -1;
    
    // Return information only for local files
    if ([self isPlayableOnTexture]) {
        if (NOT_READY > mediaState) {
            ret = videoSize.width;
        }
        else {
            NSLog(@"Video width not available in current state");
        }
    }
    else {
        NSLog(@"Video width available only for video that is playable on texture");
    }
    
    return ret;
}


// Get the length of the media (on-texture player only)
- (float)getLength
{
    float ret = -1.0f;
    
    // Return information only for local files
    if ([self isPlayableOnTexture]) {
        if (NOT_READY > mediaState) {
            ret = (float)videoLengthSeconds;
        }
        else {
            NSLog(@"Video length not available in current state");
        }
    }
    else {
        NSLog(@"Video length available only for video that is playable on texture");
    }
    
    return ret;
}


// Play the asset
- (BOOL)play:(BOOL)fullscreen fromPosition:(float)seekPosition
{
    BOOL ret = NO;
    
    int requestedPlayerType = YES == fullscreen ? PLAYER_TYPE_NATIVE : PLAYER_TYPE_ON_TEXTURE;
    
    // If switching player type or not currently playing, and not in an unknown
    // or error state
    if ((PLAYING != mediaState || playerType != requestedPlayerType) && NOT_READY > mediaState) {
        if (PLAYER_TYPE_NATIVE == requestedPlayerType) {
            BOOL playingOnTexture = YES;
            
            if (PLAYING == mediaState) {
                // Pause the on-texture player
                [self pause];
                playingOnTexture = YES;
            }
            
            // ----- Info: additional player threads not running at this point -----
            
            // Use an MPMoviePlayerController to play the media, owned by our
            // own MovieViewContrllerClass
            movieViewController = [[MovieViewController alloc] init];

            // Set up observations
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(moviePlayerPlaybackDidFinish:)
                                                         name:MPMoviePlayerPlaybackDidFinishNotification
                                                       object:movieViewController.moviePlayer];
            
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(moviePlayerLoadStateChanged:)
                                                         name:MPMoviePlayerLoadStateDidChangeNotification
                                                       object:movieViewController.moviePlayer];
            
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(moviePlayerDidExitFullscreen:)
                                                         name:MPMoviePlayerDidExitFullscreenNotification
                                                       object:movieViewController.moviePlayer];
            
            if (YES == localFile) {
                // Playback state will reflect the current on-texture playback
                // state (playback will be started, if required, when the media
                // has loaded)
                [movieViewController.moviePlayer setShouldAutoplay:NO];
                
                if (0.0f <= seekPosition) {
                    // If a valid position has been requested, update the player
                    // cursor, which will allow playback to begin from the
                    // correct position (it will be set when the media has
                    // loaded)
                    [self updatePlayerCursorPosition:seekPosition];
                }
                
                if (YES == playingOnTexture) {
                    // Store the fact that video was playing on texture when
                    // fullscreen playback was requested
                    resumeOnTexturePlayback = YES;
                }
            }
            else {
                // Always start playback of remote files from the beginning
                [self updatePlayerCursorPosition:PLAYER_CURSOR_POSITION_MEDIA_START];
                
                // Play as soon as enough data is buffered
                [movieViewController.moviePlayer setShouldAutoplay:YES];
            }
            
            // Set the movie player's content URL and prepare to play
            [movieViewController.moviePlayer setContentURL:mediaURL];
            [movieViewController.moviePlayer prepareToPlay];
            
            // Present the MovieViewController in the root view controller
            [rootViewController presentViewController:movieViewController animated:YES completion:^(void){}];
            
            mediaState = PLAYING_FULLSCREEN;
            
            ret = YES;
        }
        // On texture playback available only for local files
        else if (YES == localFile) {
            // ----- Info: additional player threads not running at this point -----
            
            // Seek to the current playback cursor time (this causes the start
            // and current times to be synchronised as well as starting AVPlayer
            // playback)
            seekRequested = YES;
            
            if (0.0f <= seekPosition) {
                // If a valid position has been requested, update the player
                // cursor, which will allow playback to begin from the
                // correct position
                [self updatePlayerCursorPosition:seekPosition];
            }
            
            mediaState = PLAYING;
            
            if (YES == playVideo) {
                // Start a timer to drive the frame pump (on a background
                // thread)
                [self performSelectorInBackground:@selector(createFrameTimer) withObject:nil];
            }
            else {
                // The asset contains no video.  Play the audio
                [player play];
            }
            
            ret = YES;
        }
    }
    
    if (YES == ret) {
        playerType = (enum tagPLAYER_TYPE)requestedPlayerType;
    }
    
    // ----- Info: additional player threads now running (if ret is YES) -----
    
    return ret;
}


// Pause playback (on-texture player only)
- (BOOL)pause
{
    BOOL ret = NO;
    
    // Control available only when playing on texture (not the native player)
    if (PLAYING == mediaState) {
        if (PLAYER_TYPE_ON_TEXTURE == playerType) {
            [dataLock lock];
            mediaState = PAUSED;
            
            // Stop the audio (if there is any)
            if (YES == playAudio) {
                [player pause];
            }
            
            // Stop the frame pump thread
            [self waitForFrameTimerThreadToEnd];
            
            [dataLock unlock];
            ret = YES;
        }
        else {
            NSLog(@"Pause control available only when playing video on texture");
        }
    }
    
    return ret;
}


// Stop playback (on-texture player only)
- (BOOL)stop
{
    BOOL ret = NO;
    
    // Control available only when playing on texture (not the native player)
    if (PLAYING == mediaState) {
        if (PLAYER_TYPE_ON_TEXTURE == playerType) {
            [dataLock lock];
            mediaState = STOPPED;
            
            // Stop the audio (if there is any)
            if (YES == playAudio) {
                [player pause];
            }
            
            // Stop the frame pump thread
            [self waitForFrameTimerThreadToEnd];
            
            // Reset the playback cursor position
            [self updatePlayerCursorPosition:PLAYER_CURSOR_POSITION_MEDIA_START];
            
            [dataLock unlock];
            ret = YES;
        }
        else {
            NSLog(@"Stop control available only when playing video on texture");
        }
    } else if (PLAYING_FULLSCREEN == mediaState) {
        // Stop receiving notifications
        [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:movieViewController.moviePlayer];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerLoadStateDidChangeNotification object:movieViewController.moviePlayer];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerDidExitFullscreenNotification object:movieViewController.moviePlayer];
        
        // Stop fullscreen mode
        [movieViewController.moviePlayer setFullscreen:NO];
        
        // Dismiss the MovieViewController
        [rootViewController dismissViewControllerAnimated:YES completion:^(void){}];
        
//        [movieViewController release];
        movieViewController = nil;
    }
    
    return ret;
}


// Seek to a particular playback cursor position (on-texture player only)
- (BOOL)seekTo:(float)position
{
    BOOL ret = NO;
    
    // Control available only when playing on texture (not the native player)
    if (PLAYER_TYPE_ON_TEXTURE == playerType) {
        if (NOT_READY > mediaState) {
            if (position < videoLengthSeconds) {
                // Set the new time (the actual seek occurs in getNextVideoFrame)
                [dataLock lock];
                [self updatePlayerCursorPosition:position];
                seekRequested = YES;
                [dataLock unlock];
                ret = YES;
            }
            else {
                NSLog(@"Requested seek position greater than video length");
            }
        }
        else {
            NSLog(@"Seek control not available in current state");
        }
    }
    else {
        NSLog(@"Seek control available only when playing video on texture");
    }
    
    return ret;
}


// Get the current playback cursor position (on-texture player only)
- (float)getCurrentPosition
{
    float ret = -1.0f;
    
    // Return information only when playing on texture (not the native player)
    if (PLAYER_TYPE_ON_TEXTURE == playerType) {
        if (NOT_READY > mediaState) {
            [dataLock lock];
            ret = (float)playerCursorPosition;
            [dataLock unlock];
        }
        else {
            NSLog(@"Current playback position not available in current state");
        }
    }
    else {
        NSLog(@"Current playback position available only when playing video on texture");
    }
    
    return ret;
}


// Set the volume level (on-texture player only)
- (BOOL)setVolume:(float)volume
{
    BOOL ret = NO;
    
    // Control available only when playing on texture (not the native player)
    if (PLAYER_TYPE_ON_TEXTURE == playerType) {
        if (NOT_READY > mediaState) {
            [dataLock lock];
            ret = [self setVolumeLevel:volume];
            [dataLock unlock];
        }
        else {
            NSLog(@"Volume control not available in current state");
        }
    }
    else {
        NSLog(@"Volume control available only when playing video on texture");
    }
    
    return ret;
}


// Update the OpenGL video texture with the latest available video data
- (GLuint)updateVideoData
{
    GLuint textureID = 0;
    
    // If currently playing on texture
    if (PLAYING == mediaState && PLAYER_TYPE_ON_TEXTURE == playerType) {
        [latestSampleBufferLock lock];
        
        unsigned char* pixelBufferBaseAddress = NULL;
        CVImageBufferRef pixelBuffer;
        
        // If we have a valid buffer, lock the base address of its pixel buffer
        if (NULL != latestSampleBuffer) {
            pixelBuffer = CMSampleBufferGetImageBuffer(latestSampleBuffer);
            CVPixelBufferLockBaseAddress(pixelBuffer, 0);
            pixelBufferBaseAddress = (unsigned char*)CVPixelBufferGetBaseAddress(pixelBuffer);
        }
        else {
            // No video sample buffer available: we may have been asked to
            // provide one before any are available, or we may have read all
            // available frames
            DEBUGLOG(@"No video sample buffer available");
        }
        
        if (NULL != pixelBufferBaseAddress) {
            // If we haven't created the video texture, do so now
            if (0 == videoTextureHandle) {
                videoTextureHandle = [self createVideoTexture];
            }
            
            glBindTexture(GL_TEXTURE_2D, videoTextureHandle);
            const size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
            
            if (bytesPerRow / BYTES_PER_TEXEL == videoSize.width) {
                // No padding between lines of decoded video
                glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, videoSize.width, videoSize.height, 0, GL_BGRA, GL_UNSIGNED_BYTE, pixelBufferBaseAddress);
            }
            else {
                // Decoded video contains padding between lines.  We must not
                // upload it to graphics memory as we do not want to display it
                
                // Allocate storage for the texture (correctly sized)
                glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, videoSize.width, videoSize.height, 0, GL_BGRA, GL_UNSIGNED_BYTE, NULL);
            
                videoSize.width = bytesPerRow / BYTES_PER_TEXEL;
                // Now upload each line of texture data as a sub-image
                for (int i = 0; i < videoSize.width; ++i) {
                    GLubyte* line = pixelBufferBaseAddress + i * bytesPerRow;
                    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, i, videoSize.width,1, GL_BGRA, GL_UNSIGNED_BYTE, line);
                }
            }
            
            glBindTexture(GL_TEXTURE_2D, 0);
            
            // Unlock the buffers
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            
            textureID = videoTextureHandle;
        }
        
        [latestSampleBufferLock unlock];
    }
    
    return textureID;
}


//------------------------------------------------------------------------------
#pragma mark - AVPlayer observation
// Called when the value at the specified key path relative to the given object
// has changed.  Note, this method is invoked on the main queue
- (void)observeValueForKeyPath:(NSString*) path 
                      ofObject:(id)object 
                        change:(NSDictionary*)change 
                       context:(void*)context
{
    if (AVPlayerItemStatusObservationContext == context) {
        AVPlayerItemStatus status = (AVPlayerItemStatus)[[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        
        switch (status) {
            case AVPlayerItemStatusUnknown:
                DEBUGLOG(@"AVPlayerItemStatusObservationContext -> AVPlayerItemStatusUnknown");
                mediaState = NOT_READY;
                break;
            case AVPlayerItemStatusReadyToPlay:
                DEBUGLOG(@"AVPlayerItemStatusObservationContext -> AVPlayerItemStatusReadyToPlay");
                mediaState = READY;
                
                // If immediate on-texture playback has been requested, start
                // playback
                if (YES == playImmediately) {
                    [self play:NO fromPosition:VIDEO_PLAYBACK_CURRENT_POSITION];
                }
                
                break;
            case AVPlayerItemStatusFailed:
                DEBUGLOG(@"AVPlayerItemStatusObservationContext -> AVPlayerItemStatusFailed");
                NSLog(@"Error - AVPlayer unable to play media: %@", [[[player currentItem] error] localizedDescription]);
                mediaState = ERROR;
                break;
            default:
                DEBUGLOG(@"AVPlayerItemStatusObservationContext -> Unknown");
                mediaState = NOT_READY;
                break;
        }
    }
    else if (AVPlayerRateObservationContext == context && NO == playVideo && PLAYING == mediaState) {
        // We must detect the end of playback here when playing audio-only
        // media, because the video frame pump is not running (end of playback
        // is detected by the frame pump when playing video-only and audio/video
        // media).  We detect the difference between reaching the end of the
        // media and the user pausing/stopping playback by testing the value of
        // mediaState
        DEBUGLOG(@"AVPlayerRateObservationContext");
        float rate = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
        
        if (0.0f == rate) {
            // Playback has reached end of media
            mediaState = REACHED_END;
            
            // Reset AVPlayer cursor position (audio)
            CMTime startTime = CMTimeMake(PLAYER_CURSOR_POSITION_MEDIA_START * TIMESCALE, TIMESCALE);
            [player seekToTime:startTime];
        }
    }
}


//------------------------------------------------------------------------------
#pragma mark - MPMoviePlayerController observation
// Called when the movie player's media load state changes
- (void)moviePlayerLoadStateChanged:(NSNotification*)notification;
{
    DEBUGLOG(@"moviePlayerLoadStateChanged");
    if (MPMovieLoadStatePlayable & [movieViewController.moviePlayer loadState]) {
        // If the movie is playable, set the playback time to the current cursor
        // position (in case the on texture player is passing responsibility for
        // playing the current media to the native player) and start playback
        [movieViewController.moviePlayer setCurrentPlaybackTime:playerCursorPosition];
        
        // Use fullscreen mode
        [movieViewController.moviePlayer setFullscreen:YES];
        
        // If video was playing on texture before switching to fullscreen mode,
        // start playback
        if (YES == resumeOnTexturePlayback) {
            [movieViewController.moviePlayer play];
        }
    }
}

// Called when the movie player's media playback ends
- (void)moviePlayerPlaybackDidFinish:(NSNotification*)notification
{
    DEBUGLOG(@"moviePlayerPlaybackDidFinish");
    // Determine the reason the playback finished
    NSDictionary* dict = [notification userInfo];
    NSNumber* reason = (NSNumber*)[dict objectForKey:@"MPMoviePlayerPlaybackDidFinishReasonUserInfoKey"];
    
    CFTimeInterval cursorPosition = PLAYER_CURSOR_POSITION_MEDIA_START;
    
    switch ([reason intValue]) {
        case MPMovieFinishReasonPlaybackEnded:
            DEBUGLOG(@"moviePlayerPlaybackDidFinish -> MPMovieFinishReasonPlaybackEnded");
            break;
        case MPMovieFinishReasonPlaybackError:
            DEBUGLOG(@"moviePlayerPlaybackDidFinish -> MPMovieFinishReasonPlaybackError");
            break;
        case MPMovieFinishReasonUserExited:
            DEBUGLOG(@"moviePlayerPlaybackDidFinish -> MPMovieFinishReasonUserExited");
            cursorPosition = [movieViewController.moviePlayer currentPlaybackTime];
            break;
        default:
            DEBUGLOG(@"moviePlayerPlaybackDidFinish -> Unknown");
            break;
    }
    
    // no need to resume player if going back to texture
    resumeOnTexturePlayback = NO;
    [self moviePlayerExitAtPosition:cursorPosition];
}


- (void)moviePlayerDidExitFullscreen:(NSNotification*)notification
{
    DEBUGLOG(@"moviePlayerDidExitFullscreen");
    [self moviePlayerExitAtPosition:[movieViewController.moviePlayer currentPlaybackTime]];
}


- (void)moviePlayerExitAtPosition:(NSTimeInterval)position
{
#ifdef DEBUG
    NSLog(@"moviePlayerExitAtPosition: %f", position);
#endif
    // Stop receiving notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:movieViewController.moviePlayer];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerLoadStateDidChangeNotification object:movieViewController.moviePlayer];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerDidExitFullscreenNotification object:movieViewController.moviePlayer];
    
    // Stop fullscreen mode
    [movieViewController.moviePlayer setFullscreen:NO];
    
    // Dismiss the MovieViewController
    [rootViewController dismissViewControllerAnimated:YES completion:^(void){}];
    
//    [movieViewController release];
    movieViewController = nil;
    
    [dataLock lock];
    // Update the playback cursor position
    [self updatePlayerCursorPosition:position];
    [dataLock unlock];

    // If video was playing on texture before switching to fullscreen mode,
    // restart playback
    if (YES == resumeOnTexturePlayback) {
        resumeOnTexturePlayback = NO;
        [self play:NO fromPosition:VIDEO_PLAYBACK_CURRENT_POSITION];
    }
    else {
        mediaState = PAUSED;
    }
}


//------------------------------------------------------------------------------
#pragma mark - Private methods
- (void)resetData
{
    // ----- Info: additional player threads not running at this point -----
    
    // Reset media state and information
    mediaState = NOT_READY;
    syncStatus = SYNC_DEFAULT;
    playerType = PLAYER_TYPE_ON_TEXTURE;
    requestedCursorPosition = PLAYER_CURSOR_REQUEST_COMPLETE;
    playerCursorPosition = PLAYER_CURSOR_POSITION_MEDIA_START;
    playImmediately = NO;
    videoSize.width = 0.0f;
    videoSize.height = 0.0f;
    videoLengthSeconds = 0.0f;
    videoFrameRate = 0.0f;
    playAudio = NO;
    playVideo = NO;
    
    // Remove KVO observers
    [[player currentItem] removeObserver:self forKeyPath:kStatusKey];
    [player removeObserver:self forKeyPath:kRateKey];
    
    // Release AVPlayer, AVAsset, etc.
//    [player release];
    player = nil;
//    [asset release];
    asset = nil;
//    [assetReader release];
    assetReader = nil;
//    [assetReaderTrackOutputVideo release];
    assetReaderTrackOutputVideo = nil;
//    [movieViewController release];
    movieViewController = nil;
//    [mediaURL release];
    mediaURL = nil;
}


- (BOOL)loadLocalMediaFromURL:(NSURL*)url
{
    BOOL ret = NO;
    asset = [[AVURLAsset alloc] initWithURL:url options:nil];
    
    if (nil != asset) {
        // We can now attempt to load the media, so report success.  We will
        // discover if the load actually completes successfully when we are
        // called back by the system
        ret = YES;
        
        [asset loadValuesAsynchronouslyForKeys:[NSArray arrayWithObject:kTracksKey] completionHandler:
         ^{
             // Completion handler block (dispatched on main queue when loading
             // completes)
             dispatch_async(dispatch_get_main_queue(),
                            ^{
                                NSError *error = nil;
                                AVKeyValueStatus status = [asset statusOfValueForKey:kTracksKey error:&error];
                                
                                if (status == AVKeyValueStatusLoaded) {
                                    // Asset loaded, retrieve info and prepare
                                    // for playback
                                    if (NO == [self prepareAssetForPlayback]) {
                                        NSLog(@"Error - Unable to prepare media for playback");
                                        mediaState = ERROR;
                                    }
                                }
                                else {
                                    // Error
                                    NSLog(@"Error - The asset's tracks were not loaded: %@", [error localizedDescription]);
                                    mediaState = ERROR;
                                }
                            });
         }];
    }
    
    return ret;
}


// Prepare the AVURLAsset for playback
- (BOOL)prepareAssetForPlayback
{
    // Get video properties
    videoSize = [asset naturalSize];
    videoLengthSeconds = CMTimeGetSeconds([asset duration]);
    
    // Start playback at time 0.0
    playerCursorStartPosition = kCMTimeZero;
    
    // Start playback at full volume (audio mix level, not system volume level)
    currentVolume = PLAYER_VOLUME_DEFAULT;
    
    // Create asset tracks for reading
    BOOL ret = [self prepareAssetForReading:playerCursorStartPosition];
    
    if (YES == ret) {
        if (YES == playAudio) {
            // Prepare the AVPlayer to play the audio
            [self prepareAVPlayer];
        }
        else {
            // Inform our client that the asset is ready to play
            mediaState = READY;
        }
    }
    
    return ret;
}


// Prepare the AVURLAsset for reading so we can obtain video frame data from it
- (BOOL)prepareAssetForReading:(CMTime)startTime
{
    BOOL ret = YES;
    NSError* error = nil;
    
    // ===== Video =====
    // Get the first video track
    AVAssetTrack* assetTrackVideo = nil;
    NSArray* arrayTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if (0 < [arrayTracks count]) {
        playVideo = YES;
        assetTrackVideo = [arrayTracks objectAtIndex:0];
        videoFrameRate = [assetTrackVideo nominalFrameRate];
        
        // Release any existing asset reader-related resources]
//        [assetReader release];
//        [assetReaderTrackOutputVideo release];
        
        // Create an asset reader for the video track
        assetReader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
        
        // Create an output for the video track
        NSDictionary* outputSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(NSString *)kCVPixelBufferPixelFormatTypeKey];
        assetReaderTrackOutputVideo = [[AVAssetReaderTrackOutput alloc] initWithTrack:assetTrackVideo outputSettings:outputSettings];
        
        // Add the video output to the asset reader
        if ([assetReader canAddOutput:assetReaderTrackOutputVideo]) {
            [assetReader addOutput:assetReaderTrackOutputVideo];
        }
        
        // Set the time range
        CMTimeRange requiredTimeRange = CMTimeRangeMake(startTime, kCMTimePositiveInfinity);
        [assetReader setTimeRange:requiredTimeRange];
        
        // Start reading the track
        [assetReader startReading];
        
        if (AVAssetReaderStatusReading != [assetReader status]) {
            NSLog(@"Error - AVAssetReader not in reading state");
            ret = NO;
        }
    }
    else {
        NSLog(@"***** No video tracks in asset *****");
    }
    
    // ===== Audio =====
    // Get the first audio track
    arrayTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    if (0 < [arrayTracks count]) {
        playAudio = YES;
        AVAssetTrack* assetTrackAudio = [arrayTracks objectAtIndex:0];
        
        AVMutableAudioMixInputParameters* audioInputParams = [AVMutableAudioMixInputParameters audioMixInputParameters];
        [audioInputParams setVolume:currentVolume atTime:playerCursorStartPosition];
        [audioInputParams setTrackID:[assetTrackAudio trackID]];
        
        NSArray* audioParams = [NSArray arrayWithObject:audioInputParams];
        AVMutableAudioMix* audioMix = [AVMutableAudioMix audioMix];
        [audioMix setInputParameters:audioParams];
        
        AVPlayerItem* item = [player currentItem];
        [item setAudioMix:audioMix];
    }
    else {
        NSLog(@"***** No audio tracks in asset *****");
    }
    
    return ret;
}


// Prepare the AVPlayer object for media playback
- (void)prepareAVPlayer
{
    // Create a player item
    AVPlayerItem* item = [AVPlayerItem playerItemWithAsset:asset];
    
    // Add player item status KVO observer
    NSKeyValueObservingOptions opts = NSKeyValueObservingOptionNew;
    [item addObserver:self forKeyPath:kStatusKey options:opts context:AVPlayerItemStatusObservationContext];
    
    // Create an AV player
    player = [[AVPlayer alloc] initWithPlayerItem:item];
    
    // Add player rate KVO observer
    [player addObserver:self forKeyPath:kRateKey options:opts context:AVPlayerRateObservationContext];
}


// Video frame pump timer callback
- (void)frameTimerFired:(NSTimer*)timer;
{
    if (NO == stopFrameTimer) {
        [self getNextVideoFrame];
    }
    else {
        // NSTimer invalidate must be called on the timer's thread
        [frameTimer invalidate];
    }
}


// Decode the next video frame and make it available for use (do not assume the
// timer driving the frame pump will be accurate)
- (void)getNextVideoFrame
{
    // Synchronise access to publicly accessible internal data.  We use tryLock
    // here to prevent possible deadlock when pause or stop are called on
    // another thread
    if (NO == [dataLock tryLock]) {
        return;
    }
    
    @try {
        // If we've been told to seek to a new time, do so now
        if (YES == seekRequested) {
            seekRequested = NO;
            [self doSeekAndPlayAudio];
        }
        
        // Simple video synchronisation mechanism:
        // If the video frame time is within tolerance, make it available to our
        // client.  This state is SYNC_READY.
        // If the video frame is behind, throw it away and get the next one.  We
        // will either catch up with the reference time (and become SYNC_READY),
        // or run out of frames.  This state is SYNC_BEHIND.
        // If the video frame is ahead, make it available to the client, but do
        // not retrieve more frames until the reference time catches up.  This
        // state is SYNC_AHEAD.
        
        while (SYNC_READY != syncStatus) {
            Float64 delta;
            
            if (SYNC_AHEAD != syncStatus) {
                currentSampleBuffer = [assetReaderTrackOutputVideo copyNextSampleBuffer];
            }
            
            if (NULL == currentSampleBuffer) {
                // Failed to read the next sample buffer
                break;
            }
            
            // Get the time stamp of the video frame
            CMTime frameTimeStamp = CMSampleBufferGetPresentationTimeStamp(currentSampleBuffer);
            
            // Get the time since playback began
            playerCursorPosition = CACurrentMediaTime() - mediaStartTime;
            CMTime caCurrentTime = CMTimeMake(playerCursorPosition * TIMESCALE, TIMESCALE);
            
            // Compute delta of video frame and current playback times
            delta = CMTimeGetSeconds(caCurrentTime) - CMTimeGetSeconds(frameTimeStamp);
            
            if (delta < 0) {
                delta *= -1;
                syncStatus = SYNC_AHEAD;
            }
            else {
                syncStatus = SYNC_BEHIND;
            }
            
            if (delta < 1 / videoFrameRate) {
                // Video in sync with audio
                syncStatus = SYNC_READY;
            }
            else if (SYNC_AHEAD == syncStatus) {
                // Video ahead of audio: stay in SYNC_AHEAD state, exit loop
                break;
            }
            else {
                // Video behind audio (SYNC_BEHIND): stay in loop
                CFRelease(currentSampleBuffer);
            }
        }
    }
    @catch (NSException* e) {
        // Assuming no other error, we are trying to read past the last sample
        // buffer
        DEBUGLOG(@"Failed to copyNextSampleBuffer");        
        currentSampleBuffer = NULL;
    }
    
    if (NULL == currentSampleBuffer) {
        switch ([assetReader status]) {
            case AVAssetReaderStatusCompleted:
                // Playback has reached the end of the video media
                DEBUGLOG(@"getNextVideoFrame -> AVAssetReaderStatusCompleted");
                mediaState = REACHED_END;
                break;
            case AVAssetReaderStatusFailed: {
                NSError* error = [assetReader error];
                NSLog(@"getNextVideoFrame -> AVAssetReaderStatusFailed: %@", [error localizedDescription]);
                mediaState = ERROR;
                break;
            }
            default:
                DEBUGLOG(@"getNextVideoFrame -> Unknown");
                break;
        }
        
        // Stop the frame pump
        [frameTimer invalidate];
        
        // Reset the playback cursor position
        [self updatePlayerCursorPosition:PLAYER_CURSOR_POSITION_MEDIA_START];
    }
    
    [latestSampleBufferLock lock];
    
    if (NULL != latestSampleBuffer) {
        // Release the latest sample buffer
        CFRelease(latestSampleBuffer);
    }
    
    if (SYNC_READY == syncStatus) {
        // Audio and video are synchronised, so transfer ownership of
        // currentSampleBuffer to latestSampleBuffer
        latestSampleBuffer = currentSampleBuffer;
    }
    else {
        // Audio and video not synchronised, do not supply a sample buffer
        latestSampleBuffer = NULL;
    }
    
    [latestSampleBufferLock unlock];
    
    // Reset the sync status, unless video is ahead of the reference time
    if (SYNC_AHEAD != syncStatus) {
        syncStatus = SYNC_DEFAULT;
    }
    
    [dataLock unlock];
}


// Create a timer to drive the video frame pump
- (void)createFrameTimer
{
//    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    frameTimer = [NSTimer scheduledTimerWithTimeInterval:(1 / videoFrameRate) target:self selector:@selector(frameTimerFired:) userInfo:nil repeats:YES];
    
    // Execute the current run loop (it will terminate when its associated timer
    // becomes invalid)
    [[NSRunLoop currentRunLoop] run];
    
    // Release frameTimer (set to nil to notify any threads waiting for the
    // frame pump to stop)
//    [frameTimer release];
    frameTimer = nil;
    
    // Make sure we do not leak a sample buffer
    [latestSampleBufferLock lock];
    
    if (NULL != latestSampleBuffer) {
        // Release the latest sample buffer
        CFRelease(latestSampleBuffer);
        latestSampleBuffer = NULL;
    }
    
    [latestSampleBufferLock unlock];
    
//    [pool release];
}


// Create an OpenGL texture for the video data
- (GLuint)createVideoTexture
{
	GLuint handle;
	glGenTextures(1, &handle);
	glBindTexture(GL_TEXTURE_2D, handle);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glBindTexture(GL_TEXTURE_2D, 0);
	
	return handle;
}


// Update the playback cursor position
// [Always called with dataLock locked]
- (void)updatePlayerCursorPosition:(float)position
{
    // Set the player cursor position so the native player can restart from the
    // appropriate time if play (fullscreen) is called again
    playerCursorPosition = position;
    
    // Set the requested cursor position to cause the on texture player to seek
    // to the appropriate time if play (on texture) is called again
    requestedCursorPosition = position;
}


// Set the volume level (on-texture player only)
// [Always called with dataLock locked]
- (BOOL)setVolumeLevel:(float)volume
{
    BOOL ret = NO;
    NSArray* arrayTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    
    if (0 < [arrayTracks count]) {
        // Get the asset's audio track
        AVAssetTrack* assetTrackAudio = [arrayTracks objectAtIndex:0];
        
        if (nil != assetTrackAudio) {
            // Set up the audio mix
            AVMutableAudioMixInputParameters* audioInputParams = [AVMutableAudioMixInputParameters audioMixInputParameters];
            [audioInputParams setVolume:volume atTime:playerCursorStartPosition];
            [audioInputParams setTrackID:[assetTrackAudio trackID]];
            NSArray* audioParams = [NSArray arrayWithObject:audioInputParams];
            AVMutableAudioMix* audioMix = [AVMutableAudioMix audioMix];
            [audioMix setInputParameters:audioParams];
            
            // Apply the audio mix the the AVPlayer's current item
            [[player currentItem] setAudioMix:audioMix];
            
            // Store the current volume level
            currentVolume = volume;
            ret = YES;
        }
    }
    
    return ret;
}


// Seek to a particular playback position (when playing on texture)
// [Always called with dataLock locked]
- (void)doSeekAndPlayAudio
{
    if (PLAYER_CURSOR_REQUEST_COMPLETE < requestedCursorPosition) {
        // Store the cursor position from which playback will start
        playerCursorStartPosition = CMTimeMake(requestedCursorPosition * TIMESCALE, TIMESCALE);
        
        // Ensure the volume continues at the current level
        [self setVolumeLevel:currentVolume];
        
        if (YES == playAudio) {
            // Set AVPlayer cursor position (audio)
            [player seekToTime:playerCursorStartPosition];
        }
    
        // Set the asset reader's start time to the new time (video)
        [self prepareAssetForReading:playerCursorStartPosition];
        
        // Indicate seek request is complete
        requestedCursorPosition = PLAYER_CURSOR_REQUEST_COMPLETE;
    }
    
    if (YES == playAudio) {
        // Play the audio (if there is any)
        [player play];
    }
    
    // Store the media start time for reference
    mediaStartTime = CACurrentMediaTime() - playerCursorPosition;
}


// Request the frame timer to terminate and wait for its thread to end
- (void)waitForFrameTimerThreadToEnd
{
    stopFrameTimer = YES;
    
    // Wait for the frame pump thread to stop
    while (nil != frameTimer) {
        [NSThread sleepForTimeInterval:0.01];
    }
    
    stopFrameTimer = NO;
}

@end
