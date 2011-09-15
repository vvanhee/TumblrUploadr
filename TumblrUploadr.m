//
//  TumblrUploadr.m
//  Displayr
//
//  Created by Victor Van Hee on 9/14/11.
//  Uses code from Scott James Remnant 
//

#import "TumblrUploadr.h"
#include <sys/time.h>

#import <CommonCrypto/CommonHMAC.h>
#import "NSData+Base64.h"
#import "NSString+URLEncode.h"
#import "NSData+URLEncode.h"


static NSString *tumblrConsumerKey = @"ENTER ME HERE";
static NSString *tumblrConsumerSecret = @"ENTER ME HERE";

// Signature Method strings, keep in sync with ASIOAuthSignatureMethod
static const NSString *oauthSignatureMethodName[] = {
    @"PLAINTEXT",
    @"HMAC-SHA1",
};

// OAuth version implemented here
static const NSString *oauthVersion = @"1.0";

@implementation TumblrUploadr

@synthesize url, delegate, params,responseData, blogName, photoDataArray, request, caption;

- (id)initWithNSDataForPhotos:(NSArray *)aPhotoDataArray andBlogName:(NSString *)aBlogName andDelegate:(id)aDelegate {
    [self initWithNSDataForPhotos:aPhotoDataArray andBlogName:aBlogName andDelegate:aDelegate andCaption:nil];
    return self;
}

- (id)initWithNSDataForPhotos:(NSArray *)aPhotoDataArray andBlogName:(NSString *)aBlogName andDelegate:(id)aDelegate andCaption:(NSString *)aCaption {
    self = [super init];
    if (self) {
        self.delegate = aDelegate;
        self.blogName = aBlogName;
        self.photoDataArray = aPhotoDataArray;
        self.caption = aCaption;
        self.url = [NSURL URLWithString:[NSString stringWithFormat:@"http://api.tumblr.com/v2/blog/%@/post",[self blogName]]];
        NSMutableData *someResponseData = [NSMutableData data];
        [self setResponseData:someResponseData];
        NSMutableURLRequest *aRequest = [NSMutableURLRequest requestWithURL:self.url];
        self.request = aRequest;
        self.request.HTTPMethod = @"POST";
        NSMutableArray *someParams = [NSMutableArray arrayWithCapacity:[photoDataArray count]+1];
        [self setParams:someParams];
        for (NSData *photoData in photoDataArray) {
            NSString *thisKey = [NSString stringWithFormat:@"data%%5B%d%%5D",[photoDataArray indexOfObject:photoData]];
            //NSLog(@"this key:%@",thisKey );
            [params addObject:[NSDictionary dictionaryWithObjectsAndKeys:thisKey, @"key", [photoData stringWithoutURLEncoding], @"value", nil]];
        }
        [params addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"type", @"key", @"photo", @"value", nil]];
        if (self.caption !=nil) {
            [params addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"caption", @"key", [self.caption encodeForURL], @"value", nil]];
        }
        //    [request setHTTPBody:XXX];
        [request setValue:[self.url host] forHTTPHeaderField:@"Host"];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-type"];

    }
    return self;
}


- (void) signAndSendWithTokenKey:(NSString *)key andSecret:(NSString *)secret {
    [self signRequestWithClientIdentifier:tumblrConsumerKey secret:tumblrConsumerSecret tokenIdentifier:key secret:secret usingMethod:ASIOAuthHMAC_SHA1SignatureMethod2];
	[[NSURLConnection alloc] initWithRequest:request delegate:self];    
}


- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	[responseData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[responseData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [connection release];
    [delegate tumblrUploadr:self didFailWithError:error];
    self.request = nil;
    self.responseData = nil;
    self.photoDataArray = nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	[connection release];
    NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    [delegate tumblrUploadrDidSucceed:self withResponse:responseString];
	[responseString release];
    self.request = nil;
    self.responseData = nil;
    self.photoDataArray = nil;
}


#pragma mark -
#pragma mark Timestamp and nonce handling

- (NSArray *)oauthGenerateTimestampAndNonce
{
    static time_t last_timestamp = -1;
    static NSMutableSet *nonceHistory = nil;
    
    // Make sure we never send the same timestamp and nonce
    if (!nonceHistory)
        nonceHistory = [[NSMutableSet alloc] init];
    
    struct timeval tv;
    NSString *timestamp, *nonce;
    do {
        // Get the time of day, for both the timestamp and the random seed
        gettimeofday(&tv, NULL);
        
        // Generate a random alphanumeric character sequence for the nonce
        char nonceBytes[16];
        srandom(tv.tv_sec | tv.tv_usec);
        for (int i = 0; i < 16; i++) {
            int byte = random() % 62;
            if (byte < 26)
                nonceBytes[i] = 'a' + byte;
            else if (byte < 52)
                nonceBytes[i] = 'A' + byte - 26;
            else
                nonceBytes[i] = '0' + byte - 52;
        }
        
        timestamp = [NSString stringWithFormat:@"%d", tv.tv_sec];
        nonce = [NSString stringWithFormat:@"%.16s", nonceBytes];
    } while ((tv.tv_sec == last_timestamp) && [nonceHistory containsObject:nonce]);
    
    if (tv.tv_sec != last_timestamp) {
        last_timestamp = tv.tv_sec;
        [nonceHistory removeAllObjects];
    }
    [nonceHistory addObject:nonce];
    
    return [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjectsAndKeys:@"oauth_timestamp", @"key", timestamp, @"value", nil], [NSDictionary dictionaryWithObjectsAndKeys:@"oauth_nonce", @"key", nonce, @"value", nil], nil];
}


#pragma mark -
#pragma mark Signature base string construction

- (NSString *)oauthBaseStringURI
{
    NSAssert1([self.url host] != nil, @"URL host missing: %@", [self.url absoluteString]);
    
    // Port need only be present if it's not the default
    NSString *hostString;
    if (([self.url port] == nil)
        || ([[[self.url scheme] lowercaseString] isEqualToString:@"http"] && ([[self.url port] integerValue] == 80))
        || ([[[self.url scheme] lowercaseString] isEqualToString:@"https"] && ([[self.url port] integerValue] == 443))) {
        hostString = [[self.url host] lowercaseString];
    } else {
        hostString = [NSString stringWithFormat:@"%@:%@", [[self.url host] lowercaseString], [self.url port]];
    }
    
    // Annoyingly [self.url path] is decoded and has trailing slashes stripped, so we have to manually extract the path without the query or fragment
    NSString *pathString = [[self.url absoluteString] substringFromIndex:[[self.url scheme] length] + 3];
    NSRange pathStart = [pathString rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
    NSRange pathEnd = [pathString rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"?#"]];
    if (pathEnd.location != NSNotFound) {
        pathString = [pathString substringWithRange:NSMakeRange(pathStart.location, pathEnd.location - pathStart.location)];
    } else {
        pathString = [pathString substringFromIndex:pathStart.location];
    }
    
    return [NSString stringWithFormat:@"%@://%@%@", [[self.url scheme] lowercaseString], hostString, pathString];
}

