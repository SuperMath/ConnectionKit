//
//  KTDocument+Saving.m
//  Marvel
//
//  Created by Mike on 26/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTDocument.h"

#import "KTDesign.h"
#import "KTDocumentController.h"
#import "KTDocWindowController.h"
#import "KTDocSiteOutlineController.h"
#import "KTDocumentInfo.h"
#import "KTHTMLParser.h"
#import "KTPage.h"
#import "KTMaster.h"
#import "KTMediaManager+Internal.h"

#import "KTWebKitCompatibility.h"

#import "CIImage+Karelia.h"
#import "NSError+Karelia.h"
#import "NSFileManager+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSImage+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSMutableSet+Karelia.h"
#import "NSThread+Karelia.h"
#import "NSView+Karelia.h"
#import "NSWorkspace+Karelia.h"
#import "NSURL+Karelia.h"

#import "KSThreadProxy.h"

#import <Connection/Connection.h>

#import "Registration.h"
#import "Debug.h"


NSString *KTDocumentWillSaveNotification = @"KTDocumentWillSave";


/*	These strings are used for generating Quick Look preview sticky-note text
 */
// NSLocalizedString(@"Published at", "Quick Look preview sticky-note text");
// NSLocalizedString(@"Last updated", "Quick Look preview sticky-note text");
// NSLocalizedString(@"Author", "Quick Look preview sticky-note text");
// NSLocalizedString(@"Language", "Quick Look preview sticky-note text");
// NSLocalizedString(@"Pages", "Quick Look preview sticky-note text");


// TODO: change these into defaults
//#define FIRST_AUTOSAVE_DELAY 3
//#define SECOND_AUTOSAVE_DELAY 60


@interface KTDocument (PropertiesPrivate)
- (void)copyDocumentDisplayPropertiesToModel;
@end


@interface KTDocument (SavingPrivate)

// Save
- (BOOL)performSaveToOperationToURL:(NSURL *)absoluteURL error:(NSError **)outError;

// Write Safely
- (NSString *)backupExistingFileForSaveAsOperation:(NSString *)path error:(NSError **)error;
- (void)recoverBackupFile:(NSString *)backupPath toURL:(NSURL *)saveURL;

// Write To URL
- (BOOL)prepareToWriteToURL:(NSURL *)inURL 
					 ofType:(NSString *)inType 
		   forSaveOperation:(NSSaveOperationType)inSaveOperation
					  error:(NSError **)outError;

- (BOOL)writeMOCToURL:(NSURL *)inURL 
			   ofType:(NSString *)inType 
	 forSaveOperation:(NSSaveOperationType)inSaveOperation
  originalContentsURL:(NSURL *)inOriginalContentsURL
				error:(NSError **)outError;

- (BOOL)migrateToURL:(NSURL *)URL ofType:(NSString *)typeName originalContentsURL:(NSURL *)originalContentsURL error:(NSError **)outError;

// Quick Look
- (void)startGeneratingQuickLookThumbnail;
- (BOOL)writeQuickLookThumbnailToDocumentURLIfPossible:(NSURL *)docURL error:(NSError **)error;
- (NSString *)quickLookPreviewHTML;

@end


#pragma mark -


@implementation KTDocument (Saving)

#pragma mark -
#pragma mark Save to URL

