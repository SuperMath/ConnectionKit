//
//  SVMigrationHTMLWriterDOMAdaptor.m
//  Sandvox
//
//  Created by Mike on 24/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVMigrationHTMLWriterDOMAdaptor.h"

#import "SVArticleDOMController.h"
#import "SVGraphicFactory.h"
#import "SVRawHTMLGraphic.h"
#import "SVWebEditorHTMLContext.h"


@implementation SVMigrationHTMLWriterDOMAdaptor

- (BOOL)DOMElementContainsAWebEditorItem:(DOMElement *)element;
{
    NSArray *items = [[self articleDOMController] childWebEditorItems];
    for (WEKWebEditorItem *anItem in items)
    {
        if ([[anItem HTMLElement] ks_isDescendantOfElement:element]) return YES;
    }
    
    return NO;
}

- (DOMNode *)handleInvalidDOMElement:(DOMElement *)element;
{
    // super will convert styling tags to <em> etc.
    NSString *tagName = [element tagName];
    if ([tagName isEqualToString:@"FONT"] ||    
        [tagName isEqualToString:@"I"] ||
        [tagName isEqualToString:@"B"])
    {
        return [super handleInvalidDOMElement:element];
    }
    
    // If the element is invalid just because it's in the wrong location, let super take care of repositioning
    if ([[self class] validateElement:tagName])
    {
        return [super handleInvalidDOMElement:element];
    }
    
    // Can't convert to raw HTML if contains an embedded image
    if ([self DOMElementContainsAWebEditorItem:element])
    {
        return [super handleInvalidDOMElement:element];
    }
    
    
    // Import as Raw HTML
    NSString *html = [KSXMLWriterDOMAdaptor outerHTMLOfDOMElement:element];
    
    SVRawHTMLGraphic *graphic = [[SVGraphicFactory rawHTMLFactory] insertNewGraphicInManagedObjectContext:
                                 [[[self articleDOMController] representedObject] managedObjectContext]];
    
    [graphic setHTMLString:html];
    
    
    // Create text attachment too
    [SVTextAttachment textAttachmentWithGraphic:graphic];
    
    
    // Create controller for graphic and hook up to imported node
    SVDOMController *controller = [graphic newDOMController];
    [controller awakeFromHTMLContext:[[self articleDOMController] HTMLContext]];
    [controller setHTMLElement:(DOMHTMLElement *)element];
    
    [[self articleDOMController] addChildWebEditorItem:controller];
    OBASSERT([[self articleDOMController] hitTestDOMNode:element] == controller);
    [controller release];
    
    
    // Generate new DOM node to match what model would normally generate
    [controller performSelector:@selector(update)];
    
    
    // Write the replacement
    OBASSERT([controller writeAttributedHTML:self]);
    
    
    return [[controller HTMLElement] nextSibling];
}

@synthesize articleDOMController = _articleController;

@end