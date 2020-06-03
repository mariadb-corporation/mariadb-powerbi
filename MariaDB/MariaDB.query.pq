//section MariaDBTests;

// Use this file to write queries to test your data connector
let
    result = MariaDB.Database("localhost"),
    tables = result{[Name="flights"]}[Data]
in
    Table.FirstN(tables, 3)