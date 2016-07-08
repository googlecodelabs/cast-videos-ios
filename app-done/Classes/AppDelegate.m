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

#import "AppDelegate.h"

#import <AVFoundation/AVFoundation.h>
#import <GoogleCast/Googlecast.h>

#import "MediaViewController.h"
#import "Toast.h"

NSString *const kPrefPreloadTime = @"preload_time_sec";

static NSString *const kPrefEnableAnalyticsLogging =
    @"enable_analytics_logging";
static NSString *const kPrefEnableSDKLogging = @"enable_sdk_logging";
static NSString *const kPrefAppVersion = @"app_version";
static NSString *const kPrefSDKVersion = @"sdk_version";
static NSString *const kPrefReceiverAppID = @"receiver_app_id";
static NSString *const kPrefCustomReceiverSelectedValue =
    @"use_custom_receiver_app_id";
static NSString *const kPrefCustomReceiverAppID = @"custom_receiver_app_id";
static NSString *const kPrefEnableMediaNotifications =
    @"enable_media_notifications";

@interface AppDelegate ()<GCKLoggerDelegate> {
  BOOL _enableSDKLogging;
  BOOL _mediaNotificationsEnabled;
  BOOL _firstUserDefaultsSync;
}
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [self populateRegistrationDomain];
  NSString *applicationID = [self applicationIDFromUserDefaults];
  if (!applicationID) {
    // Don't try to go on without a valid application ID - SDK will fail an
    // assert and app will crash.
    return YES;
  }

  GCKCastOptions *options =
      [[GCKCastOptions alloc] initWithReceiverApplicationID:applicationID];
  [GCKCastContext setSharedInstanceWithOptions:options];

  GCKLoggerFilter *logFilter = [[GCKLoggerFilter alloc] init];
  logFilter.exclusive = YES;
  [logFilter addClassNames:@[
    @"GCKDeviceScanner",
    @"GCKDeviceProvider",
    @"GCKDiscoveryManager",
    @"GCKCastChannel",
    @"GCKMediaControlChannel",
    @"GCKUICastButton",
    @"GCKUIMediaController",
    @"NSMutableDictionary"
  ]];
  [GCKLogger sharedInstance].filter = logFilter;
  [[GCKLogger sharedInstance] setDelegate:self];

  // Set playback category mode to allow playing audio on the video files even
  // when the ringer mute switch is on.
  NSError *setCategoryError;
  BOOL success = [[AVAudioSession sharedInstance]
      setCategory:AVAudioSessionCategoryPlayback
            error:&setCategoryError];
  if (!success) {
    NSLog(@"Error setting audio category: %@",
          setCategoryError.localizedDescription);
  }

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(syncWithUserDefaults)
             name:NSUserDefaultsDidChangeNotification
           object:nil];

  UIStoryboard *appStoryboard =
      [UIStoryboard storyboardWithName:@"Main" bundle:nil];
  UINavigationController *navigationController =
      [appStoryboard instantiateViewControllerWithIdentifier:@"MainNavigation"];
  GCKUICastContainerViewController *castContainerVC;
  castContainerVC = [[GCKCastContext sharedInstance]
      createCastContainerControllerForViewController:navigationController];
  castContainerVC.miniMediaControlsItemEnabled = YES;
  self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
  self.window.rootViewController = castContainerVC;
  [self.window makeKeyAndVisible];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(presentExpandedMediaControls)
             name:kGCKExpandedMediaControlsTriggeredNotification
           object:nil];

  _firstUserDefaultsSync = YES;
  [self syncWithUserDefaults];

  [[UIApplication sharedApplication]
      setStatusBarStyle:UIStatusBarStyleLightContent];

  [GCKCastContext sharedInstance].useDefaultExpandedMediaControls = YES;

  return YES;
}

- (void)applicationWillTerminate:(UIApplication *)application {
  [[NSNotificationCenter defaultCenter]
      removeObserver:self
                name:kGCKExpandedMediaControlsTriggeredNotification
              object:nil];
}

- (void)populateRegistrationDomain {
  NSURL *settingsBundleURL = [[NSBundle mainBundle] URLForResource:@"Settings"
                                                     withExtension:@"bundle"];
  NSString *appVersion = [[NSBundle mainBundle]
      objectForInfoDictionaryKey:@"CFBundleShortVersionString"];

  NSMutableDictionary *appDefaults = [NSMutableDictionary dictionary];
  [self loadDefaults:appDefaults
           fromSettingsPage:@"Root"
      inSettingsBundleAtURL:settingsBundleURL];
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  [userDefaults registerDefaults:appDefaults];
  [userDefaults setValue:appVersion forKey:kPrefAppVersion];
  [userDefaults setValue:kGCKFrameworkVersion forKey:kPrefSDKVersion];
  [userDefaults synchronize];
}

