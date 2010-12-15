//
//  SVArticle.h
//  Sandvox
//
//  Created by Mike on 27/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVRichText.h"

#import "SVPageProtocol.h"


@class KTPage;

@interface SVArticle : SVRichText

+ (SVArticle *)insertPageBodyIntoManagedObjectContext:(NSManagedObjectContext *)context;

@property (nonatomic, retain, readonly) KTPage *page;


#pragma mark HTML

- (NSAttributedString *)attributedHTMLStringWithTruncation:(NSUInteger)maxCount
                                                      type:(SVTruncationType)truncationType
                                         includeLargeMedia:(BOOL)includeLargeMedia
                                               didTruncate:(BOOL *)truncated;

- (NSUInteger)writeEarlyCallouts:(SVHTMLContext *)context;

@end



