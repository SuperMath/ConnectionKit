//
//  SVPlugInInspector.m
//  Sandvox
//
//  Created by Mike on 30/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPlugInInspector.h"

#import "KSCollectionController.h"
#import "SVInspectorViewController.h"
#import "SVPlugIn.h"

#import "NSArrayController+Karelia.h"


static NSString *sPlugInInspectorInspectedObjectsObservation = @"PlugInInspectorInspectedObjectsObservation";


@interface SVPlugInInspector ()
@property(nonatomic, copy, readwrite) NSString *selectedPlugInsIdentifier;
@end


#pragma mark -


@implementation SVPlugInInspector

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    [self addObserver:self
           forKeyPath:@"inspectedObjectsController.selectedObjects"
              options:NSKeyValueObservingOptionOld
              context:sPlugInInspectorInspectedObjectsObservation];
    
    return self;
}
     
- (void)dealloc
{
    [self removeObserver:self forKeyPath:@"inspectedObjectsController.selectedObjects"];
    
    [_plugInIdentifier release];
    
    [super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)
change context:(void *)context
{
    if (context == sPlugInInspectorInspectedObjectsObservation)
    {
        NSString *identifier = nil;
        @try
        {
            identifier = [[[self inspectedObjectsController] selection] valueForKeyPath:@"plugInIdentifier"];
        }
        @catch (NSException *exception)
        {
            if (![[exception name] isEqualToString:NSUndefinedKeyException]) @throw exception;
        }
        
        
        SVInspectorViewController *inspector = nil;
        if (NSIsControllerMarker(identifier))
        {
            identifier = nil;
        }
        else if ([[self selectedPlugInsIdentifier] isEqual:identifier])
        {
            inspector = [self selectedInspector];
        }
        else
        {
            Class <SVPlugIn> class = [[self inspectedObjectsController] valueForKeyPath:@"selection.plugIn.class"];
            inspector = [class makeInspectorViewController];
            
            // If re-selecting something of the same type, keep the Inspector we aready have
            if ([[self selectedInspector] isKindOfClass:[inspector class]]) return;
            
            
            // Give it the right content/selection
            NSArrayController *controller = [inspector inspectedObjectsController];
            NSArray *plugIns = [[self inspectedObjects] valueForKey:@"plugIn"];
            [controller setContent:plugIns];
            [controller selectAll];
        }
        
        [self setSelectedInspector:inspector];
        [self setSelectedPlugInsIdentifier:identifier];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark -

@synthesize selectedInspector = _selectedInspector;
- (void)setSelectedInspector:(SVInspectorViewController *)inspector;
{
    if (inspector == [self selectedInspector]) return;
    
    
    // Remove old inspector
    [[_selectedInspector view] removeFromSuperview];
    [[_selectedInspector inspectedObjectsController] setContent:nil];
    
    // Store new
    [_selectedInspector release]; _selectedInspector = [inspector retain];
    
    // Setup new
    @try
    {
        [[inspector view] setFrame:[[self view] frame]];
        [[self view] addSubview:[inspector view]];
    }
    @catch (NSException *exception)
    {
        // TODO: Log error
    }
}

@synthesize selectedPlugInsIdentifier = _plugInIdentifier;

- (CGFloat)viewHeight
{
    CGFloat result = ([self selectedInspector] ? [[[self selectedInspector] view] frame].size.height : [super viewHeight]);
    return result;
}

@end
