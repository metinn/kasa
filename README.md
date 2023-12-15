# Kasa

Tiny ***Codable*** Store based on SQLITE with no external dependencies.

- Tiny (~300 loc),
    - Easy to read and hack
- Painless, only needs Codable & Identifiable
    - Zero setup code
        - No database, table, index creation needed 
    - Easy integration, and disintegration if needed
- Good and consistent performance
    - Query performance with sqlite json1 extension is good. 
    - Additional indexes can be created based on expression

## Basic Usage

Create ***Storable*** (Codable & Identifiable) object:

```swift
struct Person: Storable {
    let id: String
    let name: String
    var age: Int
    let height: Double
}

func testKasa() {
    do {
        // Create store
        let kasa = try await Kasa(name: "test")
        
        // Save some person information
        var person = Person(id: "theId", name: "SomePerson", age: 28, height: 172.3)
        try await kasa.save(person)
        
        // update
        person.age = 29
        try await kasa.save(person)
    
        // fetch object with id
        let fetchedPerson = try await kasa.object(Person.self, forId: "theId")
        print("Kasa:", fetchedPerson ?? "nil")
    
        // fetch multiple objects
        // Filter objects with where part of sql. Properties can be accessed with $ sign. Accessing nested objects is also possible like $person.adress.postCode
        let persons = try await kasa.objects(Person.self, filter: "$age >= ? and $height < ?", params: [30, 175], limit: 7)
        print("Kasa:", persons.first?.name ?? "nil")
    
    } catch let err {
        print("Kasa:", "Some error occured:", err.localizedDescription)
    }
}
```

## Usage Tips:
- Kasa is an actor, an instance can be accessed from multiple threads safely. Also multiple instances can be used to access Sqlite in parallel because sqlite is in "multi-thread" mode.
- While sqlite performance is amazing, JSONDecoder performance is not. So getting to much objects from database (like >1000) will be costly
    - Try to filter objects in query rather than getting all and filter it in swift.
- Kasa using [JSON1 extension](https://www.sqlite.org/json1.html). The functions can be used in filter query
    - The only syntaxtic sugar in the project is being able to write `$age` in filter query instead of `json_extract(value, '$.age')`
- Migration can be done with `runMigration` function. This project does not keep the version number or handles the concurency. It need to be done inside the app.
- When you need to run sql queries directly in sqlite, you can reach sqlite db from `kasa.db`

## How it works
- JSONEndoder and JSONDecoder are used for conversion between Codable and Data
- Data saved on Sqlite table, named same as the codable object
    - Table has 2 column: uuid (primary key) and value (json data)
- To run queries on json data, sqlite JSON1 extension is used
- Check out [kasa.swift](https://github.com/metinn/kasa/blob/master/Sources/kasa/kasa.swift) 
