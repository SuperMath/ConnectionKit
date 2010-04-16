//
//  KTPage+Web.m
//  KTComponents
//
//  Created by Dan Wood on 8/9/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTPage+Internal.h"

#import "KT.h"
#import "KTSite.h"
#import "SVApplicationController.h"
#import "KTDesign.h"
#import "KTDocument.h"
#import "KTElementPlugInWrapper.h"
#import "SVHTMLContext.h"
#import "SVHTMLTextBlock.h"
#import "SVHTMLTemplateParser.h"
#import "KTMaster.h"
#import "KTPublishingEngine.h"
#import "SVTitleBox.h"

#import "NSBundle+KTExtensions.h"
#import "NSBundle+QuickLook.h"

#import "NSBundle+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"
#import "NSObject+Karelia.h"

#import <WebKit/WebKit.h>

#import "Registration.h"


@implementation KTPage (Web)

/*	Generates the path to the specified file with the current page's design.
 *	Takes into account the HTML Generation Purpose to handle Quick Look etc.
 */
- (NSString *)pathToDesignFile:(NSString *)filename inContext:(SVHTMLContext *)context;
{
	NSString *result = nil;
	
	// Return nil if the file doesn't actually exist
	
	KTDesign *design = [[self master] design];
	NSString *localPath = [[[design bundle] bundlePath] stringByAppendingPathComponent:filename];
	if ([[NSFileManager defaultManager] fileExistsAtPath:localPath])
	{
		if ([context isForQuickLookPreview])
        {
            result = [[design bundle] quicklookDataForFile:filename];
        }
        else if ([context isEditable] && ![context baseURL])
        {
            result = [[NSURL fileURLWithPath:localPath] absoluteString];
        }
        else
        {
            KTMaster *master = [(KTPage *)[context currentPage] master];
            NSURL *designFileURL = [NSURL URLWithString:filename relativeToURL:[master designDirectoryURL]];
            result = [designFileURL stringRelativeToURL:[context baseURL]];
        }
	}
	
	return result;
}

#pragma mark Class Methods

- (NSString *)markupString;   // creates a temporary HTML context and calls -writeHTML
{
    NSMutableString *result = [NSMutableString string];
    
    SVHTMLContext *context = [[SVHTMLContext alloc] initWithStringWriter:result];
    [context setCurrentPage:self];
	
	[self writeHTML:context];
    
    [context release];
    return result;
}

- (void)writeHTML:(SVHTMLContext *)context;
{
	// Build the HTML    
    [context setXHTML:[self isXHTML]];
    [context setEncoding:[[[self master] valueForKey:@"charset"] encodingFromCharset]];
    [context setLanguage:[[self master] language]];
    
    NSString *cssPath = [self pathToDesignFile:@"main.css" inContext:context];
    [context setMainCSSURL:[NSURL URLWithString:cssPath
                                  relativeToURL:[context baseURL]]];
     
    
	SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc] initWithPage:self];
    [parser parseIntoHTMLContext:context];
    [parser release];
}

- (void)publish:(id <SVPublishingContext>)publishingEngine recursively:(BOOL)recursive;
{
    NSString *path = [self uploadPath];
    SVHTMLContext *context = [publishingEngine beginPublishingHTMLToPath:path];
    [context setCurrentPage:self];
	
    [self writeHTML:context];
    [context close];
    
    
	// Ask the delegate for any extra resource files that the parser didn't catch
    NSMutableSet *resources = [[NSMutableSet alloc] init];
    NSString *aResourcePath;
    for (aResourcePath in resources)
    {
        [publishingEngine addResourceFile:[NSURL fileURLWithPath:aResourcePath]];
    }
    
    [resources release];
	
	
	// Generate and publish RSS feed if needed
	if ([self collectionSyndicate] && [self collectionCanSyndicate])
	{
		NSString *RSSString = [self RSSFeedWithParserDelegate:publishingEngine];
		if (RSSString)
		{			
			// Now that we have page contents in unicode, clean up to the desired character encoding.
			NSData *RSSData = [RSSString dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
			OBASSERT(RSSData);
			
			NSString *RSSFilename = [self RSSFileName];
			NSString *RSSUploadPath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:RSSFilename];
			[publishingEngine publishData:RSSData toPath:RSSUploadPath];
		}
	}
    
    
    // Continue onto the next page if the app is licensed
    if (recursive && !gLicenseIsBlacklisted && gRegistrationString)
    {
        for (SVSiteItem *anItem in [self sortedChildren])
        {
            if (![[anItem isDraft] boolValue])
            {
                [anItem publish:publishingEngine recursively:recursive];
            }
        }
    }
}

