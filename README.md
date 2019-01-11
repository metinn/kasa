# Kasa

Tiny Key-***Codable*** Store based on SQLITE with no external dependencies.

## Usage

Create ***Codable*** object:

```swift
struct Person: Codable {
    let name: String
    let age: Int
    let height: Double
}
```

Create store:

```swift
let kasa = try? Kasa(name: "test")
```

Save some person information:

```swift
let person = Person(name: "SomePerson", age: 28, height: 172.3)
kasa.update { tran in
    try tran.save(person, withKey: "key")
}.onError { err in
    print("Kasa:", "Some error occured:", err.localizedDescription)
}
```

> update block starts transaction. Exceptions inside update block triggers rollback then calls onError callback

Read person data:

```swift
kasa.view { tran in
    let person = try tran.fetch(Person.self, withKey: "key")
    print("Kasa:", person ?? "nil")
}.onError { err in
    print("Kasa:", "Some error occured:", err.localizedDescription)
}
```

For saving data Synchronously use `updateSync` blocks

```swift
let person = Person(name: "SomePerson", age: 28, height: 172.3)
let err = kasa.updateSync { tran in
    try tran.save(person, withKey: "key")
}
if let err = err {
    print("Kasa:", "Some error occured:", err.localizedDescription)
}
```

For reading data Synchronously use `viewSync` block

```swift
let err = kasa.viewSync { tran in
    let person = try tran.fetch(Person.self, withKey: "key")
    print("Kasa:", person ?? "nil")
}
if let err = err {
    print("Kasa:", "Some error occured:", err.localizedDescription)
}
```

If you have ***Sortable Key*** you can get many objects

```swift
kasa.view { tran in
    let persons = try tran.fetchMany(Person.self, startKey: "Person-00010", toKey: "Person-00030", limit: 20)
    print("Kasa:", persons.first?.name ?? "nil")
}.onError { err in
    print("Kasa:", "Some error occured:", err.localizedDescription)
}
```
