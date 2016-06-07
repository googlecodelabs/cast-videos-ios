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

@interface AppDelegate () {
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

  _firstUserDefaultsSync = YES;
  [self syncWithUserDefaults];

  [[UIApplication sharedApplication]
      setStatusBarStyle:UIStatusBarStyleLightContent];

  return YES;
}

- (void)applicationWillTerminate:(UIApplication *)application {
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
  //_enableSDKLogging = NO;

  BOOL mediaNotificationsEnabled =
      [userDefaults boolForKey:kPrefEnableMediaNotifications];

  if (_firstUserDefaultsSync ||
      (_mediaNotificationsEnabled != mediaNotificationsEnabled)) {
    _mediaNotificationsEnabled = mediaNotificationsEnabled;
  }

  _firstUserDefaultsSync = NO;
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