- (void)loadDefaults:(NSMutableDictionary *)appDefaults
         fromSettingsPage:(NSString *)plistName
    inSettingsBundleAtURL:(NSURL *)settingsBundleURL {
  NSString *plistFileName = [plistName stringByAppendingPathExtension:@"plist"];
  NSDictionary *settingsDict = [NSDictionary
      dictionaryWithContentsOfURL:
          [settingsBundleURL URLByAppendingPathComponent:plistFileName]];
  NSArray *prefSpecifierArray =
      [settingsDict objectForKey:@"PreferenceSpecifiers"];

  for (NSDictionary *prefItem in prefSpecifierArray) {
    NSString *prefItemType = prefItem[@"Type"];
    NSString *prefItemKey = prefItem[@"Key"];
    NSString *prefItemDefaultValue = prefItem[@"DefaultValue"];

    if ([prefItemType isEqualToString:@"PSChildPaneSpecifier"]) {
      NSString *prefItemFile = prefItem[@"File"];
      [self loadDefaults:appDefaults
               fromSettingsPage:prefItemFile
          inSettingsBundleAtURL:settingsBundleURL];
    } else if (prefItemKey && prefItemDefaultValue) {
      [appDefaults setObject:prefItemDefaultValue forKey:prefItemKey];
    }
  }
}

- (NSString *)applicationIDFromUserDefaults {
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  NSString *prefApplicationID = [userDefaults stringForKey:kPrefReceiverAppID];
  if ([prefApplicationID isEqualToString:kPrefCustomReceiverSelectedValue]) {
    prefApplicationID = [userDefaults stringForKey:kPrefCustomReceiverAppID];
  }
  NSRegularExpression *appIdRegex =
      [NSRegularExpression regularExpressionWithPattern:@"\\b[0-9A-F]{8}\\b"
                                                options:0
                                                  error:nil];
  NSUInteger numberOfMatches = [appIdRegex
      numberOfMatchesInString:prefApplicationID
                      options:0
                        range:NSMakeRange(0, [prefApplicationID length])];
  if (!numberOfMatches) {
    NSString *message = [NSString
        stringWithFormat:
            @"\"%@\" is not a valid application ID\n"
            @"Please fix the app settings (should be 8 hex digits, in CAPS)",
            prefApplicationID];
    [self showAlertWithTitle:@"Invalid Receiver Application ID"
                     message:message];
    return nil;
  }
  return prefApplicationID;
}

#pragma mark - NSUserDefaults notification

- (void)syncWithUserDefaults {
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

  _enableSDKLogging = [userDefaults boolForKey:kPrefEnableSDKLogging];

  BOOL mediaNotificationsEnabled =
      [userDefaults boolForKey:kPrefEnableMediaNotifications];
  GCKLog(@"notifications ON? %d", mediaNotificationsEnabled);

  if (_firstUserDefaultsSync ||
      (_mediaNotificationsEnabled != mediaNotificationsEnabled)) {
    _mediaNotificationsEnabled = mediaNotificationsEnabled;
  }

  _firstUserDefaultsSync = NO;
}

#pragma mark - GCKLoggerDelegate

- (void)logMessage:(NSString *)message fromFunction:(NSString *)function {
  if (_enableSDKLogging) {
    // Send SDK's log messages directly to the console.
    NSLog(@"%@  %@", function, message);
  }
}

#pragma mark - Notifications

- (void)setCastControlBarsEnabled:(BOOL)notificationsEnabled {
  GCKUICastContainerViewController *castContainerVC;
  castContainerVC =
      (GCKUICastContainerViewController *)self.window.rootViewController;
  castContainerVC.miniMediaControlsItemEnabled = notificationsEnabled;
}

- (BOOL)castControlBarsEnabled {
  GCKUICastContainerViewController *castContainerVC;
  castContainerVC =
      (GCKUICastContainerViewController *)self.window.rootViewController;
  return castContainerVC.miniMediaControlsItemEnabled;
}

- (void)presentExpandedMediaControls {
  NSLog(@"present expanded media controls");
  // Segue directly to the ExpandedViewController.
  UINavigationController *navigationController;
  GCKUICastContainerViewController *castContainerVC;
  castContainerVC =
      (GCKUICastContainerViewController *)self.window.rootViewController;
  navigationController =
      (UINavigationController *)castContainerVC.contentViewController;

  navigationController.navigationItem.backBarButtonItem =
      [[UIBarButtonItem alloc] initWithTitle:@""
                                       style:UIBarButtonItemStylePlain
                                      target:nil
                                      action:nil];
  if (appDelegate.castControlBarsEnabled) {
    appDelegate.castControlBarsEnabled = NO;
  }
  [[GCKCastContext sharedInstance] presentDefaultExpandedMediaControls];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                  message:message
                                                 delegate:nil
                                        cancelButtonTitle:@"OK"
                                        otherButtonTitles:nil];
  [alert show];
}

@end
