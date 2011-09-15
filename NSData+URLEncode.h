//
//  NSData+URLEncode.h
//  Displayr
//
//  Created by Victor Van Hee on 9/14/11 http://www.totagogo.com
//  Uses code from Scott James Remnant's NSString+URLEncode category
//

#import <Foundation/Foundation.h>

@interface NSData (NSData_URLEncode)

- (NSString *)encodeForURL;
- (NSString *)stringWithoutURLEncoding;
- (NSString *)encodeForOauthBaseString;

@end
