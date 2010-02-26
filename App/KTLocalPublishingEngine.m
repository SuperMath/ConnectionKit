//
//  KTTransferController.m
//  Marvel
//
//  Created by Terrence Talbot on 10/30/08.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTLocalPublishingEngine.h"

#import "KTAbstractPage+Internal.h"
#import "KTDesign.h"
#import "KTSite.h"
#import "KTHostProperties.h"
#import "KTPage.h"
#import "SVPublishingRecord.h"
#import "KTURLCredentialStorage.h"

#import "NSManagedObjectContext+KTExtensions.h"

#import "NSBundle+Karelia.h"
#import "NSData+Karelia.h"
#import "NSError+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"

#import "KSUtilities.h"


@interface KTLocalPublishingEngine ()
- (void)pingURL:(NSURL *)URL;
@end


#pragma mark -


@implementation KTLocalPublishingEngine

#pragma mark -
#pragma mark Init & Dealloc

- (id)initWithSite:(KTSite *)site onlyPublishChanges:(BOOL)publishChanges;
{
	OBPRECONDITION(site);
    
    KTHostProperties *hostProperties = [site hostProperties];
    NSString *docRoot = [hostProperties documentRoot];
    NSString *subfolder = [hostProperties subfolder];
    
    if (self = [super initWithSite:site documentRootPath:docRoot subfolderPath:subfolder])
	{
		_onlyPublishChanges = publishChanges;
        
        // These notifications are used to mark objects non-stale
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(transferRecordDidFinish:)
                                                     name:CKTransferRecordTransferDidFinishNotification
                                                   object:nil];
	}
	
	return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (BOOL)onlyPublishChanges { return _onlyPublishChanges; }

#pragma mark -
#pragma mark Connection

/*  Once publishing is fully complete, without any errors, ping google if there is a sitemap
 */
- (void)engineDidPublish:(BOOL)didPublish error:(NSError *)error
{
    if (didPublish)
    {
        // Ping google about the sitemap if there is one
        if ([[self site] boolForKey:@"generateGoogleSitemap"])
        {
            NSURL *siteURL = [[[self site] hostProperties] siteURL];
            NSURL *sitemapURL = [siteURL URLByAppendingPathComponent:@"sitemap.xml.gz" isDirectory:NO];
            
            NSString *pingURLString = [[NSString alloc] initWithFormat:
                                       @"http://www.google.com/webmasters/tools/ping?sitemap=%@",
                                       [[sitemapURL absoluteString] stringByAddingURLQueryPercentEscapes]];
            
            NSURL *pingURL = [[NSURL alloc] initWithString:pingURLString];
            [pingURLString release];
            
            [self pingURL:pingURL];
            [pingURL release];
        }
        
        
        // ping JS-Kit
        KTMaster *master = [[[self site] rootPage] master];
        if ( nil != master )
        {
            if ( [master wantsJSKit] && (nil != [master JSKitModeratorEmail]) )
            {
                NSURL *siteURL = [[[self site] hostProperties] siteURL];
                
                NSString *pingURLString = [[NSString alloc] initWithFormat:
                                           @"http://js-kit.com/api/isv/site-bind?email=%@&site=%@&confirmviaemail=%@",
                                           [[master JSKitModeratorEmail] stringByAddingPercentEscapesWithSpacesAsPlusCharacters:YES],
                                           [[siteURL absoluteString] stringByAddingPercentEscapesWithSpacesAsPlusCharacters:YES],
										   ([[NSUserDefaults standardUserDefaults] boolForKey:@"JSKitConfirmModeratorViaEmail"] ? @"YES" : @"NO")];
                
                NSURL *pingURL = [[NSURL alloc] initWithString:pingURLString];
                [pingURLString release];
                
                [self pingURL:pingURL];
                [pingURL release];
            }
        }
        
        
        // Record the app version published with
        NSManagedObject *hostProperties = [[self site] hostProperties];
        [hostProperties setValue:[[NSBundle mainBundle] marketingVersion] forKey:@"publishedAppVersion"];
        [hostProperties setValue:[[NSBundle mainBundle] buildVersion] forKey:@"publishedAppBuildVersion"];
    }
    
    
    [super engineDidPublish:didPublish error:error];
}

/*	Supplement the default behaviour by also deleting any existing file first if the user requests it.
 */
- (CKTransferRecord *)uploadContentsOfURL:(NSURL *)localURL toPath:(NSString *)remotePath
{
	OBPRECONDITION(localURL);
    OBPRECONDITION([localURL isFileURL]);
    OBPRECONDITION(remotePath);
    
    
    if ([[[self site] hostProperties] boolForKey:@"deletePagesWhenPublishing"])
	{
		[[self connection] deleteFile:remotePath];
	}
	
    return [super uploadContentsOfURL:localURL toPath:remotePath];
    
}

- (CKTransferRecord *)uploadData:(NSData *)data toPath:(NSString *)remotePath
{
	OBPRECONDITION(data);
    OBPRECONDITION(remotePath);
    
    
    if ([[[self site] hostProperties] boolForKey:@"deletePagesWhenPublishing"])
	{
		[[self connection] deleteFile:remotePath];
	}
    
	return [super uploadData:data toPath:remotePath];
}

#pragma mark -
#pragma mark Content Generation

/*  Called when a transfer we are observing finishes. Mark its corresponding object non-stale and
 *  stop observation.
 */
