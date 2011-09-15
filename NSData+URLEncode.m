//
//  NSData+URLEncode.m
//  Displayr
//
//  Created by Victor Van Hee on 9/14/11.
//  Uses code from Scott James Remnant's NSString+URLEncode category
//

#import "NSData+URLEncode.h"

@implementation NSData (NSData_URLEncode)

- (NSString *) stringWithoutURLEncoding {
    NSString *hexDataDesc = [self description];
    hexDataDesc = [[hexDataDesc stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]] stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSMutableString * newString = [NSMutableString string];    
    for (int x=0; x<[hexDataDesc length]; x+=2) {
        NSString *component = [hexDataDesc substringWithRange:NSMakeRange(x, 2)];
        int value = 0;
        sscanf([component cStringUsingEncoding:NSASCIIStringEncoding], "%x", &value);
        if ((value <=46 && value >= 45) || (value <=57 && value >= 48) || (value <=90 && value >= 65) || (value == 95) || (value <=122 && value >= 97)) {  //48-57, 65-90, 97-122
            [newString appendFormat:@"%c", (char)value];
        }
        else {
            [newString appendFormat:@"%%%@", [component uppercaseString]];
        }
    }
    NSString *aNewString = [newString stringByReplacingOccurrencesOfString:@"%20" withString:@"+"];
    return aNewString;
}

- (NSString *) encodeForURL {
    NSString *newString = [self stringWithoutURLEncoding];
    newString = [newString stringByReplacingOccurrencesOfString:@"+" withString:@"%20"];
    const CFStringRef legalURLCharactersToBeEscaped = CFSTR("!*'();:@&=+$,/?#[]<>\"{}|\\`^% ");    
    NSString *urlEncodedString = [NSMakeCollectable(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)newString, NULL, legalURLCharactersToBeEscaped, kCFStringEncodingUTF8)) autorelease];
    
    return urlEncodedString;
    
}

- (NSString *) encodeForOauthBaseString {
    NSString *newString = [self encodeForURL];
    newString =[newString stringByReplacingOccurrencesOfString:@"%257E" withString:@"~"];
    return newString;
}

@end
