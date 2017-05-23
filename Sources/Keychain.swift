//
//  Keychain.swift
//  Released
//
//  Created by Fernando Fernandes on 5/1/17.
//  Copyright © 2017 backslash-f. All rights reserved.
//

import Foundation

/// Wrapper around Apple's `Keychain Services`.
/// Provides the following features:
///  - **Saves** / **Updates** credentials to the `Keychain`.
///  - **Reads** credentials from the `Keychain`.
///  - **Deletes** credentials from the `Keychain`.
///
/// Usage examples:
///
///  - To save a credential:
///
/// ```
/// Keychain(service: SpotifyDefinitions.sessionService,
///          account: SpotifyDefinitions.canonicalUsername
/// ).saveCredential(stringCanonicalUsername)
/// ```
///
///  - To read a credential:
///
/// ```
/// Keychain(service: SpotifyDefinitions.sessionService,
///          account: SpotifyDefinitions.canonicalUsername
/// ).readCredential())
/// ```
struct Keychain {
    
    // MARK: - Types
    
    /// Represents the types of the errors that can happen during operations.
    ///
    /// - noCredential: No credential was found in the keychain. Used internally
    /// to distinguish between create and update operations.
    /// - unexpectedCredentialData: Cannot read / decode the credential from the
    /// keychain. Probably corrupted.
    /// - unhandledError: Generic error not handled by the `Keychain` struct.
    /// Also holds the `OSStatus` of the error (a 32-bit result error code).
    enum KeychainError: Error {
        case noCredential
        case unexpectedCredentialData
        case unhandledError(status: OSStatus)
    }
    
    // MARK: - Properties
    
    /// It is possible to distribute the credentials among multiple app
    /// "services". Some examples: "SpotifyService", "FacebookService",
    /// "ThatRestEndpoint", etc. It's ok to use only a single service too.
    let service: String
    
    /// Identify the "element" to be saved, for example: "token", "tokenSecret",
    /// "password", "secretKey", etc.
    private(set) var account: String
    
    // **Not** specifying an access group will create items specific to each
    // app.
    //
    // Specifying an access group will create items shared accross apps that use
    // the same access group.
    let accessGroup: String?
    
    // MARK: - Lifecycle
    