- (void)transferRecordDidFinish:(NSNotification *)notification
{
    CKTransferRecord *transferRecord = [notification object];
    
    if ([transferRecord root] != [self rootTransferRecord]) return; // it's not for us
    if ([transferRecord error]) return; // bail
    
    
    id object = [transferRecord propertyForKey:@"object"];
    NSString *path = [transferRecord propertyForKey:@"path"];
    
    
    //  Update publishing records to match
    if (path && ![transferRecord isDirectory])
    {
        SVPublishingRecord *record = [[[self site] hostProperties] regularFilePublishingRecordWithPath:path];
        
        NSData *digest = [transferRecord propertyForKey:@"dataDigest"];
        [record setSHA1Digest:digest];
    }
    
    
    // Any other processing (left over from 1.6 really)
    if ([self status] > KTPublishingEngineStatusNotStarted &&
        [self status] < KTPublishingEngineStatusFinished)
    {
        if ([object isKindOfClass:[KTAbstractPage class]])
        {
            [object setPublishedPath:path];
        }
        else if ([object isKindOfClass:[KTDesign class]])
        {
            // Record the version of the design published
            NSManagedObjectContext *moc = [[self site] managedObjectContext];
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", [(KTDesign *)object identifier]];
            
            NSArray *designPublishingInfo = [moc fetchAllObjectsForEntityForName:@"DesignPublishingInfo"
                                                             predicate:predicate
                                                                 error:NULL];
            
            [designPublishingInfo setValue:[(KTDesign *)object marketingVersion] forKey:@"versionLastPublished"];
        }
        else if ([object isKindOfClass:[KTMaster class]])
        {
        }
        else
        {
            // It's probably a simple media object. Mark it non-stale.
            [object setBool:NO forKey:@"isStale"];
        }
    }
}

- (BOOL)shouldUploadHTML:(NSString *)HTML
                encoding:(NSStringEncoding)encoding
                 forPage:(KTAbstractPage *)page
                  toPath:(NSString *)uploadPath
                  digest:(NSData **)outDigest;
{
    // Generate data digest. It has to ignore the app version string
    NSString *versionString = [NSString stringWithFormat:@"<meta name=\"generator\" content=\"%@\" />",
                               [[self site] appNameVersion]];
    NSString *versionFreeHTML = [HTML stringByReplacing:versionString with:@"<meta name=\"generator\" content=\"Sandvox\" />"];
    NSData *digest = [[versionFreeHTML dataUsingEncoding:encoding allowLossyConversion:YES] SHA1HashDigest];
    
    
	
	// Don't upload if the page isn't stale and we've been requested to only publish changes
	if ([self onlyPublishChanges])
    {
        SVPublishingRecord *record = [[[self site] hostProperties] publishingRecordForPath:uploadPath];
        NSData *publishedDataDigest = [record SHA1Digest];
        NSString *publishedPath = [page publishedPath];
        
        if (publishedDataDigest &&
            (!publishedPath || [uploadPath isEqualToPOSIXPath:publishedPath]) &&   // 1.5.1 and earlier didn't store -publishedPath
            [publishedDataDigest isEqualToData:digest])
        {
            return NO;
        }
    }
    
    
    *outDigest = digest;
    return YES;
}

- (void)uploadMediaIfNeeded:(KTMediaFileUpload *)media
{
    if (![self onlyPublishChanges] || [media boolForKey:@"isStale"])
    {
        [super uploadMediaIfNeeded:media];
    }
}

/*  This method gets called once all pages, media and designs have been processed. If there's nothing
 *  queued to be uploaded at this point, we want to cancel and tell the user
 */
- (BOOL)uploadResourceFiles
{
    if ([self onlyPublishChanges] && [[[self baseTransferRecord] contents] count] == 0)
    {
        // Fake an error that the window controller will use to close itself
        NSError *error = [NSError errorWithDomain:KTPublishingEngineErrorDomain
											 code:KTPublishingEngineNothingToPublish
										 userInfo:nil];
        [self engineDidPublish:NO error:error];
        return NO;
    }
    else
    {
        return [super uploadResourceFiles];
    }
}

#pragma mark -
#pragma mark Design

- (void)uploadDesignIfNeeded
{
    // When publishing changes, only upload the design if its published version is different to the current one
    KTMaster *master = [[[self site] rootPage] master];
    KTDesign *design = [master design];
    if (![self onlyPublishChanges] ||
        ![[design marketingVersion] isEqualToString:[master valueForKeyPath:@"designPublishingInfo.versionLastPublished"]])
    {
        [super uploadDesignIfNeeded];
    }
}

- (BOOL)shouldUploadMainCSSData:(NSData *)mainCSSData toPath:(NSString *)path digest:(NSData **)outDigest;
{
    BOOL result = YES;
    
    NSData *digest = [mainCSSData SHA1HashDigest];
    
    SVPublishingRecord *record = [[[self site] hostProperties] publishingRecordForPath:path];
    NSData *publishedDigest = [record SHA1Digest];
    
    if ([self onlyPublishChanges] && publishedDigest && [publishedDigest isEqualToData:digest])
    {
        result = NO;
    }
    
    if (digest) *outDigest = digest;
    
    return result;
}

#pragma mark -
#pragma mark Ping

/*  Sends a GET request to the URL but does nothing with the result.
 */
- (void)pingURL:(NSURL *)URL
{
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:URL
                                                  cachePolicy:NSURLRequestReloadIgnoringCacheData
                                              timeoutInterval:10.0];
    
    [NSURLConnection connectionWithRequest:request delegate:nil];
    [request release];
}

@end