+ (NSString *)pageTemplate
{
	static NSString *sPageTemplateString = nil;
	
	if (!sPageTemplateString)
	{
		NSString *path = [[NSBundle bundleForClass:[self class]] overridingPathForResource:@"KTPageTemplate" ofType:@"html"];
		NSData *data = [NSData dataWithContentsOfFile:path];
		sPageTemplateString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	}
	
	return sPageTemplateString;
}

+ (NSString *)pageMainContentTemplate;
{
	static NSString *sPageTemplateString = nil;
	
	if (!sPageTemplateString)
	{
		NSString *path = [[NSBundle bundleForClass:[self class]] overridingPathForResource:@"KTPageMainContentTemplate" ofType:@"html"];
		NSData *data = [NSData dataWithContentsOfFile:path];
		sPageTemplateString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	}
	
	return sPageTemplateString;
}

- (void)writeMainContent
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    
    SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc] initWithTemplate:[[self class] pageMainContentTemplate]
                                                                        component:[context currentPage]];
    
    [context setCurrentHeaderLevel:3];
    [parser parse];
    [parser release];
}

#pragma mark CSS

- (NSString *)cssClassName { return @"text-page"; }

/*  Used by KTPageTemplate.html to generate links to the stylesheets needed by this page. Used to be a dedicated [[stylesheet]] parser function
 */
- (void)writeStylesheetLinks
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    
    
    // Write link to main.CSS file -- the most specific
    NSURL *mainCSSURL = [context mainCSSURL];
    if (mainCSSURL)
    {
        [context writeLinkToStylesheet:[context relativeURLStringOfURL:mainCSSURL]
                                 title:[[[self master] design] title]
                                 media:nil];
    }
    [context writeNewline];
	
	
	// design's print.css but not for Quick Look
    if (![context isForQuickLookPreview])
	{
		NSString *printCSS = [self pathToDesignFile:@"print.css" inContext:context];
		if (printCSS)
        {
            [context writeLinkToStylesheet:printCSS title:nil media:@"print"];
            [context writeNewline];
        }
	}
	
	
	// Always include the global sandvox CSS.
	NSString *globalCSSFile = [[NSBundle mainBundle] overridingPathForResource:@"sandvox" ofType:@"css"];
    NSString *globalCSS = [NSString stringWithContentsOfFile:globalCSSFile encoding:NSUTF8StringEncoding error:NULL];
    if (globalCSS) [[context mainCSS] appendString:globalCSS];
    
    
    // Load up main.css
    NSString *mainCSS = [NSString stringWithData:[[[self master] design] mainCSSData]
                                        encoding:NSUTF8StringEncoding];
    if (mainCSS) [[context mainCSS] appendString:mainCSS];
    
    
	// If we're for editing, include additional editing CSS
	if ([context isEditable])
	{
		NSString *editingCSSPath = [[NSBundle mainBundle] overridingPathForResource:@"design-time"
																			 ofType:@"css"];
        NSString *editingCSS = [NSString stringWithContentsOfFile:editingCSSPath
                                                         encoding:NSUTF8StringEncoding
                                                            error:NULL];
		if (editingCSS) [[context mainCSS] appendString:editingCSS];
	}
	
    
	// For preview/quicklook mode, the banner CSS
    [[self master] writeBannerCSS];
}

#pragma mark Other

/*!	Generate path to javascript.  Nil if not there */
- (NSString *)javascriptURLPath
{
	NSString *result = nil;
	
	NSBundle *designBundle = [[[self master] design] bundle];
	BOOL scriptExists = ([designBundle pathForResource:@"javascript" ofType:@"js"] != nil);
	if (scriptExists)
	{
		NSURL *javascriptURL = [NSURL URLWithString:@"javascript.js" relativeToURL:[[self master] designDirectoryURL]];
		result = [javascriptURL stringRelativeToURL:[self URL]];
	}
	
	return result;
}


