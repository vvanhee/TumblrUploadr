# iPhone code to upload multiple photos to Flickr API as a slideshow / photoset

If you use this code, [please upvote my response on Stack Overflow here](http://stackoverflow.com/questions/6878662/tumblr-api-how-to-upload-multiple-images-to-a-photoset/7431731#7431731).

Steps to get this to work:

Copy all files to a group in your project.  
In your MyViewController.h, import the header and register the TumblrUploadrDelegate like so:

    #import "TumblrUploadr.h"
    
    @interface MyViewController : UIViewController <TumblrUploadrDelegate, AnotherDelegate> {
    ...
    }

Now add your tumblr Consumer Key and Secret to the top of TumblrUploader.m!!  You'll also need an OAuth access token key and secret which you will add in the appropriate place below. (Getting the access token is beyond the scope of this project, for now...)

In your MyViewController.m implementation file, make a function to upload the files.  For now, you should thread the process as shown because otherwise the UI will lock up. This only works for iOS 4.

    - (void) uploadFiles {
        NSData *data1 = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"picture1" ofType:@"jpg"]];
        NSData *data2 = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"picture2" ofType:@"jpg"]];
        NSArray *array = [NSArray arrayWithObjects:data1, data2, nil];
        dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            TumblrUploadr *tu = [[TumblrUploadr alloc] initWithNSDataForPhotos:array andBlogName:@"supergreatblog.tumblr.com" andDelegate:self andCaption:@"Great Photos!"];
            dispatch_async( dispatch_get_main_queue(), ^{
                [tu signAndSendWithTokenKey:@"myAccessTokenKey" andSecret:@"myAccessTokenSecret"];
            });
        });
    }

Then add the two delegate methods, one of which should be called:

    - (void) tumblrUploadr:(TumblrUploadr *)tu didFailWithError:(NSError *)error {
        NSLog(@"connection failed with error %@",[error localizedDescription]);
        [tu release];
    }
    - (void) tumblrUploadrDidSucceed:(TumblrUploadr *)tu withResponse:(NSString *)response {
        NSLog(@"connection succeeded with response: %@", response);
        [tu release];
    }
