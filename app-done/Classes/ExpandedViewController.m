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

#import "ExpandedViewController.h"

#import <GoogleCast/GoogleCast.h>

#import "AppDelegate.h"

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

@interface ExpandedViewController ()<GCKSessionManagerListener,
                                     GCKRemoteMediaClientListener> {
  // Device title
  IBOutlet UILabel *_castingLabel;

  // Image
  IBOutlet UIImageView *_mediaImage;

  // Stream position.
  IBOutlet UILabel *_streamPositionLabel;
  IBOutlet UILabel *_streamDurationLabel;
  IBOutlet UISlider *_streamPositionSlider;
  NSTimer *_timer;

  // Transport controls.
  IBOutlet UIButton *_prevButton;
  IBOutlet GCKUIButton *_playPauseButton;
  IBOutlet UIButton *_nextButton;
  IBOutlet GCKUIButton *_closedCaptionsButton;
  UIActivityIndicatorView *_activityIndicator;

  IBOutlet UIView *topScrim;
  IBOutlet UIView *bottomScrim;

  BOOL _castControlBarsWereEnabled;

  GCKRemoteMediaClient *_mediaClient;
  GCKUIMediaController *_mediaController;
  GCKRequest *_mediaClientRequest;
}

@end

@implementation ExpandedViewController

