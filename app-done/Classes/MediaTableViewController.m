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

#import "AppDelegate.h"
#import "MediaItem.h"
#import "MediaListModel.h"
#import "MediaTableViewController.h"
#import "MediaViewController.h"
#import "SimpleImageFetcher.h"
#import "Toast.h"

static NSString *const kPrefMediaListURL = @"media_list_url";

@interface MediaTableViewController ()<MediaListModelDelegate> {
  UIImageView *_rootTitleView;
  UIView *_titleView;
  NSURL *_mediaListURL;
  ActionSheet *_actionSheet;
  MediaItem *selectedItem;
}

/** The media to be displayed. */
@property(nonatomic) MediaListModel *mediaList;

@end

@implementation MediaTableViewController

- (void)setRootItem:(MediaItem *)rootItem {
  _rootItem = rootItem;
  self.title = rootItem.title;
  [self.tableView reloadData];
}

- (void)viewDidLoad {
  NSLog(@"MediaTableViewController - viewDidLoad");
  [super viewDidLoad];

  _titleView = self.navigationItem.titleView;
  _rootTitleView = [[UIImageView alloc]
      initWithImage:[UIImage imageNamed:@"logo_castvideos.png"]];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(loadMediaList)
             name:NSUserDefaultsDidChangeNotification
           object:nil];
  if (!self.rootItem) {
    [self loadMediaList];
  }

  GCKUICastButton *castButton =
      [[GCKUICastButton alloc] initWithFrame:CGRectMake(0, 0, 24, 24)];
  castButton.tintColor = [UIColor whiteColor];
  self.navigationItem.rightBarButtonItem =
      [[UIBarButtonItem alloc] initWithCustomView:castButton];

  self.tableView.separatorColor = [UIColor clearColor];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  NSLog(@"viewWillAppear");

  if (!self.rootItem.parent) {
    // If this is the root group, show stylized application title in the title
    // view.
    self.navigationItem.titleView = _rootTitleView;
  } else {
    // Otherwise show the title of the group in the title view.
    self.navigationItem.titleView = _titleView;
    self.title = self.rootItem.title;
  }
  appDelegate.castControlBarsEnabled = YES;
  [self.navigationController.navigationBar sizeToFit];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [[GCKCastContext sharedInstance] presentCastInstructionsViewControllerOnce];
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
  return [self.rootItem.items count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell =
      [tableView dequeueReusableCellWithIdentifier:@"MediaCell"];

  MediaItem *item =
      (MediaItem *)[self.rootItem.items objectAtIndex:indexPath.row];

  NSString *detail = item.studio;

  UILabel *mediaTitle = (UILabel *)[cell viewWithTag:1];
  UILabel *mediaOwner = (UILabel *)[cell viewWithTag:2];

  if ([mediaTitle respondsToSelector:@selector(setAttributedText:)]) {
    NSString *titleText = item.title;
    NSString *ownerText = detail;

    NSString *text =
        [NSString stringWithFormat:@"%@\n%@", titleText, ownerText];

    NSDictionary *attribs = @{
      NSForegroundColorAttributeName : mediaTitle.textColor,
      NSFontAttributeName : mediaTitle.font
    };
    NSMutableAttributedString *attributedText =
        [[NSMutableAttributedString alloc] initWithString:text
                                               attributes:attribs];

    UIColor *blackColor = [UIColor blackColor];
    NSRange titleTextRange = NSMakeRange(0, [titleText length]);
    [attributedText setAttributes:@{
      NSForegroundColorAttributeName : blackColor
    }
                            range:titleTextRange];

    UIColor *lightGrayColor = [UIColor lightGrayColor];
    NSRange ownerTextRange =
        NSMakeRange([titleText length] + 1, [ownerText length]);
    [attributedText setAttributes:@{
      NSForegroundColorAttributeName : lightGrayColor,
      NSFontAttributeName : [UIFont systemFontOfSize:12]
    }
                            range:ownerTextRange];

    mediaTitle.attributedText = attributedText;
    [mediaOwner setHidden:YES];
  } else {
    mediaTitle.text = item.title;
    mediaOwner.text = detail;
  }

  cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

  UIImageView *imageView = (UIImageView *)[cell.contentView viewWithTag:3];
  // Asynchronously load the table view image
  dispatch_queue_t queue =
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);

  dispatch_async(queue, ^{
    UIImage *image = [UIImage
        imageWithData:[SimpleImageFetcher getDataFromImageURL:item.imageURL]];

    dispatch_sync(dispatch_get_main_queue(), ^{
      [imageView setImage:image];
      [cell setNeedsLayout];
    });
  });

  UIButton *addButton = (UIButton *)[cell viewWithTag:4];
  [addButton setHidden:YES];

  return cell;
}
- (IBAction)playButtonClicked:(id)sender {
  NSLog(@"playButtonClicked");
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [self performSegueWithIdentifier:@"mediaDetails" sender:self];  // playMedia
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  NSLog(@"prepareForSegue");
  if ([[segue identifier] isEqualToString:@"mediaDetails"]) {
    MediaViewController *viewController =
        (MediaViewController *)[segue destinationViewController];
    MediaItem *mediaInfo = [self getSelectedItem];
    if (mediaInfo) {
      viewController.mediaInfo = mediaInfo;
    }
  }
}

- (MediaItem *)getSelectedItem {
  MediaItem *item = nil;
  NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
  if (indexPath) {
    NSLog(@"selected row is %@", indexPath);
    item = (MediaItem *)[self.rootItem.items objectAtIndex:indexPath.row];
  }
  return item;
}

#pragma mark - MediaListModelDelegate

- (void)mediaListModelDidLoad:(MediaListModel *)list {
  self.rootItem = self.mediaList.rootItem;
  self.title = self.mediaList.title;

  [self.tableView reloadData];
}

- (void)mediaListModel:(MediaListModel *)list
didFailToLoadWithError:(NSError *)error {
  NSString *errorMessage =
      [NSString stringWithFormat:@"Unable to load the media list from\n%@.",
                                 [_mediaListURL absoluteString]];
  UIAlertView *alert =
      [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cast Error", nil)
                                 message:NSLocalizedString(errorMessage, nil)
                                delegate:nil
                       cancelButtonTitle:NSLocalizedString(@"OK", nil)
                       otherButtonTitles:nil];
  [alert show];
}

- (void)loadMediaList {
  // Look up the media list URL.
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  NSString *urlKey = [userDefaults stringForKey:kPrefMediaListURL];
  NSString *urlText = [userDefaults stringForKey:urlKey];

  NSURL *mediaListURL = [NSURL URLWithString:urlText];

  if (_mediaListURL && [mediaListURL isEqual:_mediaListURL]) {
    // The URL hasn't changed; do nothing.
    return;
  }

  _mediaListURL = mediaListURL;

  // Asynchronously load the media json.
  AppDelegate *delegate =
      (AppDelegate *)[UIApplication sharedApplication].delegate;
  delegate.mediaList = [[MediaListModel alloc] init];
  self.mediaList = delegate.mediaList;
  self.mediaList.delegate = self;
  [self.mediaList loadFromURL:_mediaListURL];
}

@end
