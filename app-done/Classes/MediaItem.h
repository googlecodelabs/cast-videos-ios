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
#import <Foundation/Foundation.h>

/**
 * An object representing a media item (or a container group of media items).
 */
@interface MediaItem : NSObject

/** The title of the item. */
@property(nonatomic, strong, readonly) NSString *title;
/** The subtitle of the item. */
@property(nonatomic, strong, readonly) NSString *subtitle;
/** The studio of the item. */
@property(nonatomic, strong, readonly) NSString *studio;
/** The URL of the item. */
@property(nonatomic, strong, readonly) NSURL *url;
/** The URL of the image for the item. */
@property(nonatomic, strong, readonly) NSURL *imageURL;
/** The URL of the poster image for the item. */
@property(nonatomic, strong, readonly) NSURL *posterURL;
/** The duration of the item. */
@property(nonatomic, readonly) NSInteger duration;
/** The list of child items, if any. If this is not a group, this will be an
 * empty array. */
@property(nonatomic, strong, readonly) NSMutableArray *items;
/** The parent item of this item, or <code>nil</code> if this is the root item.
 */
@property(nonatomic, strong, readonly) MediaItem *parent;

/** Initializer for constructing a group item.
 *
 * @param title The title of the item.
 * @param imageURL The URL of the image for this item.
 * @param parent The parent item of this item, if any.
 */
- (instancetype)initWithTitle:(NSString *)title
                     subtitle:(NSString *)subtitle
                       studio:(NSString *)studio
                          url:(NSURL *)url
                     imageURL:(NSURL *)imageURL
                    posterURL:(NSURL *)posterURL
                     duration:(NSInteger)duration
                       parent:(MediaItem *)parent;

@end
