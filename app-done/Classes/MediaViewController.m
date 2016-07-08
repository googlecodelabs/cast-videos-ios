// Copyright 2016 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <GoogleCast/GoogleCast.h>
#import "ActionSheet.h"
#import "MediaViewController.h"

#import "MediaItem.h"
#import "MediaListModel.h"

#import "AppDelegate.h"
#import "LocalPlayerView.h"
#import "Toast.h"

/* The player state. */
typedef NS_ENUM(NSInteger, PlaybackMode) {
  PlaybackModeNone = 0,
  PlaybackModeLocal,
  PlaybackModeRemote
};

static NSString *const kPrefShowStreamTimeRemaining =
    @"show_stream_time_remaining";

@interface MediaViewController ()<GCKSessionManagerListener,
                                  LocalPlayerViewDelegate> {
  IBOutlet UILabel *_titleLabel;
  IBOutlet UILabel *_subtitleLabel;
  IBOutlet UITextView *_descriptionTextView;
  IBOutlet LocalPlayerView *_localPlayerView;
  GCKSessionManager *_sessionManager;
  GCKCastSession *_castSession;
  GCKUIMediaController *_castMediaController;
  BOOL _streamPositionSliderMoving;
  PlaybackMode _playbackMode;
  BOOL _showStreamTimeRemaining;
  BOOL _localPlaybackImplicitlyPaused;
  ActionSheet *_actionSheet;
}

/* Whether to reset the edges on disappearing. */
@property(nonatomic) BOOL resetEdgesOnDisappear;

@end

@implementation MediaViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  NSLog(@"in MediaViewController viewDidLoad");

  _sessionManager = [GCKCastContext sharedInstance].sessionManager;
  _castMediaController = [[GCKUIMediaController alloc] init];

  [_sessionManager addListener:self];

  _localPlayerView.delegate = self;

  GCKUICastButton *castButton =
      [[GCKUICastButton alloc] initWithFrame:CGRectMake(0, 0, 24, 24)];
  castButton.tintColor = [UIColor whiteColor];
  self.navigationItem.rightBarButtonItem =
      [[UIBarButtonItem alloc] initWithCustomView:castButton];

  _playbackMode = PlaybackModeNone;
}

