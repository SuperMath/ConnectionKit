//
//  KTImageScalingSettings.h
//  Marvel
//
//  Created by Mike on 09/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "KTMediaContainer.h"

@interface KTImageScalingSettings : NSObject <NSCoding>
{
	@private
	
	KTMediaScalingOperation	myBehaviour;
	NSSize					_size;
	float					myScaleFactor;
	NSImageAlignment		myImageAlignment;
}

// Init
+ (id)settingsWithScaleFactor:(float)scaleFactor sharpening:(NSNumber *)sharpening;

+ (id)settingsWithBehavior:(KTMediaScalingOperation)behavior
					  size:(NSSize)size
				sharpening:(NSNumber *)sharpening;

+ (id)cropToSize:(NSSize)size alignment:(NSImageAlignment)alignment;

+ (id)scalingSettingsWithDictionaryRepresentation:(NSDictionary *)dictionary;

// Accessors
- (KTMediaScalingOperation)behavior;
- (NSSize)size;
- (float)scaleFactor;
- (NSImageAlignment)alignment;

// Equality
- (BOOL)isEqual:(id)anObject;
- (BOOL)isEqualToImageScalingSettings:(KTImageScalingSettings *)settings;
- (unsigned)hash;

// Resizing
- (NSRect)sourceRectForImageOfSize:(NSSize)sourceSize;

- (float)scaleFactorForImageOfSize:(NSSize)sourceSize;
- (float)aspectRatioForImageOfSize:(NSSize)sourceSize;
- (NSSize)scaledSizeForImageOfSize:(NSSize)sourceSize;
//- (NSSize)destinationSizeForImageOfSize:(NSSize)sourceSize;
//- (float)heightForImageOfSize:(NSSize)sourceSize;

@end
