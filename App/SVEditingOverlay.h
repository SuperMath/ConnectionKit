//
//  SVWebViewContainerView.h
//  Sandvox
//
//  Created by Mike on 04/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  An SVEditingOverlay view is used to place over a WebView so that it can gain early access to hit testing in order to deny certain events reaching the WebView. By doing so it can create a UI paradigm whereby areas of the WebView becme "selectable" – that is, a click will place a selection border around an object rather than performing the normal action. The selected object can then be manipulated (e.g. change size, reposition), or a second click will allow access to WebKit's usual behaviour for the content.


#import <Cocoa/Cocoa.h>
#import "SVEditingOverlayItem.h"


@protocol SVWebEditingOverlayDataSource;
@class SVSelectionBorder, SVEditingOverlayDrawingView;


@interface SVEditingOverlay : NSView
{
  @private
    // Content
    NSView  *_contentView;
    NSRect  _contentFrame;
    id <SVWebEditingOverlayDataSource>  _dataSource;    // weak ref as you'd expect
    
    // Drawing
    SVEditingOverlayDrawingView *_drawingView;
    
    // Overlay Window
    NSWindow        *_overlayWindow;
    NSArray         *_trackedViews;
    
    // Selection
    NSArray *_selectedItems;
    NSArray *_selectionBorders;
    
    // Event Handling
    BOOL    _isProcessingEvent;
}


#pragma mark Document

@property(nonatomic, retain) NSView *contentView;

// Our document view (in Sandvox, the main frame's WebFrameView) will often not fill the space as ourself. Rather than have to reposition the overlay view to match, it should be more efficent to adjust this mask to match the document.
@property(nonatomic) NSRect contentFrame;

// Uses the same coordinate system as a standard NSScrollView. i.e. 0,0 is the top of the document. 0,10 scrolls down by 10 pixels.
- (void)scrollToPoint:(NSPoint)point;

// Pretty similar to NSView's -convertXToBase: set of methods. Translates coordinates as though -contentFrame were its own coordinates system.
- (CGPoint)convertPointToContent:(NSPoint)aPoint;
- (CGRect)convertRectToContent:(NSRect)aRect;


#pragma mark Data Source

@property(nonatomic, assign) id <SVWebEditingOverlayDataSource> dataSource;


#pragma mark Selection

@property(nonatomic, copy) NSArray *selectedItems;
- (void)selectItems:(NSArray *)items byExtendingSelection:(BOOL)extendSelection;


#pragma mark Getting Item Information

//  Queries the datasource
- (id <SVEditingOverlayItem>)itemAtPoint:(NSPoint)point;


@end


#pragma mark -


@protocol SVWebEditingOverlayDataSource <NSObject>

/*!
 @method editingOverlay:itemAtPoint:
 @param overlay The SVEditingOverlay object sending the message.
 @param point The point being tested in the overlay's coordinate system.
 @result The frontmost item that covers the point. nil if there is none.
 */
- (id <SVEditingOverlayItem>)editingOverlay:(SVEditingOverlay *)overlay
                                itemAtPoint:(NSPoint)point;

@end


extern NSString *SVWebEditingOverlaySelectionDidChangeNotification;
