//
//  CollectionArchiveInspector.h
//  CollectionArchiveElement
//
//  Created by Terrence Talbot on 8/16/10.
//  Copyright 2010 Terrence Talbot. All rights reserved.
//

#import "SandvoxPlugin.h"


@interface CollectionArchiveInspector : SVInspectorViewController 
{
	IBOutlet KTLinkSourceView	*collectionLinkSourceView;
}

// IB Actions
- (IBAction)clearCollectionLink:(id)sender;

@end