/*!	Return the string that makes up the title.  Page Title | Site Title | Author ... this is the DEFAULT if not set by windowTitle property.
*/
- (NSString *)comboTitleText
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *titleSeparator = [defaults objectForKey:@"TitleSeparator"];
	
	if ( [self isDeleted] || (nil == [[self site] rootPage]) )
	{
		return @"Bad Page!";
	}
	
	NSMutableString *buf = [NSMutableString string];
	
	BOOL needsSeparator = NO;
	NSString *title = [[self titleBox] text];
	if ( nil != title && ![title isEqualToString:@""])
	{
		[buf appendString:title];
		needsSeparator = YES;
	}
	
	
	NSString *siteTitleText = [[[[self master] siteTitle] textHTMLString] stringByConvertingHTMLToPlainText];
	if ( (nil != siteTitleText) && ![siteTitleText isEqualToString:@""] && ![siteTitleText isEqualToString:title] )
	{
		if (needsSeparator)
		{
			[buf appendString:titleSeparator];
		}
		[buf appendString:siteTitleText];
		needsSeparator = YES;
	}
	
	NSString *author = [[self master] valueForKey:@"author"];
	if (nil != author
		&& ![author isEqualToString:@""]
		&& ![author isEqualToString:siteTitleText]
		)
	{
		if (needsSeparator)
		{
			[buf appendString:titleSeparator];
		}
		[buf appendString:author];
	}
	
	if ([buf isEqualToString:@""])
	{
		buf = [NSMutableString stringWithString:NSLocalizedString(@"Untitled Page","fallback page title if no title is otherwise found")];
	}
	
	return buf;
}

#pragma mark -
#pragma mark DTD

- (KTDocType)docType
{
	KTDocType result = [[NSUserDefaults standardUserDefaults] integerForKey:@"DocType"];
	
	
    // if wantsJSKit comments, use transitional doc type (or worse, if already known)
	if ( result > KTXHTMLTransitionalDocType )
	{
		if ([[self allowComments] boolValue] && [[self master] wantsJSKit] )
		{
			result = KTXHTMLTransitionalDocType; // if this changes to KTHTML401DocType, also change isXHTML
		}
	}
    
    
    // Do any plug-ins want to lower the tone?
    NSManagedObjectContext *context = [self managedObjectContext];
    NSArray *graphics = [context fetchAllObjectsForEntityForName:@"Graphic" error:NULL];
    
    for (NSManagedObject *aGraphic in graphics)
    {
        result = MIN(result, [[aGraphic valueForKey:@"docType"] integerValue]);
        if (result == KTHTML401DocType) break;
    }
    
    
	return result;
}

- (NSString *)docTypeName
{
	KTDocType docType = [self docType];
	NSString *result = nil;
	switch (docType)
	{
		case KTHTML401DocType:
			result = @"HTML 4.01 Transitional";
			break;
		case KTXHTMLTransitionalDocType:
			result = @"XHTML 1.0 Transitional";
			break;
		case KTXHTMLStrictDocType:
			result = @"XHTML 1.0 Strict";
			break;
		case KTXHTML11DocType:
			result = @"XHTML 1.1";
			break;
	}
	return result;
}


- (BOOL)isXHTML	// returns true if our page is XHTML of some type, false if old HTML
{
	KTDocType docType = [self docType];
	BOOL result = (KTHTML401DocType != docType);
	return result;
}

- (NSString *)DTD
{
	KTDocType docType = [self docType];
	NSString *result = nil;
	switch (docType)
	{
		case KTHTML401DocType:
			result = @"<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">";
			break;
		case KTXHTMLTransitionalDocType:
			result = @"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">";
			break;
		case KTXHTMLStrictDocType:
			result = @"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">";
			break;
		case KTXHTML11DocType:
			result = @"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\" \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">";
			break;
	}
	return result;
}

