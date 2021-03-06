//
//  CK2Authentication.h
//  Connection
//
//  Created by Mike on 18/12/2012.
//
//

#import <Foundation/Foundation.h>


#pragma mark SSH Host Fingerprint

@interface NSURLProtectionSpace (CK2SSHHostFingerprint)

// Creates a protection space with CK2AuthenticationMethodSSHHostFingerprint. (Other NSURLProtectionSpace APIs ignore the auth method and change it to NSURLAuthenticationDefault
+ (NSURLProtectionSpace *)ck2_SSHHostFingerprintProtectionSpaceWithHost:(NSString *)host;

extern NSString * const CK2AuthenticationMethodSSHHostFingerprint;

@end


@interface NSURLCredential (CK2SSHHostFingerprint)

// NSURLCredentialPersistencePermanent indicates new keys should be added to the known_hosts file
+ (NSURLCredential *)ck2_credentialWithSSHKnownHostsFileURL:(NSURL *)knownHosts persistence:(NSURLCredentialPersistence)persistence;
- (NSURL *)ck2_SSHKnownHostsFileURL;

@end
