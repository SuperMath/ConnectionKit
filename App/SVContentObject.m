//
//  SVWebContentItem.m
//  Sandvox
//
//  Created by Mike on 02/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVContentObject.h"


@implementation SVContentObject

#pragma mark Init & Dealloc

- (id)init
{
    return [self initWithElement:nil];
}

- (id)initWithElement:(DOMHTMLElement *)element;
{
    OBPRECONDITION(element);
    
    self = [super init];
    
    _element = [element retain];
    
    _nodeTracker = [[SVDOMNodeBoundsTracker alloc] initWithDOMNode:element];
    [_nodeTracker setDelegate:self];
    
    return self;
}

- (void)dealloc
{
    [_nodeTracker stopTracking];
    [_nodeTracker setDelegate:nil];
    [_nodeTracker release];
    
    [_element release];
    
    [super dealloc];
}

#pragma mark DOM

@synthesize element = _element;

#pragma mark Editing Overlay Item

- (NSRect)rect
{
    DOMElement *element = [self element];
    NSRect result = [element boundingBox];
    return result;
}

- (void)trackerDidDetectDOMNodeBoundsChange:(NSNotification *)notification;
{
    
}

@end