    /// Initializes a `Keychain` struct with the given parameters. For example:
    ///
    /// ````
    /// Keychain(service: "myAppService", account: "password")
    /// ````
    ///
    /// After the initialization, the following functions are available:
    ///
    /// ````
    /// .saveCredential(_ credential: String) throws
    /// .readCredential() throws -> String
    /// .deleteCredential()
    /// ````
    ///
    /// - Parameters:
    ///   - service: It is possible to distribute the credentials among multiple
    /// app "services". Some examples: "SpotifyService", "FacebookService",
    /// "ThatRestEndpoint", etc. It's ok to use only a single service too.
    ///   - account: Identify the "element" to be saved, for example: "token",
    /// "tokenSecret", "password", "secretKey", etc.
    ///   - accessGroup: Optional. **Not** specifying an access group will
    /// create items specific to each app. Specifying an access group will
    /// create items shared accross apps that use the same access group.
    init(service: String, account: String, accessGroup: String? = nil) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup
    }
    
    // MARK: - Save
    
    /// Saves (adds) the given credential into the keychain for the given
    /// service / account. If the account already has a credential in the
    /// keychain, the credential will be updated. For example:
    ///
    /// ````
    /// // Saves a new credential for "tokenSecret":
    /// Keychain(service: "myAppService", account: "tokenSecret").saveCredential("secret")
    ///
    /// // Updates the credential of "tokenSecret":
    /// Keychain(service: "myAppService", account: "tokenSecret").saveCredential("newSecret")
    /// ````
    ///
    /// Before saving, the given credential is encapsulated into a `Data`
    /// object and encoded with `String.Encoding.utf8`.
    ///
    /// The credentials `Data` has `kSecValueData` for its attribute key,
    /// signaling that the data is secret (encrypted) and may require the user
    /// to enter a password for access.
    ///
    /// - Parameter credential: The credential to be saved or updated in the
    /// keychain.
    /// - Throws: `KeychainError.unhandledError` if any error takes place. The
    /// status of the operation is also returned via `OSStatus`
    /// (32-bit result error code).
    func saveCredential(_ credential: String) throws {
        
        // Encode the credential into an Data object.
        let encodedCredential = credential.data(using: String.Encoding.utf8)!
        
        do {
            // Check for an existing item in the keychain.
            try _ = readCredential()
            
            // Update the existing item with the new credential.
            var attributesToUpdate = [String : AnyObject]()
            attributesToUpdate[kSecValueData as String] = encodedCredential as AnyObject?
            
            let query = Keychain.query(withService: service, account: account, accessGroup: accessGroup)
            let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            
            // Throw an error if an unexpected status was returned.
            guard status == noErr else { throw KeychainError.unhandledError(status: status) }
            
        } catch KeychainError.noCredential {
            
            // No credential was found in the keychain. Create a dictionary to
            // save as a new keychain item.
            var newItem = Keychain.query(withService: service, account: account, accessGroup: accessGroup)
            newItem[kSecValueData as String] = encodedCredential as AnyObject?
            
            // Add a the new item to the keychain.
            let status = SecItemAdd(newItem as CFDictionary, nil)
            
            // Throw an error if an unexpected status was returned.
            guard status == noErr else { throw KeychainError.unhandledError(status: status) }
        }
    }
    
    // MARK: - Read
    
    /// Reads (decodes) the credential from the Keychain.
    ///
    /// - Returns: The credential decoded from the Keychain, in plain String.
    /// - Throws: A `KeychainError`.
    func readCredential() throws -> String  {
        
        // Build a query to find the item that matches the service, account and
        // access group.
        var query = Keychain.query(withService: service, account: account, accessGroup: accessGroup)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnAttributes as String] = kCFBooleanTrue
        query[kSecReturnData as String] = kCFBooleanTrue
        
        // Try to fetch the existing keychain item that matches the query.
        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }
        
        // Check the return status and throw an error if appropriate.
        guard status != errSecItemNotFound else { throw KeychainError.noCredential }
        guard status == noErr else { throw KeychainError.unhandledError(status: status) }
        
        // Parse the credential string from the query result.
        guard let existingItem = queryResult as? [String : AnyObject],
            let credentialData = existingItem[kSecValueData as String] as? Data,
            let credential = String(data: credentialData, encoding: String.Encoding.utf8)
            else {
                throw KeychainError.unexpectedCredentialData
        }
        
        return credential
    }
    
    // MARK: - Remove
    
    
    /// Deletes the credential from the Keychain.
    ///
    /// - Throws: `KeychainError.unhandledError` if any error takes place. The
    /// status of the operation is also returned via `OSStatus`
    /// (32-bit result error code).
    func deleteCredential() throws {
        
        // Delete the existing item from the keychain.
        let query = Keychain.query(withService: service, account: account, accessGroup: accessGroup)
        let status = SecItemDelete(query as CFDictionary)
        
        // Throw an error if an unexpected status was returned.
        guard status == noErr || status == errSecItemNotFound else { throw KeychainError.unhandledError(status: status) }
    }
    
    // MARK: - Query
    
    /// Convenience function that creates Keychain queries.
    private static func query(withService service: String, account: String? = nil, accessGroup: String? = nil) -> [String : AnyObject] {
        var query = [String : AnyObject]()
        query[kSecClass as String] = kSecClassGenericPassword
        query[kSecAttrService as String] = service as AnyObject?
        
        if let account = account {
            query[kSecAttrAccount as String] = account as AnyObject?
        }
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup as AnyObject?
        }
        
        return query
    }
}
