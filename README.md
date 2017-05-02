# Keychain
Wrapper around Apple's Keychain Services.  
Based on Apple's sample project [GenericKeychain](https://developer.apple.com/library/content/samplecode/GenericKeychain/Introduction/Intro.html).

## Usage

### Saving 💾
````
Keychain(service: "myService", account: "tokenSecret").saveCredential("Hi!")
````

### Updating ✍🏻
````
Keychain(service: "myService", account: "tokenSecret").saveCredential("Hi again!")
````

### Reading 🔍
````
Keychain(service: "myService", account: "tokenSecret").readCredential())
````

### Deleting 💀
````
Keychain(service: "myService", account: "tokenSecret").deleteCredential()
````

Notice that every API `throws`. So:
````
do {
    try Keychain...
} catch {
    print(error)
}
````

### Swift package manager 📦
Add it to the dependencies value of your `Package.swift`:
````
dependencies: [
    .Package(url: "https://github.com/backslash-f/keychain.git", majorVersion: 1)
]
````