- (void)viewWillAppear:(BOOL)animated {
  NSLog(@"viewWillAppear; mediaInfo is %@, mode is %d", self.mediaInfo,
        (int)_playbackMode);

  appDelegate.castControlBarsEnabled = YES;

  if ((_playbackMode == PlaybackModeLocal) && _localPlaybackImplicitlyPaused) {
    [_localPlayerView play];
    _localPlaybackImplicitlyPaused = NO;
  }

  [self switchToLocalPlayback];

  if (_resetEdgesOnDisappear) {
    [self setNavigationBarStyle:LPVNavBarDefault];
  }
  [self setNavigationBarStyle:LPVNavBarDefault];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(deviceOrientationDidChange:)
             name:UIDeviceOrientationDidChangeNotification
           object:nil];
  [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];

  [self.navigationController.navigationBar sizeToFit];

  [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
  NSLog(@"viewWillDisappear");

  switch (_playbackMode) {
    case PlaybackModeLocal:
      if (_localPlayerView.playerState == LocalPlayerStatePlaying ||
          _localPlayerView.playerState == LocalPlayerStateStarting) {
        _localPlaybackImplicitlyPaused = YES;
        [_localPlayerView pause];
      }
      break;
    case PlaybackModeRemote:
    case PlaybackModeNone:
    default:
      // Do nothing.
      break;
  }

  [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
  [[NSNotificationCenter defaultCenter]
      removeObserver:self
                name:UIDeviceOrientationDidChangeNotification
              object:nil];

  [super viewWillDisappear:animated];
}

- (void)deviceOrientationDidChange:(NSNotification *)notification {
  NSLog(@"Orientation changed.");
  UIInterfaceOrientation orientation =
      [UIApplication sharedApplication].statusBarOrientation;

  [_localPlayerView orientationChanged];

  if (!UIInterfaceOrientationIsLandscape(orientation) ||
      !_localPlayerView.playingLocally) {
    [self setNavigationBarStyle:LPVNavBarDefault];
  } else if (UIInterfaceOrientationIsLandscape(orientation)) {
    [self setNavigationBarStyle:LPVNavBarTransparent];
  }
}

- (void)setMediaInfo:(MediaItem *)mediaInfo {
  NSLog(@"setMediaInfo");
  _mediaInfo = mediaInfo;
}

#pragma mark - Mode switching

- (void)switchToLocalPlayback {
  NSLog(@"switchToLocalPlayback");

  if (_playbackMode == PlaybackModeLocal) {
    return;
  }

  NSTimeInterval playPosition = 0;
  BOOL paused = NO;
  BOOL ended = NO;
  if (_playbackMode == PlaybackModeRemote) {
    playPosition = _castMediaController.lastKnownStreamPosition;
    paused = (_castMediaController.lastKnownPlayerState ==
              GCKMediaPlayerStatePaused);
    ended =
        (_castMediaController.lastKnownPlayerState == GCKMediaPlayerStateIdle);
    NSLog(@"last player state: %ld, ended: %d",
          (long)_castMediaController.lastKnownPlayerState, ended);
  }

  [self populateMediaInfo:(!paused && !ended) playPosition:playPosition];

  _castSession = nil;

  _playbackMode = PlaybackModeLocal;
}

- (void)populateMediaInfo:(BOOL)autoPlay
             playPosition:(NSTimeInterval)playPosition {
  NSLog(@"populateMediaInfo");
  _titleLabel.text = self.mediaInfo.title;

  NSString *subtitle = self.mediaInfo.studio;
  _subtitleLabel.text = subtitle;

  NSString *description = self.mediaInfo.subtitle;
  _descriptionTextView.text =
      [description stringByReplacingOccurrencesOfString:@"\\n"
                                             withString:@"\n"];
  [_localPlayerView loadMedia:self.mediaInfo
                     autoPlay:autoPlay
                 playPosition:playPosition];
}

- (void)switchToRemotePlayback {
  NSLog(@"switchToRemotePlayback; mediaInfo is %@", self.mediaInfo);

  if (_playbackMode == PlaybackModeRemote) {
    return;
  }

  _castSession = _sessionManager.currentCastSession;

  // If we were playing locally, load the local media on the remote player
  if ((_playbackMode == PlaybackModeLocal) &&
      (_localPlayerView.playerState != LocalPlayerStateStopped) &&
      self.mediaInfo) {
    NSLog(@"loading media: %@", self.mediaInfo);
    NSTimeInterval playPosition = _localPlayerView.streamPosition;
    BOOL paused = (_localPlayerView.playerState == LocalPlayerStatePaused);
    GCKMediaQueueItemBuilder *builder = [[GCKMediaQueueItemBuilder alloc] init];
    builder.mediaInformation = [self buildMediaInformation];
    builder.autoplay = !paused;
    builder.preloadTime =
        [[NSUserDefaults standardUserDefaults] integerForKey:kPrefPreloadTime];
    GCKMediaQueueItem *item = [builder build];

    [_castSession.remoteMediaClient queueLoadItems:@[ item ]
                                        startIndex:0
                                      playPosition:playPosition
                                        repeatMode:GCKMediaRepeatModeOff
                                        customData:nil];
  }
  [_localPlayerView stop];
  [_localPlayerView showSplashScreen];
  _playbackMode = PlaybackModeRemote;
}

- (void)clearMetadata {
  _titleLabel.text = @"";
  _subtitleLabel.text = @"";
  _descriptionTextView.text = @"";
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                  message:message
                                                 delegate:nil
                                        cancelButtonTitle:@"OK"
                                        otherButtonTitles:nil];
  [alert show];
}

#pragma mark - Local playback UI actions

- (void)startAdjustingStreamPosition:(id)sender {
  _streamPositionSliderMoving = YES;
}

- (void)finishAdjustingStreamPosition:(id)sender {
  _streamPositionSliderMoving = NO;
}

- (void)togglePlayPause:(id)sender {
  [_localPlayerView togglePause];
}

#pragma mark - LocalPlayerViewDelegate

/* Signal the requested style for the view. */
- (void)setNavigationBarStyle:(LPVNavBarStyle)style {
  NSLog(@"setNavigationBarStyle: %lu", (unsigned long)style);
  if (style == LPVNavBarDefault) {
    self.edgesForExtendedLayout = UIRectEdgeAll;
    [self hideNavigationBar:NO];
    [self.navigationController.navigationBar setTranslucent:NO];
    [self.navigationController.navigationBar
        setBackgroundImage:nil
             forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = nil;
    [[UIApplication sharedApplication]
        setStatusBarHidden:NO
             withAnimation:UIStatusBarAnimationFade];
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
    _resetEdgesOnDisappear = NO;
  } else if (style == LPVNavBarTransparent) {
    self.edgesForExtendedLayout = UIRectEdgeTop;
    [self.navigationController.navigationBar setTranslucent:YES];
    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage new]
             forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = [UIImage new];
    [[UIApplication sharedApplication]
        setStatusBarHidden:YES
             withAnimation:UIStatusBarAnimationFade];
    // Disable the swipe gesture if we're fullscreen.
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    _resetEdgesOnDisappear = YES;
  }
}

