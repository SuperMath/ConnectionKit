//
//  DownloadIndex.m
//  DownloadIndex
//
//  Copyright 2007-2010 Karelia Software. All rights reserved.
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

#import "DownloadIndexPlugIn.h"


// LocalizedStringInThisBundle(@"You really should add something to the collection so you can see it, ok? Also, feel free to suggest how to phrase this better. Case 87647.", "String_On_Page_Template")


@interface DownloadIndexPlugIn ()
- (NSSize)thumbnailSize;
@end


@implementation DownloadIndexPlugIn


#pragma mark SVIndexPlugIn

+ (NSArray *)plugInKeys
{ 
    NSArray *plugInKeys = [NSArray arrayWithObjects:
                           @"truncateChars", 
                           nil];    
    return [[super plugInKeys] arrayByAddingObjectsFromArray:plugInKeys];
}


- (void)awakeFromNew;
{
    [super awakeFromNew];
    self.truncateChars = 0;    
}


#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    // parse template
    [super writeHTML:context];
    
    // add dependencies
    [context addDependencyForKeyPath:@"indexedCollection" ofObject:self];
    [context addDependencyForKeyPath:@"indexedCollection.childPages" ofObject:self];
    [context addDependencyForKeyPath:@"truncateChars" ofObject:self];
    
    // add resources
    NSString *path = [[self bundle] pathForResource:@"DownloadIndex" ofType:@"css"];
    if (path && ![path isEqualToString:@""]) 
    {
        NSURL *cssURL = [NSURL fileURLWithPath:path];
        [context addCSSWithURL:cssURL];
    }
}


/* 
<div class="article-summary">[[summary item page.collectionTruncateCharacters]]</div>
 */

- (void)writeSummaryOfIteratedPage
{
    id<SVPlugInContext> context = [SVPlugIn currentContext]; 
    id<SVPage> iteratedPage = [context objectForCurrentTemplateIteration];
    //FIXME: summary needs to be truncated at truncateChars
    [iteratedPage writeSummary:context];
}


/*
 [[textblock property:item.title flags:"line" tag:h3 graphicalTextCode:h3 hyperlink:item]]
 */

- (void)writeTitleOfIteratedPage
{
    id<SVPlugInContext> context = [SVPlugIn currentContext]; 
    id<SVPage> iteratedPage = [context objectForCurrentTemplateIteration];
    
    [context writeTitleOfPage:iteratedPage
                  asPlainText:YES
             enclosingElement:nil
                   attributes:nil];
}


/*
 <img[[idClass entity:Page property:item.thumbnail flags:"anchor" id:item.uniqueID]]
src="[[mediainfo info:path media:item.thumbnail sizeToFit:thumbnailSize]]"
alt="[[=&item.titleText]]"
width="[[mediainfo info:width media:item.thumbnail sizeToFit:thumbnailSize]]"
height="[[mediainfo info:height media:item.thumbnail sizeToFit:thumbnailSize]]" />
 */

- (void)writeThumbnailImageOfIteratedPage
{
    id<SVPlugInContext> context = [SVPlugIn currentContext]; 
    id<SVPage> iteratedPage = [context objectForCurrentTemplateIteration];
    
    [[context HTMLWriter] writeThumbnailImageOfPage:iteratedPage 
                                          className:@"" 
                                           maxWidth:[self thumbnailSize].width 
                                          maxHeight:[self thumbnailSize].height];
}

- (NSSize)thumbnailSize
{
	return NSMakeSize(128.0, 128.0);
}


#pragma mark Properties

@synthesize truncateChars = _truncateChars;

@end
