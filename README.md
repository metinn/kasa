# Kasa

> ⚠ Experimental, expect bugs and breaking changes

Tiny ***Codable*** Store based on SQLITE with no external dependencies.

## Goals of this project:
- Very easy to start with. 
    - Add primary key to a Codable struct and use it
    - No need to create tables, create indexes later if you need
    - Nested objects can be saved, retrived and filtered with no additional effort
- Open tiny library, restricted to be less than 500 loc
    - Reading the source and hacking is easy
    - Save lots of build time! (and maybe electricity, heat, CO2... who knows 🤔)
- Good and consistent performance
    - Query performance with sqlite json1 extension is good. 
    - Indexes can be created based on expression
- Upgrade path
    - While this library should cover many use cases, it is better to have a way to migrate when needed.
    - Codable will be the bridge in the migration
    - TODO: An example

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

do {
    // Create store
    let kasa = try Kasa(name: "test")
    
    // Save some person information
    var person = Person(uuid: "theuuid", name: "SomePerson", age: 28, height: 172.3)
    try kasa.save(person)
    
    // update
    person.age = 29
    try kasa.save(person)

    // fetch object with uuid
    let fetchedPerson = try kasa.object(Person.self, forUuid: "theuuid")
    print("Kasa:", person ?? "nil")

    // fetch multiple objects
    // Filter objects with where part of sql. Properties can be accessed with $ sign. Accessing nested objects is also possible like $person.adress.postCode 
    let persons = try kasa.objects(Person.self, filter: "$age >= ? and $height < ?", params: [30, 175], limit: 7)
    print("Kasa:", persons.first?.name ?? "nil")

} catch let err {
    print("Kasa:", "Some error occured:", err.localizedDescription)
}
```

## Usage Tips:
- Sqlite is in "multi-thread" mode. Accessing to database from multiple thread is ok, but do not use same instance across threads
    - Creating a new instance inside funciton is recommended. Keep the instance lifetime inside the scope
- While sqlite performance is amazing, JSONDecoder performance is not. So getting to much objects from database (like >1000) will be costly
    - Try to filter objects in query rather than getting all and filter it in swift.
- Kasa using [JSON1 extension](https://www.sqlite.org/json1.html). The functions can be used in filter query
    - The only syntaxtic sugar in the project is being able to write `$age` in filter query instead of `json_extract(value, '$.age')`
- Migration can be done with `runMigration` function. This project does not keep the version number or handles the concurency. It need to be done inside the app.
    - TODO: An example
- When you need to run sql queries directly in sqlite, you can reach sqlite db from `kasa.db`


## How it works
- You can read the source [kasa.swift](https://github.com/metinn/kasa/blob/master/Sources/kasa/kasa.swift)
- If you don't want to
    - JSONEndoder and JSONDecoder are used for conversion between Codable and Data
    - Data saved on Sqlite table, named same as the codable object
        - Table has 2 column: uuid (primary key) and value (json data)
    - To run queries on json data, sqlite JSON1 extension is used

