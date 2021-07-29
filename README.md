# Kasa

> ⚠ Experimental, expect bugs and breaking changes

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
do {
    let kasa = try Kasa(name: "test")
    
    ...
} catch let err {
    print("Kasa:", "Some error occured:", err.localizedDescription)
}
```

Save some person information:

```swift
do {
    ...
    
    let person = Person(name: "SomePerson", age: 28, height: 172.3)
    try kasa.set(person, forKey: "key1")
} catch let err {
    ...
}
```

> update block starts transaction. Exceptions inside update block triggers rollback then calls onError callback

Read person data:

```swift
do {
    ...
    
    let person = try kasa.get(Person.self, forKey: "key1")
    print("Kasa:", person ?? "nil")
} catch let err {
    ...
}
```

If you have ***Sortable Key*** you can get many objects

```swift
do {
    ...
    
    let persons = try kasa.getMany(Person.self, startKey: "Person-00010", endKey: "Person-00030", limit: 20)
    print("Kasa:", persons.first?.name ?? "nil")
} catch let err {
    ...
}
```