- (void)outputMenuForArrayOfDuples:(NSArray *)anArray isTreeTop:(BOOL)isTreeTop
{
	SVHTMLContext *context = [SVHTMLContext currentContext];
	KTPage *currentParserPage = [[SVHTMLContext currentContext] currentPage];


	[context writeNewline];
	
	NSString *className = nil;
	if (isTreeTop)
	{
		className = @"jd_menu";
		int hierMenuType = [[[self master] design] hierMenuType];
		if (HIER_MENU_VERTICAL == hierMenuType)
		{
			className = [className stringByAppendingString:@" jd_vertical"];
		}
	}
	[context writeStartTag:@"ul" idName:nil className:className];

	int i=1;	// 1-based iteration
	int last = [anArray count];

	for (NSDictionary *duple in anArray)
	{
		KTPage *page = [duple objectForKey:@"page"];
		NSArray *children = [duple objectForKey:@"children"];

		[context writeNewline];
		if (page == currentParserPage)
		{
			[context writeStartTag:@"li" idName:nil className:
			 [NSString stringWithFormat:@"%d %@%@ currentPage", i, (i%2)?@"o":@"e", (i==last)? @" last" : @""]];
		}
		else
		{
			BOOL isCurrentParent = NO;
			if (!currentParserPage.includeInSiteMenu && page == currentParserPage.parentPage && currentParserPage.parentPage.index)
			{
				isCurrentParent = YES;
			}
			
			[context writeStartTag:@"li" idName:nil className:
			 [NSString stringWithFormat:@"%d %@%@%@",
			  i,
			  (i%2)?@"o":@"e",
			  (i==last)? @" last" : @"",
			  isCurrentParent ? @" currentParent" : @""]];
			
			NSString *urlString = [context relativeURLStringOfPage:page];
			
			[context writeAnchorStartTagWithHref:urlString title:[page title] target:nil rel:nil];
			// TODO: targetStringForPage:targetPage
		}
		
		// Build a text block
		SVHTMLTextBlock *textBlock = [[[SVHTMLTextBlock alloc] init] autorelease];
		
		[textBlock setEditable:NO];
		[textBlock setFieldEditor:NO];
		[textBlock setRichText:NO];
		[textBlock setImportsGraphics:NO];
		[textBlock setTagName:@"span"];
		[textBlock setGraphicalTextCode:@"m"];		// Actually we are probably throwing away graphical text menus
		
		[textBlock setHTMLSourceObject:page];
		[textBlock setHTMLSourceKeyPath:@"menuTitle"];
		
		[textBlock writeHTML];
		
		if (page != currentParserPage)
		{
			[context writeEndTag];	// a
		}
		
		if ([children count])
		{
			[self outputMenuForArrayOfDuples:children isTreeTop:NO];
            [context writeNewline];
			[context writeEndTag];	// li
        }
		else
		{
			[context writeEndTag];	// li
		}
		i++;
	}
    [context writeNewline];
	[context writeEndTag];	// ul
}