/* Request the navigation bar to be hidden or shown. */
- (void)hideNavigationBar:(BOOL)hide {
  NSLog(@"hideNavigationBar: %d", hide);
  [self.navigationController.navigationBar setHidden:hide];
  [self.navigationController.navigationBar setTranslucent:hide];
}

/* Play has been pressed in the LocalPlayerView. */
- (BOOL)continueAfterPlayButtonClicked {
  NSLog(@"continueAfterPlayButtonClicked");
  BOOL hasConnectedCastSession =
      [GCKCastContext sharedInstance].sessionManager.hasConnectedCastSession;
  if (self.mediaInfo && hasConnectedCastSession) {
    [self playSelectedItemRemotely];
    return NO;
  }
  return YES;
}

- (GCKMediaInformation *)buildMediaInformation {
  GCKMediaMetadata *metadata =
      [[GCKMediaMetadata alloc] initWithMetadataType:GCKMediaMetadataTypeMovie];
  [metadata setString:self.mediaInfo.title forKey:kGCKMetadataKeyTitle];
  [metadata setString:self.mediaInfo.subtitle forKey:kMediaKeyDescription];
  [metadata setString:self.mediaInfo.studio forKey:kGCKMetadataKeyStudio];

  [metadata addImage:[[GCKImage alloc] initWithURL:self.mediaInfo.imageURL
                                             width:720
                                            height:480]];
  [metadata setString:[self.mediaInfo.posterURL absoluteString]
               forKey:kMediaKeyPosterURL];
  [metadata addImage:[[GCKImage alloc] initWithURL:self.mediaInfo.posterURL
                                             width:1200
                                            height:780]];

  GCKMediaInformation *mediaInfo = [[GCKMediaInformation alloc]
      initWithContentID:[self.mediaInfo.url absoluteString]
             streamType:GCKMediaStreamTypeBuffered
            contentType:@"video/mp4"
               metadata:metadata
         streamDuration:self.mediaInfo.duration
            mediaTracks:nil
         textTrackStyle:nil
             customData:nil];
  return mediaInfo;
}

- (void)playSelectedItemRemotely {
  GCKCastSession *castSession =
      [GCKCastContext sharedInstance].sessionManager.currentCastSession;
  if (castSession) {
    [castSession.remoteMediaClient loadMedia:[self buildMediaInformation]
                                    autoplay:YES];
  }
  self.navigationItem.backBarButtonItem =
      [[UIBarButtonItem alloc] initWithTitle:@""
                                       style:UIBarButtonItemStylePlain
                                      target:nil
                                      action:nil];
  if (appDelegate.castControlBarsEnabled) {
    appDelegate.castControlBarsEnabled = NO;
  }
  [[GCKCastContext sharedInstance] presentDefaultExpandedMediaControls];
}

/**
 * Loads the currently selected item in the current cast media session.
 * @param appending If YES, the item is appended to the current queue if there
 * is one. If NO, or if
 * there is no queue, a new queue containing only the selected item is created.
 */
- (void)loadSelectedItemByAppending:(BOOL)appending {
  NSLog(@"enqueue item %@", self.mediaInfo);
}

- (void)sessionManager:(GCKSessionManager *)sessionManager
       didStartSession:(GCKSession *)session {
  NSLog(@"MediaViewController: sessionManager didStartSession %@", session);
  [self switchToRemotePlayback];
}

- (void)sessionManager:(GCKSessionManager *)sessionManager
      didResumeSession:(GCKSession *)session {
  NSLog(@"MediaViewController: sessionManager didResumeSession %@", session);
  [self switchToRemotePlayback];
}

- (void)sessionManager:(GCKSessionManager *)sessionManager
         didEndSession:(GCKSession *)session
             withError:(NSError *)error {
  NSLog(@"session ended with error: %@", error);
  NSString *message =
      [NSString stringWithFormat:@"The Casting session has ended.\n%@",
                                 [error description]];

  [Toast displayToastMessage:message
             forTimeInterval:3
                      inView:[UIApplication sharedApplication].delegate.window];
  [self switchToLocalPlayback];
}

- (void)sessionManager:(GCKSessionManager *)sessionManager
    didFailToStartSessionWithError:(NSError *)error {
  [self showAlertWithTitle:@"Failed to start a session"
                   message:[error description]];
}

@end
