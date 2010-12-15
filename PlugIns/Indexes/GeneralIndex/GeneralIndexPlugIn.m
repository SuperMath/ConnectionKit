//
//  GeneralIndex.m
//  GeneralIndex
//
//  Copyright 2004-2010 Karelia Software. All rights reserved.
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

#import "GeneralIndexPlugIn.h"

@interface GeneralIndexPlugIn ()
- (void)writeThumbnailImageOfIteratedPage;
- (void)writeTitleOfIteratedPage;
- (BOOL)writeSummaryOfIteratedPage;
- (void)writeArticleInfoWithContinueReadingLink:(BOOL)continueReading;
- (void)writeContinueReadingLink;
- (BOOL) hasArticleInfo;

@end

@protocol PagePrivate

- (id) master;
- (void)writeComments:(id<SVPlugInContext>)context;
- (NSObject *)titleBox;
@end

@protocol PlugInContextPrivate
- (NSString *)currentHeaderLevelTagName;
@end

@interface NSString (KareliaPrivate)
- (NSString*)stringByReplacing:(NSString *)value with:(NSString *)newValue;
@end

@implementation GeneralIndexPlugIn


#pragma mark SVIndexPlugIn

+ (NSArray *)plugInKeys
{ 
    NSArray *plugInKeys = [NSArray arrayWithObjects:
						   @"hyperlinkTitles",
						   @"indexLayoutType",
						   @"showPermaLinks",
                           @"showComments",
						   @"showTimestamps",
						   @"maxItemLength",
                           nil];    
    return [[super plugInKeys] arrayByAddingObjectsFromArray:plugInKeys];
}

- (void)awakeFromNew;
{
	[super awakeFromNew];
	
	NSNumber *isPagelet = [self valueForKeyPath:@"container.isPagelet"];	// Private. If creating in sidebar, make it more minimal
	if (isPagelet && [isPagelet boolValue])
	{
		self.indexLayoutType			= kLayoutTitlesList;
	}
}

#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
	// add dependencies
	[context addDependencyForKeyPath:@"hyperlinkTitles"		ofObject:self];
	[context addDependencyForKeyPath:@"indexLayoutType"		ofObject:self];
	[context addDependencyForKeyPath:@"showPermaLinks"		ofObject:self];
	[context addDependencyForKeyPath:@"showComments"		ofObject:self];
	[context addDependencyForKeyPath:@"showTimestamps"		ofObject:self];
	[context addDependencyForKeyPath:@"maxItemLength"		ofObject:self];

	// parse template
    [super writeHTML:context];
    
}

- (void)writeIndexStart
{
	id<SVPlugInContext> context = [self currentContext]; 

	if (self.indexLayoutType & kTableMask)
	{
		[context startElement:@"table" attributes:[NSDictionary dictionaryWithObjectsAndKeys:
												   @"0", @"border", nil]];		// TEMPORARY BORDER
	}
	else if (self.indexLayoutType & kListMask)
	{
		[context startElement:@"ul"];
	}
}

- (void)writeIndexEnd
{
	id<SVPlugInContext> context = [self currentContext]; 

	if (self.indexLayoutType & kTableMask)
	{
		[context endElement];
	}
	else if (self.indexLayoutType & kListMask)
	{
		[context endElement];
	}
}


