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

#import "AppDelegate.h"

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

@interface ExpandedViewController () {
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
  IBOutlet UIButton *_playPauseButton;
  IBOutlet UIButton *_nextButton;
  IBOutlet UIButton *_closedCaptionsButton;
  UIActivityIndicatorView *_activityIndicator;

  IBOutlet UIView *topScrim;
  IBOutlet UIView *bottomScrim;

  BOOL _castControlBarsWereEnabled;
}

@end

@implementation ExpandedViewController

- (void)viewDidLoad {
  NSLog(@"viewDidLoad");

  [_playPauseButton
      setImage:[UIImage imageNamed:@"pause_circle"]  // Icons/media_pause
      forState:(UIControlStateNormal)];
  [_playPauseButton setImage:[UIImage imageNamed:@"play_circle"]
                    forState:(UIControlStateNormal)];

  [_prevButton setImage:[UIImage imageNamed:@"media_previous"]
               forState:(UIControlStateNormal)];

  [_nextButton setImage:[UIImage imageNamed:@"media_next"]
               forState:(UIControlStateNormal)];

  [_closedCaptionsButton setImage:[UIImage imageNamed:@"closed_captions"]
                         forState:(UIControlStateNormal)];

  UIImage *thumb = [UIImage imageNamed:@"thumb"];  // Icons/slider_thumb
  [_streamPositionSlider setThumbImage:thumb forState:UIControlStateNormal];
  [_streamPositionSlider setThumbImage:thumb
                              forState:UIControlStateHighlighted];

  _activityIndicator = [[UIActivityIndicatorView alloc]
      initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
  _activityIndicator.hidesWhenStopped = YES;
  [self.view insertSubview:_activityIndicator
              aboveSubview:[self.view.subviews lastObject]];

  [self.view setBackgroundColor:[UIColor blackColor]];

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

@end
