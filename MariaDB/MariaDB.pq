// This file contains your Data Connector logic
section MariaDB;

[DataSource.Kind="MariaDB", Publish="MariaDB.Publish"]
shared MariaDB.Contents = (optional message as text) =>
    let
        _message = if (message <> null) then message else "(no message)",
        a = "Hello from MariaDB: " & _message
    in
        a;

// Data Source Kind description
MariaDB = [
    Authentication = [
        UsernamePassword = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
MariaDB.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = MariaDB.Icons,
    SourceTypeImage = MariaDB.Icons
];

MariaDB.Icons = [
    Icon16 = { Extension.Contents("MariaDB16.png"), Extension.Contents("MariaDB20.png"), Extension.Contents("MariaDB24.png"), Extension.Contents("MariaDB32.png") },
    Icon32 = { Extension.Contents("MariaDB32.png"), Extension.Contents("MariaDB40.png"), Extension.Contents("MariaDB48.png"), Extension.Contents("MariaDB64.png") }
];