- (void)writeInnards
{
	BOOL truncated = NO;
    id<SVPlugInContext, PlugInContextPrivate> context
	= (id<SVPlugInContext, PlugInContextPrivate>) [self currentContext];
	NSString *className = [context currentIterationCSSClassName];
	
	if (self.indexLayoutType & kTableMask)
	{
		[context startElement:@"tr" className:className];
	}
	else if (self.indexLayoutType & kListMask)
	{
		[context startElement:@"li" className:className];
	}
	else
	{
		[context startElement:@"div" className:className];
	}
		
	// Table: We write Thumb, then title....
	if (self.indexLayoutType & kTableMask)
	{
		if (self.indexLayoutType & kThumbMask)
		{
			[context startElement:@"td" className:@"dli1"];
			[self writeThumbnailImageOfIteratedPage];
			[context endElement];
		}
		if (self.indexLayoutType & kTitleMask)
		{
			[context startElement:@"td" className:@"dli2"];
			[context startElement:[context currentHeaderLevelTagName] className:@"index-title"];
			[self writeTitleOfIteratedPage];
			[context endElement];
			[context endElement];
		}
		
		if (self.indexLayoutType & kArticleMask)
		{
			[context startElement:@"td" className:@"dli3"];
			truncated = [self writeSummaryOfIteratedPage];
			
			if (truncated)	// put the continue reading link directly below the text
			{
				[self writeContinueReadingLink];
			}
			[context endElement];
		}
		
		// Do another column if we want to show some meta info
		
		if ((self.indexLayoutType & kArticleMask) && [self hasArticleInfo])
		{
			[context startElement:@"td" className:@"dli4"];
			[self writeArticleInfoWithContinueReadingLink:NO];
			[context endElement];
		}
	}
	else
	{
		if (self.indexLayoutType & kTitleMask)
		{
			[context startElement:[context currentHeaderLevelTagName] className:@"index-title"];
			[self writeTitleOfIteratedPage];
			[context endElement];
		}
		if (self.indexLayoutType & kThumbMask)
		{
			[self writeThumbnailImageOfIteratedPage];
		}
		if (self.indexLayoutType & kArticleMask)
		{
			truncated = [self writeSummaryOfIteratedPage];
			[self writeArticleInfoWithContinueReadingLink:truncated];
		}
	}
	
	/*
	 <div class="article-info">
		 [[if truncateChars>0]]
		 <div class="continue-reading-link">
			[[if parser.HTMLGenerationPurpose]]<a href="[[path iteratedPage]]">[[endif2]]
				[[continueReadingLink iteratedPage]]
			[[if parser.HTMLGenerationPurpose]]</a>[[endif2]]
		 </div>
		 [[endif]]
		 
		 [[if iteratedPage.includeTimestamp]]
			<div class="timestamp">
				[[if showPermaLink]]
					<a [[target iteratedPage]]href="[[path iteratedPage]]">[[=&iteratedPage.timestamp]]</a>
				[[else2]]
					[[=&iteratedPage.timestamp]]
				[[endif2]]
			</div>
		 [[endif]]
		 
		 [[COMMENT parsecomponent iteratedPage iteratedPage.commentsTemplate]]
	 </div> <!-- article-info -->
	 </div> <!-- article -->
	 <div class="clear">
	 
	 
	 NOTE
	 
	 
	 when you see something like this
	 [[if parser.HTMLGenerationPurpose==0]]
	 you need to change it to
	 [[if currentContext.isForEditing]]
	 
	*/

	[context endElement];		// li, tr, or div
}

- (void)writeContinueReadingLink;
{
    id<SVPlugInContext> context = [self currentContext]; 
    id<SVPage,PagePrivate> iteratedPage = [context objectForCurrentTemplateIteration];

	// Note: Right now we are just writing out the format.  We are not providing a way to edit or customize this.
	
	[context startElement:@"div" className:@"continue-reading-link"];
	[context startAnchorElementWithPage:iteratedPage];
	
	NSString *format = [[iteratedPage master] valueForKey:@"continueReadingLinkFormat"];
	NSString *title = [iteratedPage title];
	if (nil == title)
	{
		title = @"";		// better than nil, which crashes!
	}
	NSString *textToWrite = [format stringByReplacing:@"@@" with:title];
	[context writeText:textToWrite];
	[context endElement];	// </a>
	[context endElement];	// </div> continue-reading-link
}

- (BOOL) hasArticleInfo;		// Do we have settings to show an article info column or section?
{
	return self.showTimestamps || self.showPermaLinks || self.showComments;
}