- (NSString *)oauthRequestParameterString:(NSArray *)oauthParameters
{
    NSMutableArray *parameters = [NSMutableArray array];
    /*
    // Decode the parameters given in the query string, and add their encoded counterparts
    NSArray *pairs = [[self.url query] componentsSeparatedByString:@"&"];
    for (NSString *pair in pairs) {
        NSString *key, *value;
        NSRange separator = [pair rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"="]];
        if (separator.location != NSNotFound) {
            key = [[pair substringToIndex:separator.location] decodeFromURL];
            value = [[pair substringFromIndex:separator.location + 1] decodeFromURL];
        } else {
            key = [pair decodeFromURL];
            value = @"";
        }
        
        [parameters addObject:[NSDictionary dictionaryWithObjectsAndKeys:[key encodeForURL], @"key", [value encodeForURL], @"value", nil]];
    }
    */
    // Add the encoded counterparts of the parameters in the OAuth header
    for (NSDictionary *param in oauthParameters) {
        NSString *key = [param objectForKey:@"key"];
        if ([key hasPrefix:@"oauth_"]
            && ![key isEqualToString:@"oauth_signature"])
            [parameters addObject:[NSDictionary dictionaryWithObjectsAndKeys:[key encodeForURL], @"key", [[param objectForKey:@"value"] encodeForURL], @"value", nil]];
    }
    
    for (NSDictionary *param in self.params) {
        [parameters addObject:[NSDictionary dictionaryWithObjectsAndKeys:[param objectForKey:@"key"], @"key", [[[[param objectForKey:@"value"] stringByReplacingOccurrencesOfString:@"+" withString:@"%20"] encodeForURL] stringByReplacingOccurrencesOfString:@"%257E" withString:@"~"] , @"value", nil]];
        // NSLog(@"adding parameter: %@ for key: %@",[[parameters lastObject] objectForKey:@"value"],[[parameters lastObject] objectForKey:@"key"]); 
    }
    // Sort by name and value
    [parameters sortUsingComparator:^(id obj1, id obj2) {
        NSDictionary *val1 = obj1, *val2 = obj2;
        NSComparisonResult result = [[val1 objectForKey:@"key"] compare:[val2 objectForKey:@"key"] options:NSLiteralSearch];
        if (result != NSOrderedSame)
            return result;
        
        return [[val1 objectForKey:@"value"] compare:[val2 objectForKey:@"value"] options:NSLiteralSearch];
    }];
    
    // Join components together
    NSMutableArray *parameterStrings = [NSMutableArray array];
    for (NSDictionary *parameter in parameters)
        [parameterStrings addObject:[NSString stringWithFormat:@"%@%%3D%@", [parameter objectForKey:@"key"], [parameter objectForKey:@"value"]]];
   // NSLog(@"parameters : %@",[parameterStrings componentsJoinedByString:@"%26"]);
    return [parameterStrings componentsJoinedByString:@"%26"];
}


#pragma mark -
#pragma mark Signing algorithms

- (NSString *)oauthGeneratePlaintextSignatureFor:(NSString *)baseString
                                withClientSecret:(NSString *)clientSecret
                                  andTokenSecret:(NSString *)tokenSecret
{
    // Construct the signature key
    return [NSString stringWithFormat:@"%@&%@", clientSecret != nil ? [clientSecret encodeForURL] : @"", tokenSecret != nil ? [tokenSecret encodeForURL] : @""];
}

