//
//  SVContentObject.h
//  Sandvox
//
//  Created by Mike on 29/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.

//  A typical page is made up of lots of little scraps of content: paragraphs, pagelets, plug-ins etc. Each of these should be a descendant of SVContentObject as it provides the basic facilities they need:
//
//      -   Generate an HTML string representation of themself. This could be from just the receiver, or by recursively piecing together the HTML of various sub-content.
//  
//      -   When editing, each content object must be uniquely identifiable in the WebView so that appropriate controllers can be hooked up. First, the content object generating an HTML element with an id specified. Then, each content object is asked to locate itself in the DOM by the controller.
//
//      -   The Inspector handles a wide variety of content. Not all Inspectable properties are present on all objects. By default, Cocoa handles this by throwing NSUndefinedKeyException, which makes debugging a PITA. SVContentObject is friendlier and returns NSNotApplicableMarker.


#import "KSExtensibleManagedObject.h"
#import <WebKit/WebKit.h>


@class SVHTMLContext;


@interface SVContentObject : KSExtensibleManagedObject

#pragma mark Basic HTML
//  To implement HTML support, your object needs to write some HTML to the current HTML context. This is done by calling -writeHTML. For most objects you should override this method, but for simpler cases, it's enough to override -HTMLString and return a suitable value there.

- (void)writeHTML:(SVHTMLContext *)context; // default calls -HTMLString and writes that to the current context
- (void)writeHTML;

//  Calls -writeHTML: or -writeHTML for each object
+ (void)writeContentObjects:(NSArray *)objects inContext:(SVHTMLContext *)context;
+ (void)writeContentObjects:(NSArray *)objects; 


#pragma mark Editing Support

// Default is NO. Override if you want it to be published.
- (BOOL)shouldPublishEditingElementID;

// The returned ID should be suitable for using as a DOMElement's ID attribute. It should be unique for the page being generated. The default implementation is based upon the receiver's location in memory, as it is assumed that the object will be retained for the duration of the editing cycle. Subclasses can override to specify a different ID format, perhaps because the object will already generate a unique ID as part of its HTML.
- (NSString *)elementIdName;

@end
