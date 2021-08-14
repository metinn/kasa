# Kasa

> ⚠ Experimental, expect bugs and breaking changes

Tiny ***Codable*** Store based on SQLITE with no external dependencies.

## Basic Usage

Create ***KasaStorable*** object (Codable + PrimaryKey):

```swift
struct Person: KasaStorable {
    let uuid: String
    let name: String
    let age: Int
    let height: Double
    
    var primaryKey: String { return uuid }
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
    
    var person = Person(uuid: "theuuid", name: "SomePerson", age: 28, height: 172.3)
    try kasa.save(person)
    
    // update
    person.age = 29
    try kasa.save(person)
} catch let err {
    ...
}
```

Read person data:

```swift
do {
    ...
    
    let person = try kasa.object(Person.self, forUuid: "theuuid")
    print("Kasa:", person ?? "nil")
} catch let err {
    ...
}
```

Filter objects with where part of sql. Properties can be accessed with $ sign. Accessing nested objects is also possible like $person.adress.postCode 

```swift
do {
    ...
    
    let persons = try kasa.objects(Person.self, filter: "$age >= ?", params: [30], limit: 7)
    print("Kasa:", persons.first?.name ?? "nil")
} catch let err {
    ...
}
```


## Documentation
TODO:

- API
    - Save
    - Object
    - Objects
    - Remove
    - RemoveAll
    - CreateIndex
    - Migration