- (void)writeArticleInfoWithContinueReadingLink:(BOOL)continueReading;
{
    id<SVPlugInContext> context = [self currentContext]; 
    id<SVPage,PagePrivate> iteratedPage = [context objectForCurrentTemplateIteration];

	[context startElement:@"div" className:@"article-info"];
	
	if (continueReading)	// put the continue reading link along with the article info
	{
		[self writeContinueReadingLink];
	}
	
	if (self.showTimestamps || self.showPermaLinks)		// timestamps and/or permanent links need timestamp <div>
	{
		
		[context startElement:@"div" className:@"timestamp"];
		
		if (self.showPermaLinks)		// If we are doing permanent link, start <a>
		{
			[context startAnchorElementWithPage:iteratedPage];
		}
		if (self.showTimestamps)	// Write out either timestamp ....
		{
			[context writeText:iteratedPage.timestampDescription];
		}
		else if (self.showPermaLinks)	// ... or permanent link text ..
		{
			NSBundle *bundle = [NSBundle bundleForClass:[self class]];
			NSString *language = [iteratedPage language];
			NSString *permaLink = [bundle localizedStringForString:@"Permanent Link" language:language fallback:
								   LocalizedStringInThisBundle(@"Permanent Link", @"Text in website's language to indicate a permanent link to the page")];
			[context writeText:permaLink];
		}
		if ( self.showPermaLinks )
		{
			[context endElement];	// </a>
		}
		[context endElement];	// </div> timestamp
	}
	
	if (self.showComments)
	{
		[iteratedPage writeComments:context];		// PRIVATE		
	}
	
	[context endElement];	// </div> article-info	
}

- (void)writeTitleOfIteratedPage;
{
    id<SVPlugInContext> context = [self currentContext]; 
    id<SVPage, PagePrivate> iteratedPage = [context objectForCurrentTemplateIteration];
	
	if (![[[iteratedPage titleBox] valueForKey:@"hidden"] boolValue])		// Do not show title if it is hidden!
	{
		if ( self.hyperlinkTitles) { [context startAnchorElementWithPage:iteratedPage]; } // <a>
		
		[context writeElement:@"span"
			  withTitleOfPage:iteratedPage
				  asPlainText:NO
				   attributes:[NSDictionary dictionaryWithObject:@"in" forKey:@"class"]];
		
		if ( self.hyperlinkTitles ) { [context endElement]; } // </a> 
	}
}


/*
 [[summary item indexedCollection.collectionTruncateCharacters]]
 */

extern NSUInteger kLargeMediaTruncationThreshold;

- (BOOL)writeSummaryOfIteratedPage;
{
	BOOL includeLargeMedia = self.indexLayoutType & kLargeMediaMask;
	if (includeLargeMedia && (self.indexLayoutType & kLargeMediaIfBigEnough) )
	{
		includeLargeMedia = self.maxItemLength >= kLargeMediaTruncationThreshold;
	}
	
    id<SVPlugInContext> context = [self currentContext]; 
    id<SVPage> iteratedPage = [context objectForCurrentTemplateIteration];
    BOOL truncated = [iteratedPage writeSummary:context
							  includeLargeMedia:includeLargeMedia
									 truncation:self.maxItemLength];
	return truncated;
}


/*
<img[[idClass entity:Page property:item.thumbnail flags:"anchor" id:item.uniqueID]]
 src="[[mediainfo info:path media:item.thumbnail sizeToFit:thumbnailImageSize]]"
 alt="[[=&item.titleText]]"
 width="[[mediainfo info:width media:item.thumbnail sizeToFit:thumbnailImageSize]]"
 height="[[mediainfo info:height media:item.thumbnail sizeToFit:thumbnailImageSize]]" />*/

- (void)writeThumbnailImageOfIteratedPage;
{
    id<SVPlugInContext> context = [self currentContext]; 
    id<SVPage> iteratedPage = [context objectForCurrentTemplateIteration];
    
    // Do a dry-run to see if there's actuall a thumbnail
    if ([iteratedPage writeThumbnail:context
                            maxWidth:64
                           maxHeight:64
                      imageClassName:nil
                              dryRun:YES])
    {
        [context startElement:@"div" className:@"article-thumbnail"];
        
        [iteratedPage writeThumbnail:context
                            maxWidth:64
                           maxHeight:64
                      imageClassName:nil
                              dryRun:NO];
        
        [context endElement];
    }
}

#pragma mark Properties

@synthesize hyperlinkTitles = _hyperlinkTitles;
@synthesize indexLayoutType = _indexLayoutType;
@synthesize showPermaLinks	= _showPermaLinks;
@synthesize showEntries = _showEntries;
@synthesize showTitles = _showTitles;
@synthesize showComments	= _showComments;
@synthesize showTimestamps	= _showTimestamps;
@synthesize maxItemLength	= _maxItemLength;

- (void) setIndexLayoutType:(IndexLayoutType)aType	// custom setter to also set dependent flags
{
	_indexLayoutType = aType;
	self.showTitles = 0 != (aType & kTitleMask);
	self.showEntries = 0 != (aType & kArticleMask);
}


@end