- (BOOL)saveToURL:(NSURL *)absoluteURL
		   ofType:(NSString *)typeName
 forSaveOperation:(NSSaveOperationType)saveOperation
			error:(NSError **)outError
{
	OBPRECONDITION([absoluteURL isFileURL]);
	
	
	[[NSNotificationCenter defaultCenter] postNotificationName:KTDocumentWillSaveNotification object:self];
    
    
    BOOL result = NO;		// We have to supply an Error if we are going to return NO....
    
    
    if ([self isSaving])
    {
        if (saveOperation == NSSaveOperation || saveOperation == NSAutosaveOperation)
        {
            // This can happen if there's an autosave request while we're still generating the Quick Look thumbnail.
            // If so, saving the MOCs has been completed already so we can just go ahead and return YES.
            result = YES;
        }
        else
        {
			if (outError)
			{
				*outError = [NSError errorWithDomain:NSCocoaErrorDomain
												code:0
								localizedDescription:NSLocalizedString(@"Another save operation is already in progress.",
																	   "Saving error")];
			}
        }
    }
    else
    {
        // Mark -isSaving as YES;
        mySaveOperationCount++;
        
        
        
        //  Do the save op
        if (saveOperation == NSSaveToOperation)
        {
            result = [self performSaveToOperationToURL:absoluteURL error:outError];
        }
        else if (saveOperation == NSSaveAsOperation &&  // We can't support anything other than a standard Save operation when
                 [[absoluteURL path] isEqualToString:[[self fileURL] path]])    // writing to the doc's URL
        {                                           
            result = [super saveToURL:absoluteURL ofType:typeName forSaveOperation:NSSaveOperation error:outError];
        }
        else
        {
            result = [super saveToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation error:outError];
        }
		OBASSERT( (YES == result) || (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error
        
        // Unmark -isSaving as YES if applicable
        mySaveOperationCount--;
    }
    
    
	return result;
}

/*  -writeToURL: only supports the Save and SaveAs operations. Instead,
 *  we fake SaveTo operations by doing a standard Save operation and then
 *  copying the resultant file to the destination.
 */
- (BOOL)performSaveToOperationToURL:(NSURL *)absoluteURL error:(NSError **)outError
{
    BOOL result = [super saveToURL:[self fileURL] ofType:[self fileType] forSaveOperation:NSSaveOperation error:outError];
	OBASSERT( (YES == result) || (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error

    if (result)
    {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        if ([fileManager fileExistsAtPath:[absoluteURL path]])
        {
            [fileManager removeFileAtPath:[absoluteURL path] handler:nil];
        }
        
        result = [fileManager copyPath:[[self fileURL] path] toPath:[absoluteURL path] handler:nil];
        if (!result)
        {
            // didn't work, put up an error
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [absoluteURL path], NSFilePathErrorKey,
                                      NSLocalizedString(@"Unable to copy to path", @"Unable to copy to path"), NSLocalizedDescriptionKey,
                                      nil];
			if (outError)
			{
				*outError = [NSError errorWithDomain:NSCocoaErrorDomain 
												code:512 // unknown write error 
											userInfo:userInfo];
			}
        }
    }
    
    return result;
}
    
- (BOOL)isSaving
{
    return (mySaveOperationCount > 0);
}

#pragma mark -
#pragma mark Save Panel

- (void)runModalSavePanelForSaveOperation:(NSSaveOperationType)saveOperation
                                 delegate:(id)delegate
                          didSaveSelector:(SEL)didSaveSelector
                              contextInfo:(void *)contextInfo
{
    myLastSavePanelSaveOperation = saveOperation;
    [super runModalSavePanelForSaveOperation:saveOperation
                                    delegate:delegate
                             didSaveSelector:didSaveSelector
                                 contextInfo:contextInfo];
}

- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
	BOOL result = [super prepareSavePanel:savePanel];
    
    if (result)
    {
        switch (myLastSavePanelSaveOperation)
        {
            case NSSaveOperation:
                [savePanel setTitle:NSLocalizedString(@"New Site","Save Panel Title")];
                [savePanel setPrompt:NSLocalizedString(@"Create","Create Button")];
                [savePanel setTreatsFilePackagesAsDirectories:NO];
                [savePanel setCanSelectHiddenExtension:YES];
                [savePanel setRequiredFileType:(NSString *)kKTDocumentExtension];
                break;
                
            case NSSaveToOperation:
                [savePanel setTitle:NSLocalizedString(@"Save a Copy As...", @"Save a Copy As...")];
                [savePanel setNameFieldLabel:NSLocalizedString(@"Save Copy:", @"Save sheet name field label")];
                
                break;
                
            default:
                break;
        }
    }
    
    return result;
}

#pragma mark -
#pragma mark Write Safely

/*	We override the behavior to save directly ('unsafely' I suppose!) to the URL,
 *	rather than via a temporary file as is the default.
 */
- (BOOL)writeSafelyToURL:(NSURL *)absoluteURL 
				  ofType:(NSString *)typeName 
		forSaveOperation:(NSSaveOperationType)saveOperation 
				   error:(NSError **)outError
{
	BOOL result = NO;
    
    // We're only interested in special behaviour for Save As operations
    switch (saveOperation)
    {
        case NSSaveOperation:
        case NSAutosaveOperation:
            result = [self writeToURL:absoluteURL       // Stops NSPersistentDocument locking the store in the background
                               ofType:typeName
                     forSaveOperation:NSSaveOperation 
                  originalContentsURL:[self fileURL]
                                error:outError];
            
            break;
            
        case NSSaveAsOperation:
        {
            // We'll need a path for various operations below
            NSAssert2([absoluteURL isFileURL], @"-%@ called for non-file URL: %@", NSStringFromSelector(_cmd), [absoluteURL absoluteString]);
            NSString *path = [absoluteURL path];
            
            
            // If a file already exists at the desired location move it out of the way
            NSString *backupPath = nil;
            if ([[NSFileManager defaultManager] fileExistsAtPath:path])
            {
                backupPath = [self backupExistingFileForSaveAsOperation:path error:outError];
                if (!backupPath) return NO;
            }
            
            
            // We want to catch all possible errors so that the save can be reverted. We cover exceptions & errors. Sadly crashers can't
            // be dealt with at the moment.
            @try
            {
                // Write to the new URL
                result = [self writeToURL:absoluteURL
                                   ofType:typeName
                         forSaveOperation:saveOperation
                      originalContentsURL:[self fileURL]
                                    error:outError];
                OBASSERT( (YES == result) || (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error
            }
            @catch (NSException *exception) 
            {
                // Recover from an exception as best as possible and then rethrow the exception so it goes the exception reporter mechanism
                [self recoverBackupFile:backupPath toURL:absoluteURL];
                @throw;
            }
            
            
            if (result)
            {
                // The save was successful, delete the backup file
                if (backupPath)
                {
                    [[NSFileManager defaultManager] removeFileAtPath:backupPath handler:nil];
                }
            }
            else
            {
                // There was an error saving, recover from it
                [self recoverBackupFile:backupPath toURL:absoluteURL];
            }
            
            break;
        }
            
            
        default:
            result = [super writeSafelyToURL:absoluteURL 
                                      ofType:typeName 
                            forSaveOperation:saveOperation 
                                       error:outError];
    }
    
    OBASSERT( (YES == result) || (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error
    return result;
}

/*	Support method for -writeSafelyToURL:
 *	Returns nil and an error if the file cannot be backed up.
 */
- (NSString *)backupExistingFileForSaveAsOperation:(NSString *)path error:(NSError **)error
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	// Move the existing file to the best available backup path
	NSString *backupDirectory = [path stringByDeletingLastPathComponent];
	NSString *preferredFilename = [NSString stringWithFormat:@"Backup of %@", [path lastPathComponent]];
	NSString *preferredPath = [backupDirectory stringByAppendingPathComponent:preferredFilename];
	NSString *backupFilename = [fileManager uniqueFilenameAtPath:preferredPath];
	NSString *result = [backupDirectory stringByAppendingPathComponent:backupFilename];
	
	BOOL success = [fileManager movePath:path toPath:result handler:nil];
	if (!success)
	{
		// The backup failed, construct an error
		result = nil;
		
		NSString *failureReason = [NSString stringWithFormat:@"Could not remove the existing file at:\n%@", path];
		NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Unable to save document", NSLocalizedDescriptionKey,
																			failureReason, NSLocalizedFailureReasonErrorKey,
																			path, NSFilePathErrorKey, nil];
		if (error)
		{
			*error = [NSError errorWithDomain:@"KTDocument" code:0 userInfo:userInfo];
		}
	}
	
	return result;
}

/*	In the event of a Save As operation failing, we copy the backup file back to the original location.
 */
- (void)recoverBackupFile:(NSString *)backupPath toURL:(NSURL *)saveURL
{
	// Dump the failed save
	NSString *savePath = [saveURL path];
	BOOL result = [[NSFileManager defaultManager] removeFileAtPath:savePath handler:nil];
	
	// Recover the backup if there is one
	if (backupPath)
	{
		result = [[NSFileManager defaultManager] movePath:backupPath toPath:[saveURL path] handler:nil];
	}
	
	if (!result)
	{
		NSLog(@"Could not recover backup file:\n%@\nafter Save As operation failed for URL:\n%@", backupPath, [saveURL path]);
	}
}

#pragma mark -
#pragma mark Write To URL

/*	Called when creating a new document and when performing saveDocumentAs:
 */
- (BOOL)writeToURL:(NSURL *)inURL 
			ofType:(NSString *)inType 
  forSaveOperation:(NSSaveOperationType)saveOperation originalContentsURL:(NSURL *)inOriginalContentsURL
			 error:(NSError **)outError 
{
	// We don't support any of the other save ops here.
	OBPRECONDITION(saveOperation == NSSaveOperation || saveOperation == NSSaveAsOperation);
	
	
	BOOL result = NO;
	
	
    // Kick off thumbnail generation
    if ([NSThread currentThread] == [self thread])
    {
        [self startGeneratingQuickLookThumbnail];
	}
    else
    {
        [self performSelector:@selector(startGeneratingQuickLookThumbnail) inThread:[self thread]];
    }
    
    
    
    // Prepare to save the context
    KTDocument *docProxy = ([NSThread currentThread] == [self thread]) ? [self retain] : [[KSThreadProxy alloc] initWithTarget:self];
    result = [docProxy prepareToWriteToURL:inURL
                                    ofType:inType
                          forSaveOperation:saveOperation
                                     error:outError];
    [docProxy release];
    OBASSERT(result || !outError || (nil != *outError));    // make sure we didn't return NO with an empty error
	
    
	
	if (result)
	{
		// Generate Quick Look preview HTML
        KTDocument *docProxy = ([NSThread currentThread] == [self thread]) ? [self retain] : [[KSThreadProxy alloc] initWithTarget:self thread:[self thread]];
        NSString *quickLookPreviewHTML = [docProxy quickLookPreviewHTML];
        
        
        // Save the context
		result = [docProxy writeMOCToURL:inURL
                              ofType:inType
                    forSaveOperation:saveOperation
                 originalContentsURL:inOriginalContentsURL
                               error:outError];
		OBASSERT( (YES == result) || (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error
		
        [docProxy release];
        
        
        // Write out Quick Look preview
        if (result && quickLookPreviewHTML)
        {
            NSURL *previewURL = [[KTDocument quickLookURLForDocumentURL:inURL] URLByAppendingPathComponent:@"preview.html" isDirectory:NO];
            result = [quickLookPreviewHTML writeToURL:previewURL
                                           atomically:NO
                                             encoding:NSUTF8StringEncoding
                                                error:outError];
        }
    }
    
    
    if (result && _quickLookThumbnailWebView)
    {
        [self writeQuickLookThumbnailToDocumentURLIfPossible:inURL error:outError];
	}
	
	
	return result;
}


/*	Support method that sets the environment ready for the MOC and other document contents to be written to disk.
 */
- (BOOL)prepareToWriteToURL:(NSURL *)inURL 
					 ofType:(NSString *)inType 
		   forSaveOperation:(NSSaveOperationType)saveOperation
					  error:(NSError **)outError
{
	// REGISTRATION -- be annoying if it looks like the registration code was bypassed
	if ( ((0 == gRegistrationWasChecked) && random() < (LONG_MAX / 10) ) )
	{
		// NB: this is a trick to make a licensing issue look like an Unknown Store Type error
		// KTErrorReason/KTErrorDomain is a nonsense response to flag this as bad license
		NSError *registrationError = [NSError errorWithDomain:NSCocoaErrorDomain
														 code:134000 // invalid type error, for now
													 userInfo:[NSDictionary dictionaryWithObject:@"KTErrorDomain"
																						  forKey:@"KTErrorReason"]];
		if ( nil != outError )
		{
			// we'll pass registrationError back to the document for presentation
			*outError = registrationError;
		}
		
		return NO;
	}
	
	
	// For the first save of a document, create the wrapper paths on disk before we do anything else
	if (saveOperation == NSSaveAsOperation)
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:[inURL path] attributes:nil];
		[[NSWorkspace sharedWorkspace] setBundleBit:YES forFile:[inURL path]];
		
		[[NSFileManager defaultManager] createDirectoryAtPath:[[KTDocument siteURLForDocumentURL:inURL] path] attributes:nil];
		[[NSFileManager defaultManager] createDirectoryAtPath:[[KTDocument mediaURLForDocumentURL:inURL] path] attributes:nil];
		[[NSFileManager defaultManager] createDirectoryAtPath:[[KTDocument quickLookURLForDocumentURL:inURL] path] attributes:nil];
	}
	
	
	// Make sure we have a persistent store coordinator properly set up
	OBASSERT([NSThread currentThread] == [self thread]);
    NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
	NSPersistentStoreCoordinator *storeCoordinator = [managedObjectContext persistentStoreCoordinator];
	NSURL *persistentStoreURL = [KTDocument datastoreURLForDocumentURL:inURL UTI:nil];
	
	if ([[storeCoordinator persistentStores] count] < 1)
	{ 
		BOOL didConfigure = [self configurePersistentStoreCoordinatorForURL:inURL // not newSaveURL as configurePSC needs to be consistent
																	 ofType:[KTDocument defaultStoreType]
																	  error:outError];
		
		OBASSERT( (YES == didConfigure) || (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error

		id newStore = [storeCoordinator persistentStoreForURL:persistentStoreURL];
		if ( !newStore || !didConfigure )
		{
			NSLog(@"error: unable to create document: %@", (outError ? [*outError description] : nil) );
			return NO; // bail out and display outError
		}
	} 
	
	
    // Set metadata
    if ([storeCoordinator persistentStoreForURL:persistentStoreURL])
    {
        OBASSERT([NSThread currentThread] == [self thread]);
        if (![self setMetadataForStoreAtURL:persistentStoreURL error:outError])
        {
			OBASSERT( (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error
            return NO; // couldn't setMetadata, but we should have, bail...
        }
    }
    else
    {
        if (saveOperation != NSSaveAsOperation)
        {
			OBASSERT( (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error
			LOG((@"error: wants to setMetadata during save but no persistent store at %@", persistentStoreURL));
            return NO; // this case should not happen, stop
        }
    }
    
    
    // Record display properties
    OBASSERT([NSThread currentThread] == [self thread]);
    [managedObjectContext processPendingChanges];
    [[managedObjectContext undoManager] disableUndoRegistration];
    [self copyDocumentDisplayPropertiesToModel];
    [managedObjectContext processPendingChanges];
    [[managedObjectContext undoManager] enableUndoRegistration];
    
    
    // Move external media in-document if the user requests it
    OBASSERT([NSThread currentThread] == [self thread]);
    KTDocumentInfo *docInfo = [self documentInfo];
    if ([docInfo copyMediaOriginals] != [[docInfo committedValueForKey:@"copyMediaOriginals"] intValue])
    {
        [[self mediaManager] moveApplicableExternalMediaInDocument];
    }
	
	
	return YES;
}

- (BOOL)writeMOCToURL:(NSURL *)inURL 
			   ofType:(NSString *)inType 
	 forSaveOperation:(NSSaveOperationType)inSaveOperation
  originalContentsURL:(NSURL *)inOriginalContentsURL
				error:(NSError **)outError;

{
	BOOL result = YES;
	NSError *error = nil;
	
	
	if (result)
    {
        NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
	
	
        
        // Handle the user choosing "Save As" for an EXISTING document
        if (inSaveOperation == NSSaveAsOperation && [self fileURL])
        {
            result = [self migrateToURL:inURL ofType:inType originalContentsURL:inOriginalContentsURL error:&error];
            if (!result)
            {
                if (outError)
                {
                    *outError = error;
                }
                return NO; // bail out and display outError
            }
            else
            {
                OBASSERT([NSThread currentThread] == [self thread]);
                result = [self setMetadataForStoreAtURL:[KTDocument datastoreURLForDocumentURL:inURL UTI:nil]
                                                  error:&error];
            }
        }
        
        if (result)	// keep going if OK
        {
            OBASSERT([NSThread currentThread] == [self thread]);
            result = [managedObjectContext save:&error];
        }
        if (result)
        {
            OBASSERT([NSThread currentThread] == [self thread]);
            result = [[[self mediaManager] managedObjectContext] save:&error];
        }
    }
    
    // Return, making sure to supply appropriate error info
    if (!result && outError) *outError = error;
    OBASSERT( (YES == result) || (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error
    
    return result;
}

/*	Called when performing a "Save As" operation on an existing document
 */
- (BOOL)migrateToURL:(NSURL *)URL ofType:(NSString *)typeName originalContentsURL:(NSURL *)originalContentsURL error:(NSError **)outError
{
	// Build a list of the media files that will require copying/moving to the new doc
	NSManagedObjectContext *mediaMOC = [[self mediaManager] managedObjectContext];
	NSArray *mediaFiles = [mediaMOC allObjectsWithEntityName:@"AbstractMediaFile" error:NULL];
	NSMutableSet *pathsToCopy = [NSMutableSet setWithCapacity:[mediaFiles count]];
	NSMutableSet *pathsToMove = [NSMutableSet setWithCapacity:[mediaFiles count]];
	
	NSEnumerator *mediaFilesEnumerator = [mediaFiles objectEnumerator];
	KTMediaFile *aMediaFile;
	while (aMediaFile = [mediaFilesEnumerator nextObject])
	{
		NSString *path = [aMediaFile currentPath];
		if ([aMediaFile isTemporaryObject])
		{
			[pathsToMove addObjectIgnoringNil:path];
		}
		else
		{
			[pathsToCopy addObjectIgnoringNil:path];
		}
	}
	
	
	// Migrate the main document store
	NSURL *storeURL = [KTDocument datastoreURLForDocumentURL:URL UTI:nil];
	NSPersistentStoreCoordinator *storeCoordinator = [[self managedObjectContext] persistentStoreCoordinator];
    OBASSERT(storeCoordinator);
	
	NSURL *oldDataStoreURL = [KTDocument datastoreURLForDocumentURL:originalContentsURL UTI:nil];
    OBASSERT(oldDataStoreURL);
    
    id oldDataStore = [storeCoordinator persistentStoreForURL:oldDataStoreURL];
    NSAssert5(oldDataStore,
              @"No persistent store found for URL: %@\nPersistent stores: %@\nDocument URL:%@\nOriginal contents URL:%@\nDestination URL:%@",
              [oldDataStoreURL absoluteString],
              [storeCoordinator persistentStores],
              [self fileURL],
              originalContentsURL,
              URL);
    
    if (![storeCoordinator migratePersistentStore:oldDataStore
										    toURL:storeURL
										  options:nil
										 withType:[KTDocument defaultStoreType]
										    error:outError])
	{
		OBASSERT( (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error
		return NO;
	}
	
    
	// Set the new metadata
	if ( ![self setMetadataForStoreAtURL:storeURL error:outError] )
	{
		OBASSERT( (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error
		return NO;
	}	
	
    
	// Migrate the media store
	storeURL = [KTDocument mediaStoreURLForDocumentURL:URL];
	storeCoordinator = [[[self mediaManager] managedObjectContext] persistentStoreCoordinator];
	
	NSURL *oldMediaStoreURL = [KTDocument mediaStoreURLForDocumentURL:originalContentsURL];
    OBASSERT(oldMediaStoreURL);
    id oldMediaStore = [storeCoordinator persistentStoreForURL:oldMediaStoreURL];
    OBASSERT(oldMediaStore);
    if (![storeCoordinator migratePersistentStore:oldMediaStore
										    toURL:storeURL
										  options:nil
										 withType:[KTDocument defaultMediaStoreType]
										    error:outError])
	{
		OBASSERT( (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error
		return NO;
	}
	
	
	// Copy/Move media files
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *newDocMediaPath = [[KTDocument mediaURLForDocumentURL:URL] path];
	
	NSEnumerator *pathsEnumerator = [pathsToCopy objectEnumerator];
	NSString *aPath;	NSString *destinationPath;
	while (aPath = [pathsEnumerator nextObject])
	{
		destinationPath = [newDocMediaPath stringByAppendingPathComponent:[aPath lastPathComponent]];
		[fileManager copyPath:aPath toPath:destinationPath handler:nil];
	}
	
	pathsEnumerator = [pathsToMove objectEnumerator];
	while (aPath = [pathsEnumerator nextObject])
	{
		destinationPath = [newDocMediaPath stringByAppendingPathComponent:[aPath lastPathComponent]];
		[fileManager movePath:aPath toPath:destinationPath handler:nil];
	}
	return YES;
}

#pragma mark -
#pragma mark Quick Look Thumbnail

- (void)startGeneratingQuickLookThumbnail
{
	OBASSERT([NSThread currentThread] == [self thread]);
    
    // Put together the HTML for the thumbnail
	KTHTMLParser *parser = [[KTHTMLParser alloc] initWithPage:[[self documentInfo] root]];
	[parser setHTMLGenerationPurpose:kGeneratingPreview];
	[parser setLiveDataFeeds:NO];
	NSString *thumbnailHTML = [parser parseTemplate];
	[parser release];
	
	
    // Load into webview
    [self performSelectorOnMainThread:@selector(_startGeneratingQuickLookThumbnailWithHTML:)
                           withObject:thumbnailHTML
                        waitUntilDone:NO];
}

- (void)_startGeneratingQuickLookThumbnailWithHTML:(NSString *)thumbnailHTML
{
    // View and WebView handling MUST be on the main thread
    OBASSERT([NSThread isMainThread]);
    
    
	// Create the webview's offscreen window
	unsigned designViewport = [[[[[self documentInfo] root] master] design] viewport];	// Ensures we don't clip anything important
	NSRect frame = NSMakeRect(0.0, 0.0, designViewport+20, designViewport+20);	// The 20 keeps scrollbars out the way
	
	NSWindow *window = [[NSWindow alloc]
                        initWithContentRect:frame styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
	[window setReleasedWhenClosed:NO];	// Otherwise we crash upon quitting - I guess NSApplication closes all windows when terminatating?
	
    
    // Create the webview
    OBASSERT(!_quickLookThumbnailWebView);
	_quickLookThumbnailWebView = [[WebView alloc] initWithFrame:frame];
    
    [_quickLookThumbnailWebView setResourceLoadDelegate:self];
	[window setContentView:_quickLookThumbnailWebView];
    
    
    // We want to know when it's finished loading.
    _quickLookThumbnailLock = [[NSLock alloc] init];
    [_quickLookThumbnailLock lock];
    
    OBASSERT(_quickLookThumbnailWebView);
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(webViewDidFinishLoading:)
                                                 name:WebViewProgressFinishedNotification
                                               object:_quickLookThumbnailWebView];
	
	
	// Go ahead and begin building the thumbnail
    [[_quickLookThumbnailWebView mainFrame] loadHTMLString:thumbnailHTML baseURL:nil];
}

- (BOOL)writeQuickLookThumbnailToDocumentURLIfPossible:(NSURL *)docURL error:(NSError **)error
{
    BOOL result = YES;
    
    
    
    // Wait for the thumbnail to complete. We shall allocate a maximum of 10 seconds for this
    NSDate *documentSaveLimit = [[NSDate date] addTimeInterval:10.0];
    if ([NSThread isMainThread])
    {
        while (![_quickLookThumbnailLock tryLock] &&     // Don't worry, it'll be unlocked again when tearing down the webview
               [documentSaveLimit timeIntervalSinceNow] > 0.0)
        {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:documentSaveLimit];
        }
    }
    else
    {
        OBASSERT(_quickLookThumbnailLock);
        BOOL didLock = [_quickLookThumbnailLock lockBeforeDate:documentSaveLimit];  // The lock can only be acquired once webview 
        if (didLock) [_quickLookThumbnailLock unlock];                              // loading is complete
    }
        
    
        
    // Save the thumbnail to disk
    NSImage *thumbnail = [self performSelectorOnMainThreadAndReturnResult:@selector(_quickLookThumbnail)];
    if (thumbnail)
    {
        NSURL *thumbnailURL = [[KTDocument quickLookURLForDocumentURL:docURL] URLByAppendingPathComponent:@"thumbnail.png" isDirectory:NO];
        OBASSERT(thumbnailURL);	// shouldn't be nil, right?
        
        result = [[thumbnail PNGRepresentation] writeToURL:thumbnailURL options:NSAtomicWrite error:error];
        OBASSERT(result || !error || *error != nil); // make sure we don't return NO with an empty error
    }        
        
    
    return result;
}

/*  Captures the Quick Look thumbnail from the webview if it's finished loading. MUST happen on the main thread.
 *  Has the side effect of disposing of the webview once done.
 */
- (NSImage *)_quickLookThumbnail
{
    NSImage *result = nil;
    
    
    if (_quickLookThumbnailWebView)
    {
        OBASSERT([NSThread isMainThread]);
        
        
        if (![_quickLookThumbnailWebView isLoading])
        {
            // Draw the view
            [_quickLookThumbnailWebView displayIfNeeded];	// Otherwise we'll be capturing a blank frame!
            NSImage *snapshot = [[[[_quickLookThumbnailWebView mainFrame] frameView] documentView] snapshot];
            
            result = [snapshot imageWithMaxWidth:512 height:512 
                                                      behavior:([snapshot width] > [snapshot height]) ? kFitWithinRect : kCropToRect
                                                     alignment:NSImageAlignTop];
            // Now composite "SANDVOX" at the bottom
            NSFont* font = [NSFont boldSystemFontOfSize:95];				// Emperically determine font size
            NSShadow *aShadow = [[[NSShadow alloc] init] autorelease];
            [aShadow setShadowOffset:NSMakeSize(0,0)];
            [aShadow setShadowBlurRadius:32.0];
            [aShadow setShadowColor:[NSColor colorWithCalibratedWhite:1.0 alpha:1.0]];	// white glow
            
            NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                               font, NSFontAttributeName, 
                                               aShadow, NSShadowAttributeName, 
                                               [NSColor colorWithCalibratedWhite:0.25 alpha:1.0], NSForegroundColorAttributeName,
                                               nil];
            NSString *s = @"SANDVOX";	// No need to localize of course
            
            NSSize textSize = [s sizeWithAttributes:attributes];
            float left = ([result size].width - textSize.width) / 2.0;
            float bottom = 7;		// empirically - seems to be a good offset for when shrunk to 32x32
            
            [result lockFocus];
            [s drawAtPoint:NSMakePoint(left, bottom) withAttributes:attributes];
            [result unlockFocus];
        }
        
        
        
        // Dump the webview and window
        [_quickLookThumbnailWebView setResourceLoadDelegate:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:WebViewProgressFinishedNotification object:_quickLookThumbnailWebView];
        
        NSWindow *webViewWindow = [_quickLookThumbnailWebView window];
        [_quickLookThumbnailWebView release];   _quickLookThumbnailWebView = nil;
        [webViewWindow release];
        
        
        // Remove the lock. In the event that loading the webview timed out, it will still be locked.
        // So, we call -tryLock followed by -unlock as a neat trick to ensure it's unlocked
        [_quickLookThumbnailLock tryLock];
        [_quickLookThumbnailLock unlock];
        
        [_quickLookThumbnailLock release];
        _quickLookThumbnailLock = nil;
    }
	
    
    // Finish up
    return result;
}

#pragma mark delegate

- (NSURLRequest *)webView:(WebView *)sender
				 resource:(id)identifier
		  willSendRequest:(NSURLRequest *)request
		 redirectResponse:(NSURLResponse *)redirectResponse
		   fromDataSource:(WebDataSource *)dataSource
{
	NSURLRequest *result = request;
    
    NSURL *requestURL = [request URL];
	if ([requestURL hasNetworkLocation] && ![[requestURL scheme] isEqualToString:@"svxmedia"])
	{
		result = nil;
		NSMutableURLRequest *mutableRequest = [[request mutableCopy] autorelease];
		[mutableRequest setCachePolicy:NSURLRequestReturnCacheDataDontLoad];	// don't load, but return cached value
		result = mutableRequest;
	}
    
    return result;
}

- (void)webViewDidFinishLoading:(NSNotification *)notification
{
    // Release the hounds! er, I mean the lock.
    // This allows a background thread to acquire the lock, signalling that saving can continue.
    OBASSERT(_quickLookThumbnailLock);
    [_quickLookThumbnailLock unlock];
}

#pragma mark -
#pragma mark Quick Look preview

/*  Parses the home page to generate a Quick Look preview
 */
- (NSString *)quickLookPreviewHTML
{
    OBASSERT([NSThread currentThread] == [self thread]);
    
    KTHTMLParser *parser = [[KTHTMLParser alloc] initWithPage:[[self documentInfo] root]];
    [parser setHTMLGenerationPurpose:kGeneratingQuickLookPreview];
    NSString *result = [parser parseTemplate];
    [parser release];
    
    return result;
}

#pragma mark -
#pragma mark Autosave

/*  Run the autosave on a background thread to avoid upsetting users
 */
- (void)autosaveDocumentWithDelegate:(id)delegate didAutosaveSelector:(SEL)didAutosaveSelector contextInfo:(void *)contextInfo
{
    // Prepare callback invocation
    NSInvocation *callback = nil;
    if (delegate)
    {
        NSMethodSignature *callbackSignature = [delegate methodSignatureForSelector:didAutosaveSelector];
        NSInvocation *callback = [NSInvocation invocationWithMethodSignature:callbackSignature];
        [callback setTarget:delegate];
        [callback setSelector:didAutosaveSelector];
        [callback setArgument:&self atIndex:2];
        [callback setArgument:&contextInfo atIndex:4];	// Argument 3 will be set from the save result
    }
    
    
    // We only allow triggering an autosave on the main thread. i.e. ignore autosaves during migration
    if (![NSThread isMainThread])
    {
        BOOL didSave = NO;
        [callback setArgument:&didSave atIndex:3];
        [callback invoke];
        return;
    }
    
        
    // Do the save in the background
    [NSThread detachNewThreadSelector:@selector(threadedAutosaveWithCallback:) toTarget:self withObject:callback];
}

- (void)threadedAutosaveWithCallback:(NSInvocation *)callback
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    // Because we're a secondary thread, retain for duration of operation
    NSURL *URL = [[self fileURL] retain];           
    NSString *fileType = [[self fileType] copy];
    
    // Do the save
    NSError *error;
    BOOL didSave = [self saveToURL:URL ofType:fileType forSaveOperation:NSAutosaveOperation error:&error];
    
    // Tidy up
    [URL release];
    [fileType release];
    
    // Perform callback. Does nothing if callback is nil
    [callback setArgument:&didSave atIndex:3];
    [callback performSelectorOnMainThread:@selector(invoke)
                               withObject:nil
                            waitUntilDone:NO];
    
    // Tidy up
    [pool release];
}

/*  We override this accessor to always be nil. Otherwise, the doc architecture will assume our doc is the autosaved copy and delete it!
 */
- (NSURL *)autosavedContentsFileURL { return nil; }
- (void)setAutosavedContentsFileURL:(NSURL *)absoluteURL { }

#pragma mark -
#pragma mark Change Count

- (void)processPendingChangesAndClearChangeCount
{
	LOGMETHOD;
	[[self managedObjectContext] processPendingChanges];
	[[self undoManager] removeAllActions];
	[self updateChangeCount:NSChangeCleared];
}

@end
