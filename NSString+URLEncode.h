//
//  NSString+URLEncode.h
//
//  Created by Scott James Remnant on 6/1/11.
//  Copyright 2011 Scott James Remnant <scott@netsplit.com>. All rights reserved.
//
//  encodeForURLFromData: addition by Victor C. Van Hee http://www.totagogo.com

#import <Foundation/Foundation.h>


@interface NSString (NSString_URLEncode)

- (NSString *)encodeForURL;
- (NSString *)encodeForURLReplacingSpacesWithPlus;
- (NSString *)decodeFromURL;


@end