- (NSString *)oauthGenerateHMAC_SHA1SignatureFor:(NSString *)baseString
                                withClientSecret:(NSString *)clientSecret
                                  andTokenSecret:(NSString *)tokenSecret
{
	
    NSString *key = [self oauthGeneratePlaintextSignatureFor:baseString withClientSecret:clientSecret andTokenSecret:tokenSecret];
    
    const char *keyBytes = [key cStringUsingEncoding:NSUTF8StringEncoding];
    const char *baseStringBytes = [baseString cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char digestBytes[CC_SHA1_DIGEST_LENGTH];
    
	CCHmacContext ctx;
    CCHmacInit(&ctx, kCCHmacAlgSHA1, keyBytes, strlen(keyBytes));
	CCHmacUpdate(&ctx, baseStringBytes, strlen(baseStringBytes));
	CCHmacFinal(&ctx, digestBytes);
    
	NSData *digestData = [NSData dataWithBytes:digestBytes length:CC_SHA1_DIGEST_LENGTH];
    return [digestData base64EncodedString];
}


#pragma mark -
#pragma mark Public methods

- (void)signRequestWithClientIdentifier:(NSString *)clientIdentifier
                                 secret:(NSString *)clientSecret
                        tokenIdentifier:(NSString *)tokenIdentifier
                                 secret:(NSString *)tokenSecret
                            usingMethod:(ASIOAuthSignatureMethod2)signatureMethod
{
    [self signRequestWithClientIdentifier:clientIdentifier secret:clientSecret tokenIdentifier:tokenIdentifier 
                                   secret:tokenSecret verifier:nil usingMethod:signatureMethod];
}

- (void)signRequestWithClientIdentifier:(NSString *)clientIdentifier
                                 secret:(NSString *)clientSecret
                        tokenIdentifier:(NSString *)tokenIdentifier
                                 secret:(NSString *)tokenSecret
                               verifier:(NSString *)verifier
                            usingMethod:(ASIOAuthSignatureMethod2)signatureMethod
{
    //[self buildPostBody];
    
    NSMutableArray *oauthParameters = [NSMutableArray array];
    
    // Add what we know now to the OAuth parameters
    //if (self.authenticationRealm)
    //    [oauthParameters addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"realm", @"key", self.authenticationRealm, @"value", nil]];
    [oauthParameters addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"oauth_version", @"key", oauthVersion, @"value", nil]];
    [oauthParameters addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"oauth_consumer_key", @"key", clientIdentifier, @"value", nil]];
    if (tokenIdentifier != nil)
        [oauthParameters addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"oauth_token", @"key", tokenIdentifier, @"value", nil]];
    if (verifier != nil)
        [oauthParameters addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"oauth_verifier", @"key", verifier, @"value", nil]];
    [oauthParameters addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"oauth_signature_method", @"key", oauthSignatureMethodName[signatureMethod], @"value", nil]];
    [oauthParameters addObjectsFromArray:[self oauthGenerateTimestampAndNonce]];    
    ///[oauthParameters addObjectsFromArray:[self oauthAdditionalParametersForMethod:signatureMethod]];
    
    // Construct the signature base string
    NSString *baseStringURI = [self oauthBaseStringURI];
    NSString *requestParameterString = [self oauthRequestParameterString:oauthParameters];
    NSString *baseString = [NSString stringWithFormat:@"%@&%@&%@", @"POST", [baseStringURI encodeForURL], requestParameterString];
    //NSLog(@"this is the baseString: %@",baseString);
    
    ///now can we set the post body??
    NSMutableArray *parameterStringsForBody = [NSMutableArray array];
    for (NSDictionary *parameter in params)
            [parameterStringsForBody addObject:[NSString stringWithFormat:@"%@=%@", [parameter objectForKey:@"key"], [parameter objectForKey:@"value"]]];
    NSString *stringForBody = [parameterStringsForBody componentsJoinedByString:@"&"];
    [request setHTTPBody:[stringForBody dataUsingEncoding:NSUTF8StringEncoding]];
    
    //NSLog(@"this is the body: %@",stringForBody);
    
    // Generate the signature
    NSString *signature;
    switch (signatureMethod) {
        case ASIOAuthPlaintextSignatureMethod2:
            signature = [self oauthGeneratePlaintextSignatureFor:baseString withClientSecret:clientSecret andTokenSecret:tokenSecret];
            break;
        case ASIOAuthHMAC_SHA1SignatureMethod2:
            signature = [self oauthGenerateHMAC_SHA1SignatureFor:baseString withClientSecret:clientSecret andTokenSecret:tokenSecret];
            break;
    }
    [oauthParameters addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"oauth_signature", @"key", signature, @"value", nil]];
    
    // Set the Authorization header
    NSMutableArray *oauthHeader = [NSMutableArray array];
    for (NSDictionary *param in oauthParameters)
        [oauthHeader addObject:[NSString stringWithFormat:@"%@=\"%@\"", [[param objectForKey:@"key"] encodeForURL], [[param objectForKey:@"value"] encodeForURL]]];
    
    [request setValue:[NSString stringWithFormat:@"OAuth %@", [oauthHeader componentsJoinedByString:@", "]] forHTTPHeaderField:@"Authorization"];
}


- (void) dealloc {
    [url release];
    [params release];
    [responseData release];
    [blogName release];
    [photoDataArray release];
    [request release];
    [caption release];
    [super dealloc];
}

@end
