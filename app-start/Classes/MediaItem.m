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

#import "MediaItem.h"

@interface MediaItem ()

@property(nonatomic, strong, readwrite) NSString *title;
@property(nonatomic, strong, readwrite) NSString *subtitle;
@property(nonatomic, strong, readwrite) NSString *studio;
@property(nonatomic, strong, readwrite) NSURL *url;
@property(nonatomic, strong, readwrite) NSURL *imageURL;
@property(nonatomic, strong, readwrite) NSURL *posterURL;
@property(nonatomic, readwrite) NSInteger duration;
@property(nonatomic, strong, readwrite) NSMutableArray *items;
@property(nonatomic, strong, readwrite) MediaItem *parent;
@property(nonatomic, assign, readwrite) BOOL nowPlaying;

@end

@implementation MediaItem

- (instancetype)initWithTitle:(NSString *)title
                     subtitle:(NSString *)subtitle
                       studio:(NSString *)studio
                          url:(NSURL *)url
                     imageURL:(NSURL *)imageURL
                    posterURL:(NSURL *)posterURL
                     duration:(NSInteger)duration
                       parent:(MediaItem *)parent {
  if (self = [super init]) {
    _title = title;
    _subtitle = subtitle;
    _studio = studio;
    _items = [[NSMutableArray alloc] init];
    _url = url;
    _imageURL = imageURL;
    _posterURL = posterURL;
    _duration = duration;
    _parent = parent;
  }
  return self;
}

@end