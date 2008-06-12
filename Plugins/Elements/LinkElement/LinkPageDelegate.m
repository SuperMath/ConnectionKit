//
//  LinkPageDelegate.m
//  KTPlugins
//
//  Copyright (c) 2004-2005, Karelia Software. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  *  Redistribution of source code must retain the above copyright notice,
//     this list of conditions and the follow disclaimer.
//
//  *  Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other material provided with the distribution.
//
//  *  Neither the name of Karelia Software nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
//  Community Note: This code is distrubuted under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

//  NOTE: No LocalizedStrings in this plugin, so no genstrings build phase needed

#import "LinkPageDelegate.h"

#import <SandvoxPlugin.h>
//#import <ThirdParty.h>


@interface LinkPageDelegate ( Private )
- (NSString *)absolutePathAllowingIndexPage:(BOOL)aCanHaveIndexPage;
@end


@implementation LinkPageDelegate

#pragma mark -
#pragma mark Initialization

+ (void)initialize
{
	// Register our custom value transformer
	NSValueTransformer *transformer = [[ValuesAreEqualTransformer alloc] initWithComparisonValue:[NSNumber numberWithInt:iframeLink]];
	[NSValueTransformer setValueTransformer:transformer forName:@"ExternalPageLinkTypeIsPageWithinPage"];
	[transformer release];
}

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewObject
{
	[super awakeFromBundleAsNewlyCreatedObject:isNewObject];
	
	if ( isNewObject )
	{
		// Attempt to automatically grab the URL from the user's browser
		NSURL *theURL = nil;
		NSString *theTitle = nil;
		[NSAppleScript getWebBrowserURL:&theURL title:&theTitle source:nil];
		
		if (nil != theURL)
		{
			[[self pluginProperties] setObject:[theURL absoluteString] forKey:@"linkURL"];
		}
		if (nil != theTitle)
		{
			[[self delegateOwner] setTitleText:theTitle];
		}
		
		// Set our "show border" checkbox from the defaults
		[[self delegateOwner] setBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"iFramePageIsBordered"]
							   forKey:@"iFrameIsBordered"];
		
		// Make full page as appropriate
		int linkType = [[self delegateOwner] integerForKey:@"linkType"];
		if (linkType == plainLink || linkType == newWindowLink) {
			[[self delegateOwner] setPluginHTMLIsFullPage:YES];
		}
		else {
			[[self delegateOwner] setPluginHTMLIsFullPage:NO];
		}
	}
	
	KTPage *page = [self delegateOwner];
	int linkType = [page integerForKey:@"linkType"];
	BOOL linkTypeIsPageWithinPage = (linkType != plainLink && linkType != newWindowLink);
	[page setDisableComments:!linkTypeIsPageWithinPage];
	[page setSidebarChangeable:linkTypeIsPageWithinPage];
	[page setFileExtensionIsEditable:linkTypeIsPageWithinPage];
}

- (void)awakeFromDragWithDictionary:(NSDictionary *)aDictionary
{
	[super awakeFromDragWithDictionary:aDictionary];
	
	NSString *urlString = [aDictionary valueForKey:kKTDataSourceURLString];
	[[self delegateOwner] setValue:urlString forKey:@"linkURL"];
}

#pragma mark -
#pragma mark Plugin

