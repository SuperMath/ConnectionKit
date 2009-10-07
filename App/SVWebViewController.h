//
//  SVWebViewController.h
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSWebViewController.h"
#import "KTHTMLParser.h"
#import "SVWebEditorView.h"


@class KTPage, SVWebEditorTextBlock;
@protocol SVWebEditorViewControllerDelegate;


@interface SVWebViewController : KSWebViewController <SVWebEditorViewDataSource, SVWebEditorViewDelegate, KTHTMLParserDelegate>
{
    KTPage  *_page;
    BOOL    _isLoading;
    
    NSMutableArray  *_HTMLTextBlocks;
    NSArray         *_textBlocks;
    SVWebEditorTextBlock     *_selectedTextBlock;
    
    SVWebEditorView     *_webEditorView;
    DOMHTMLDivElement   *_sidebarDiv;
    NSArray             *_contentItems;
    
    id <SVWebEditorViewControllerDelegate>  _delegate;  // weak ref
}

// These should all be KVO-compliant
@property(nonatomic, retain) KTPage *page;
@property(nonatomic, readonly, getter=isLoading) BOOL loading;


#pragma mark Text Blocks

// An array of SVTextBlock objects, one per text block created when setting up the page
@property(nonatomic, copy, readonly) NSArray *textBlocks;
// A series of methods for retrieving the Text Block to go with a bit of the webview
- (SVWebEditorTextBlock *)textBlockForDOMNode:(DOMNode *)node;
- (SVWebEditorTextBlock *)textBlockForDOMRange:(DOMRange *)range;

// Tracks what is selected in the webview in a KVO-compliant manner
@property(nonatomic, retain, readonly) SVWebEditorTextBlock *selectedTextBlock;


#pragma mark Selectable Objects

@property(nonatomic, retain) SVWebEditorView *webEditorView;
@property(nonatomic, copy, readonly) NSArray *contentItems;

#pragma mark Delegate
@property(nonatomic, assign) id <SVWebEditorViewControllerDelegate> delegate;


@end


#pragma mark -


@protocol SVWebEditorViewControllerDelegate

// The controller is not in a position to open a page by itself; it lets somebody else decide how to
- (void)webEditorViewController:(SVWebViewController *)sender openPage:(KTPage *)page;

@end

