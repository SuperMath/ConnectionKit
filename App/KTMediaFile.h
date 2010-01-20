//
//  KTMediaFile.h
//  Sandvox
//
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//
//  THIS SOFTWARE IS PROVIDED BY KARELIA SOFTWARE AND ITS CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//

#import <Cocoa/Cocoa.h>


@class KTMediaManager, KTPage, KTMediaFileUpload;
@interface KTMediaFile : NSManagedObject

+ (NSString *)entityName;

// Accessors
- (KTMediaManager *)mediaManager;
- (NSString *)filename;
- (NSString *)filenameExtension;


// Location
- (NSURL *)fileURL; // the file at that URL may not exist any more. Might be nil if the Media knows it can't be found
- (NSString *)currentPath;	// just like -fileURL, but will never return nil. Falls back to a placeholder image instead
- (NSString *)quickLookPseudoTag;

- (KTMediaFileUpload *)defaultUpload;
- (KTMediaFileUpload *)uploadForPath:(NSString *)path;
- (KTMediaFileUpload *)uploadForScalingProperties:(NSDictionary *)scalingProps;

- (NSString *)uniqueUploadPath:(NSString *)preferredPath;


// Error Recovery
- (NSString *)bestExistingThumbnail;

@end
