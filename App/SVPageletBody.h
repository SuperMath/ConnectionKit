//
//  SVPageletContent.h
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>

@class SVPagelet;
@class SVContentObject;


@interface SVPageletBody :  NSManagedObject  

#pragma mark Owner
@property(nonatomic, retain, readonly) SVPagelet *pagelet;


#pragma mark Content

// Make sure the HTML you supply includes all of -contentObjects otherwise you'll fail validation later
@property(nonatomic, copy) NSString *archiveHTMLString;

//  There's no reason to update content objects without changing HTML at the same time
@property(nonatomic, copy, readonly) NSSet *contentObjects;
- (void)setArchiveHTMLString:(NSString *)html
              contentObjects:(NSSet *)contentObjects;


#pragma mark Editing
- (NSString *)editingHTMLString;


#pragma mark Publishing
// Generated by combining content objects with archive HTML
- (NSString *)HTMLString;

@end