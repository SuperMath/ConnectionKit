//
//  SVComponent.h
//  Sandvox
//
//  Created by Mike on 23/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class SVHTMLContext, SVDOMController;
@protocol SVGraphic;


@protocol SVComponent <NSObject>

- (SVDOMController *)newDOMControllerWithElementIdName:(NSString *)elementID node:(DOMNode *)document;

@optional
// Override to call -beginGraphicContainer etc. if you're not happy with default behaviour
- (void)write:(SVHTMLContext *)context graphic:(id <SVGraphic>)graphic;

@end


#pragma mark -


@interface SVInlineGraphicContainer : NSObject <SVComponent>
{
  @private
    id <SVGraphic>  _graphic;
}

- (id)initWithGraphic:(id <SVGraphic>)graphic;
@property(nonatomic, retain, readonly) id <SVGraphic> graphic;

@end