- (void)viewDidLoad {
  NSLog(@"viewDidLoad");

  [_playPauseButton setImage:[UIImage imageNamed:@"pause_circle"]
                    forState:(UIControlStateNormal | GCKUIControlStatePlay)];
  [_playPauseButton setImage:[UIImage imageNamed:@"play_circle"]
                    forState:(UIControlStateNormal | GCKUIControlStatePause)];

  [_prevButton setImage:[UIImage imageNamed:@"media_previous"]
               forState:(UIControlStateNormal)];

  [_nextButton setImage:[UIImage imageNamed:@"media_next"]
               forState:(UIControlStateNormal)];

  [_closedCaptionsButton setImage:[UIImage imageNamed:@"closed_captions"]
                         forState:(UIControlStateNormal)];

  UIImage *thumb = [UIImage imageNamed:@"thumb"];
  [_streamPositionSlider setThumbImage:thumb forState:UIControlStateNormal];
  [_streamPositionSlider setThumbImage:thumb
                              forState:UIControlStateHighlighted];

  _activityIndicator = [[UIActivityIndicatorView alloc]
      initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
  _activityIndicator.hidesWhenStopped = YES;
  [self.view insertSubview:_activityIndicator
              aboveSubview:[self.view.subviews lastObject]];

  _mediaController = [[GCKUIMediaController alloc] init];
  _mediaController.previousButton = _prevButton;
  _mediaController.playPauseToggleButton = _playPauseButton;
  _mediaController.nextButton = _nextButton;
  _mediaController.tracksButton = _closedCaptionsButton;
  _mediaController.streamPositionLabel = _streamPositionLabel;
  _mediaController.streamDurationLabel = _streamDurationLabel;
  _mediaController.streamPositionSlider = _streamPositionSlider;
  _mediaController.mediaLoadingIndicator = _activityIndicator;

  [_mediaController.session.remoteMediaClient addListener:self];

  GCKSessionManager *sessionManager =
      [GCKCastContext sharedInstance].sessionManager;
  [sessionManager addListener:self];
  if (sessionManager.hasConnectedCastSession) {
    [self attachToCastSession:sessionManager.currentCastSession];
  }

  [self.view setBackgroundColor:[UIColor blackColor]];

  GCKUICastButton *castButton =
      [[GCKUICastButton alloc] initWithFrame:CGRectMake(0, 0, 24, 24)];
  castButton.tintColor = [UIColor whiteColor];
  self.navigationItem.rightBarButtonItem =
      [[UIBarButtonItem alloc] initWithCustomView:castButton];

  [self setNeedsStatusBarAppearanceUpdate];

  [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
  _castControlBarsWereEnabled = appDelegate.castControlBarsEnabled;
  appDelegate.castControlBarsEnabled = NO;
  // Make navigation bar transparent
  [self.navigationController.navigationBar
      setBackgroundImage:[UIImage new]
           forBarMetrics:UIBarMetricsDefault];
  self.navigationController.navigationBar.shadowImage = [UIImage new];
  self.navigationController.navigationBar.translucent = YES;

  _activityIndicator.center = self.view.center;

  topScrim.backgroundColor = [UIColor clearColor];
  bottomScrim.backgroundColor = [UIColor clearColor];
  UIColor *blackColor =
      [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.7f];
  UIColor *clearColor =
      [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.0f];
  NSArray *topColors = [NSArray
      arrayWithObjects:(id)blackColor.CGColor, clearColor.CGColor, nil];
  NSArray *bottomColors = [NSArray
      arrayWithObjects:(id)clearColor.CGColor, blackColor.CGColor, nil];

  CAGradientLayer *gradientTop = [CAGradientLayer layer];
  gradientTop.frame = topScrim.bounds;
  gradientTop.colors = topColors;
  [topScrim.layer insertSublayer:gradientTop atIndex:0];

  CAGradientLayer *gradientBottom = [CAGradientLayer layer];
  gradientBottom.frame = bottomScrim.bounds;
  gradientBottom.colors = bottomColors;
  [bottomScrim.layer insertSublayer:gradientBottom atIndex:0];

  [super viewWillAppear:animated];
}

- (void)goBack {
  [self.navigationController popViewControllerAnimated:NO];
}

- (void)muteButtonClicked {
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
  appDelegate.castControlBarsEnabled = _castControlBarsWereEnabled;
  // Restore navigation bar style
  self.navigationController.navigationBar.shadowImage = nil;
  self.navigationController.navigationBar.translucent = NO;

  [super viewWillDisappear:animated];
}

#pragma mark - UI Actions

- (void)showErrorMessage:(NSString *)message {
  UIAlertView *alert =
      [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                 message:message
                                delegate:nil
                       cancelButtonTitle:NSLocalizedString(@"OK", nil)
                       otherButtonTitles:nil];
  [alert show];
}

- (void)attachToCastSession:(GCKCastSession *)castSession {
  NSLog(@"attachToCastSession");
  _mediaClient = castSession.remoteMediaClient;
  [_mediaClient addListener:self];
  [_mediaClient requestStatus];
  _castingLabel.text = [NSString
      stringWithFormat:@"Casting to %@", castSession.device.friendlyName];
}

- (void)detachFromCastSession {
  NSLog(@"detachFromCastSession");
  [_mediaClient removeListener:self];
  _mediaClient = nil;
}

#pragma mark - GCKSessionManagerListener

- (void)sessionManager:(GCKSessionManager *)sessionManager
   didStartCastSession:(GCKCastSession *)session {
  [self attachToCastSession:session];
}

- (void)sessionManager:(GCKSessionManager *)sessionManager
 didSuspendCastSession:(GCKCastSession *)session
            withReason:(GCKConnectionSuspendReason)reason {
  [self detachFromCastSession];
  [self.navigationController popViewControllerAnimated:YES];
}

- (void)sessionManager:(GCKSessionManager *)sessionManager
  didResumeCastSession:(GCKCastSession *)session {
  [self attachToCastSession:session];
}

- (void)sessionManager:(GCKSessionManager *)sessionManager
    willEndCastSession:(GCKCastSession *)session {
  [self detachFromCastSession];
  [self.navigationController popViewControllerAnimated:YES];
}

- (void)remoteMediaClient:(GCKRemoteMediaClient *)client
     didUpdateMediaStatus:(GCKMediaStatus *)mediaStatus {
  NSLog(@"didUpdateMediaStatus");
  GCKMediaInformation *mediaInfo = mediaStatus.mediaInformation;
  NSArray *images = mediaInfo.metadata.images;
  if (images && [images count] > 0) {
    NSLog(@"didUpdateMediaStatus: images=%ld", (unsigned long)[images count]);
    if ([images count] > 1) {
      GCKImage *image = [images objectAtIndex:1];
      [[GCKCastContext sharedInstance]
              .imageCache fetchImageForURL:image.URL
                                completion:^(UIImage *image) {
                                  [_mediaImage setImage:image];
                                }];
    } else {
      GCKImage *image = [images objectAtIndex:0];
      [[GCKCastContext sharedInstance]
              .imageCache fetchImageForURL:image.URL
                                completion:^(UIImage *image) {
                                  [_mediaImage setImage:image];
                                }];
    }
    [_mediaImage setContentMode:UIViewContentModeScaleAspectFill];
  }

  self.title = [mediaInfo.metadata stringForKey:kGCKMetadataKeyTitle];
}

- (void)remoteMediaClientDidUpdateQueue:(GCKRemoteMediaClient *)client {
}

@end