- (NSString *)sitemenu
{
	if (self.site.pagesInSiteMenu)	// Are there any pages in the site menu?
	{
		SVHTMLContext *context = [SVHTMLContext currentContext];
		[context writeNewline];
		[context writeStartTag:@"div" idName:@"sitemenu" className:nil];			// <div id="sitemenu">
		[context writeNewline];
		[context writeStartTag:@"h2" idName:nil className:@"hidden"];				// hidden skip navigation menu
		[context writeNewline];
		[context writeString:
		 NSLocalizedStringWithDefaultValue(@"skipNavigationTitleHTML", nil, [NSBundle mainBundle], @"Site Navigation", @"Site navigation title on web pages (can be empty if link is understandable)")];
		[context writeNewline];

		[context writeAnchorStartTagWithHref:@"#page-content" title:nil target:nil rel:@"nofollow"];
		[context writeString:NSLocalizedStringWithDefaultValue(@"skipNavigationLinkHTML", nil, [NSBundle mainBundle], @"[Skip]", @"Skip navigation LINK on web pages")];
		
		[context writeEndTag];	// a
        [context writeNewline];
		[context writeEndTag];	// h2
		[context writeNewline];
		
		
		[context writeStartTag:@"div" idName:@"sitemenu-content" className:nil];		// <div id="sitemenu-content">
		[context writeNewline];
	
		KTSite *site = self.site;
		NSArray *pagesInSiteMenu = site.pagesInSiteMenu;
		
		int hierMenuType = [[[self master] design] hierMenuType];
		NSMutableArray *tree = [NSMutableArray array];
		if (HIER_MENU_NONE == hierMenuType || [[NSUserDefaults standardUserDefaults] boolForKey:@"disableHierMenus"])
		{
			// Flat menu, either by design's preference or user default
			for (KTPage *siteMenuPage in pagesInSiteMenu)
			{
				NSDictionary *duple = [NSDictionary dictionaryWithObjectsAndKeys:siteMenuPage, @"page", nil];
				[tree addObject:duple];
			}
			[self outputMenuForArrayOfDuples:tree isTreeTop:NO];
		}
		else	// hierarchical menu
		{
			// now to build up the hiearchical site menu.
			// Array of dictionaries keyed with "page" and "children" array
			NSMutableDictionary *childrenLookup = [NSMutableDictionary dictionary];
			// Assume we are traversing tree in sorted order, so children will always be found after parent, which makes it easy to build this tree.
			for (KTPage *siteMenuPage in pagesInSiteMenu)
			{
				BOOL wasSubPage = NO;
				KTPage *parent = siteMenuPage;
				do 
				{
					NSMutableArray *childrenToAddTo = [childrenLookup objectForKey:[NSString stringWithFormat:@"%p", parent]];
					if (childrenToAddTo)
					{
						NSMutableArray *children = [NSMutableArray array];
						[childrenToAddTo addObject:[NSDictionary dictionaryWithObjectsAndKeys:siteMenuPage, @"page", children, @"children", nil]];
						parent = nil;	// stop looking
						wasSubPage = YES;
					}
					else
					{
						parent = [siteMenuPage parentPage];

					}
				}
				while (nil != parent && ![parent isRoot]);

				if (!wasSubPage)
				{
					NSMutableArray *children = [NSMutableArray array];
					NSDictionary *nodeDict = [NSDictionary dictionaryWithObjectsAndKeys:siteMenuPage, @"page", children, @"children", nil];
					[tree addObject:nodeDict];
					[childrenLookup setObject:children forKey:[NSString stringWithFormat:@"%p", siteMenuPage]];		// quick lookup from page to children
				}
			}	// end for
			[self outputMenuForArrayOfDuples:tree isTreeTop:YES];
		}
		
		
        [context writeNewline];
		[context writeEndTag];	// div
        [context writeComment:@" sitemenu-content "];
        [context writeNewline];
		[context writeEndTag];	// div
		[context writeComment:@" sitemenu "];
	}
	return nil;
}
/*
 Based on this template markup:
 [[if site.pagesInSiteMenu]]
	 <div id='sitemenu'>
		 <h2 class='hidden'>[[`skipNavigationTitleHTML]]<a rel='nofollow' href='#page-content'>[[`skipNavigationLinkHTML]]</a></h2>
		 <div id='sitemenu-content'>
			 <ul>
				 [[forEach site.pagesInSiteMenu toplink]]
					 [[if toplink==parser.currentPage]]
						 <li class='[[i]] [[eo]][[last]] currentPage'>
							[[textblock property:toplink.menuTitle graphicalTextCode:mc tag:span]]
						 </li>
					 [[else2]]
						 <li class='[[i]] [[eo]][[last]][[if parser.currentPage.includeInSiteMenu]][[else3]][[if toplink==parser.currentPage.parentPage]][[if parser.currentPage.parentPage.index]] currentParent[[endif5]][[endif4]][[endif3]]'>
							 <a [[target toplink]]href='[[path toplink]]' title='[[=&toplink.titleText]]'>
							 [[textblock property:toplink.menuTitle graphicalTextCode:m tag:span]]</a>
						 </li>
					 [[endif2]]
				 [[endForEach]]
			 </ul>
		 </div> <!-- sitemenu-content -->
	 </div> <!-- sitemenu -->
 [[endif]]
*/ 

@end