- (void)setDelegateOwner:(KTPage *)plugin
{
	[[self delegateOwner] removeObserver:self forKeyPath:@"iFrameIsBordered"];
	[super setDelegateOwner:plugin];
	[[self delegateOwner] addObserver:self forKeyPath:@"iFrameIsBordered" options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (object == [self delegateOwner] && ![object isFault])
	{
		if ([keyPath isEqualToString:@"iFrameIsBordered"])
		{
			NSNumber *newValue = [change objectForKey:NSKeyValueChangeNewKey];
			if ([newValue isKindOfClass:[NSNumber class]])
			{
				[[NSUserDefaults standardUserDefaults] setBool:[newValue boolValue] forKey:@"iFramePageIsBordered"];
			}
		}
	}
}

/*	Keeps various page properties up-to-date with the plugin.
 */
- (void)plugin:(KTAbstractElement *)plugin didSetValue:(id)value forPluginKey:(NSString *)key oldValue:(id)oldValue;
{
	if ([key isEqualToString:@"linkType"])
	{
		int linkType = [value intValue];
		BOOL linkTypeIsPageWithinPage = (linkType != plainLink && linkType != newWindowLink);
		
		[[self delegateOwner] setPluginHTMLIsFullPage:!linkTypeIsPageWithinPage];
		[[self delegateOwner] setDisableComments:!linkTypeIsPageWithinPage];
		[[self delegateOwner] setSidebarChangeable:linkTypeIsPageWithinPage];
		[(KTPage *)plugin setFileExtensionIsEditable:linkTypeIsPageWithinPage];
		
		NSString *customPath = nil;
		if (!linkTypeIsPageWithinPage) customPath = [plugin valueForKey:@"linkURL"];
		[(KTPage *)plugin setCustomPathRelativeToSite:customPath];
	}
	else if ([key isEqualToString:@"linkURL"])
	{
		int linkType = [value intValue];
		BOOL linkTypeIsPageWithinPage = (linkType != plainLink && linkType != newWindowLink);
		if (!linkTypeIsPageWithinPage)
		{
			[(KTPage *)plugin setCustomPathRelativeToSite:value];
		}
	}
}

- (BOOL)validatePluginValue:(id *)ioValue forKeyPath:(NSString *)inKeyPath error:(NSError **)outError
{
	BOOL result = YES;
	
	if ([inKeyPath isEqualToString:@"linkURL"])
	{
		// Replace an empty entry with http://
		if (*ioValue == nil || [*ioValue isEqualToString:@""]) {
			*ioValue = @"http://";
		}
		
		*ioValue = [*ioValue stringWithValidURLScheme];
	}
	else if ([inKeyPath isEqualToString:@"iFrameWidth"])
	{
		if (*ioValue == nil || [*ioValue isEqual:@""]) {
			*ioValue = [NSNumber numberWithFloat:0.0];
		}
	}
	else
	{
		result = [super validatePluginValue:ioValue forKeyPath:inKeyPath error:outError];
	}
	
	return result;
}


#pragma mark Page methods

/*!	Cut a strict down to size
*/
// Called via recursiveComponentPerformSelector
- (void)findMinimumDocType:(void *)aDocTypePointer forPage:(KTPage *)aPage
{
	int *docType = (int *)aDocTypePointer;
	
	if (*docType > KTXHTMLTransitionalDocType)
	{
		*docType = KTXHTMLTransitionalDocType;
	}
}

- (NSString *)urlAllowingIndexPage:(BOOL)aCanHaveIndexPage  // for feeds, we return the URL of the site if it's not an iframe
{
	return [self absolutePathAllowingIndexPage:aCanHaveIndexPage];
}

#pragma mark -
#pragma mark Summary

/*	Should be a class method really, but Tiger doesn't support that for KVC.
 */
- (NSString *)iFrameTemplateHTML
{
	static NSString *result;
	
	if (!result)
	{
		NSBundle *bundle = [NSBundle bundleForClass:[self class]];
		NSString *templatePath = [bundle pathForResource:@"IFrameTemplate" ofType:@"html"];
		result = [[NSString alloc] initWithContentsOfFile:templatePath];
	}
	
	return result;
}

- (NSString *)summary
{
	KTHTMLParser *parser = [[KTHTMLParser alloc] initWithTemplate:[self iFrameTemplateHTML]
														component:[self delegateOwner]];
	
	[parser setHTMLGenerationPurpose:kGeneratingRemote];
	NSString *result = [parser parseTemplate];
	[parser release];
	
	return result;
}

/*	A summary is only available if using page-witin-page
 */
- (NSString *)summaryHTMLKeyPath
{
	NSString *result = nil;
	
	if ([[self delegateOwner] integerForKey:@"linkType"] == iframeLink)
	{
		result = @"delegate.summary";
	}
	
	return result;
}

- (BOOL)summaryHTMLIsEditable { return NO; }

#pragma mark -
#pragma mark Support

/*	We are overriding KTPage's default behaviour to force links to be in a new target */
- (BOOL)openInNewWindow
{
	return (newWindowLink == [[self delegateOwner] integerForKey:@"linkType"]);
}

- (NSString *)absolutePathAllowingIndexPage:(BOOL)aCanHaveIndexPage		// "override" KTPage to be the external URL
{
	if (iframeLink == [[self delegateOwner] integerForKey:@"linkType"])
	{
		return nil;
	}
	else
	{
		return [[self delegateOwner] wrappedValueForKey:@"linkURL"];	// return external URL when path or localPath are requested
	}
}

@end
