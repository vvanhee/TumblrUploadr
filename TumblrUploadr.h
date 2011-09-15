//
//  TumblrUploadr.h
//  Displayr
//
//  Created by Victor Van Hee on 9/14/11.
//  Uses code from Scott James Remnant 
//

#import <Foundation/Foundation.h>

typedef enum _ASIOAuthSignatureMethod2 {
    ASIOAuthPlaintextSignatureMethod2,
    ASIOAuthHMAC_SHA1SignatureMethod2,
} ASIOAuthSignatureMethod2;

@protocol TumblrUploadrDelegate;

@interface TumblrUploadr : NSObject {
    NSURL *url;
    id <TumblrUploadrDelegate> delegate;
    NSMutableArray *params;
    NSMutableData *responseData;
    NSString *blogName;
    NSArray *photoDataArray;
    NSMutableURLRequest *request;
    NSString *caption;
}


- (void) signAndSendWithTokenKey:(NSString *)key andSecret:(NSString *)secret;

- (void)signRequestWithClientIdentifier:(NSString *)clientIdentifier
                                 secret:(NSString *)clientSecret
                        tokenIdentifier:(NSString *)tokenIdentifier
                                 secret:(NSString *)tokenSecret
                            usingMethod:(ASIOAuthSignatureMethod2)signatureMethod;

- (void)signRequestWithClientIdentifier:(NSString *)clientIdentifier
                                 secret:(NSString *)clientSecret
                        tokenIdentifier:(NSString *)tokenIdentifier
                                 secret:(NSString *)tokenSecret
                               verifier:(NSString *)verifier
                            usingMethod:(ASIOAuthSignatureMethod2)signatureMethod;

- (id)initWithNSDataForPhotos:(NSArray *)aPhotoDataArray andBlogName:(NSString *)aBlogName andDelegate:(id)aDelegate;

- (id)initWithNSDataForPhotos:(NSArray *)aPhotoDataArray andBlogName:(NSString *)aBlogName andDelegate:(id)aDelegate andCaption:(NSString *)aCaption;

@property (nonatomic, retain) NSURL *url;
@property (nonatomic, assign) id <TumblrUploadrDelegate> delegate;
@property (nonatomic, retain) NSMutableArray *params;
@property (nonatomic, retain) NSMutableData *responseData;
@property (nonatomic, retain) NSString *blogName;
@property (nonatomic, retain) NSArray *photoDataArray;
@property (nonatomic, retain) NSMutableURLRequest *request;
@property (nonatomic, retain) NSString *caption;


@end

@protocol TumblrUploadrDelegate

- (void) tumblrUploadr:(TumblrUploadr *)tu didFailWithError:(NSError *)error;
- (void) tumblrUploadrDidSucceed:(TumblrUploadr *)tu withResponse:(NSString *)response;

@end
