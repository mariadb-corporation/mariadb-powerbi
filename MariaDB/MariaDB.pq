// This file contains your Data Connector logic
section MariaDB;

[DataSource.Kind="MariaDB", Publish="MariaDB.Publish"]
shared MariaDB.Database = Value.ReplaceType(MariaDBDatabaseImpl, MariaDBDatabaseType);

MariaDBDatabaseType = type function (
    server as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("GetData_Server_FieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("GetData_Server_FieldDescription")
    ]),
    optional database as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("GetData_Database_FieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("GetData_Database_FieldDescription")
    ]))
    as table meta [
        Documentation.Name = Extension.LoadString("GetData_Title")
    ];

MariaDBDatabaseImpl = (server as text, optional database as text) as table =>
    let
        // MySqlConnector for ADO.NET has to be installed:
        // https://mariadb.com/kb/en/mysqlconnector-for-adonet/
        // ADO.NET Provider name should be registered in .NET Framework Machine.config > system.data > DbProviderFactories
        Provider = "MySql.Data.MySqlClient",
        // Get the current credential, and check what type of authentication we're using
        Credential = Extension.CurrentCredential(),
        CredentialRecord = if (Credential[AuthenticationKind]?) = "UsernamePassword" then 
                [ UID = Credential[Username], PWD = Credential[Password] ]
            // unknown authentication kind - return an error
            else
                error "Username and Password credentials required.", 
        CredentialConnectionString = Record.Combine({
            [server = server],
            if database <> null then [database = database] else [],
            CredentialRecord
        }),
        //AdoDotNetDataSource = AdoDotNet.DataSource(Provider, CredentialConnectionString),
        //NavTable = NavigationTable.Simple(AdoDotNetDataSource)
        fn = Record.FieldNames(CredentialConnectionString),
        m1 = List.Accumulate(fn, 0, (state, current) => Text.Combine({if state is text then state else "", Text.From(current), ": ", Text.From(Record.Field(CredentialConnectionString, current)), ", "})),
        NavTable = CreateNavTable(m1)
    in
        NavTable;

// Implementation functions
FunctionCallThatReturnsATable = () as table => #table({"DynamicColumn"}, {{"Dynamic Value"}});
AnotherFunction.Contents = () => "Returns a static string when invoked.";

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
    SupportsDirectQuery = true,     // enables direct query
    Category = "Database",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = MariaDB.Icons,
    SourceTypeImage = MariaDB.Icons
];

MariaDB.Icons = [
    Icon16 = { Extension.Contents("MariaDB16.png"), Extension.Contents("MariaDB20.png"), Extension.Contents("MariaDB24.png"), Extension.Contents("MariaDB32.png") },
    Icon32 = { Extension.Contents("MariaDB32.png"), Extension.Contents("MariaDB40.png"), Extension.Contents("MariaDB48.png"), Extension.Contents("MariaDB64.png") }
];

// Navigation Table support
NavigationTable.Simple = (AdoDotNetDataSource as table) as table =>
    let
        objects = #table(
            {"Name",       "Key",        "Data",                           "ItemKind", "ItemName", "IsLeaf"},{
            {"Item1",      "item1",      #table({"Column1"}, {{"Item1"}}), "Table",    "Table",    true},
            {"Item2",      "item2",      #table({"Column1"}, {{"Item2"}}), "Table",    "Table",    true},
            {"Item3",      "item3",      FunctionCallThatReturnsATable(),  "Table",    "Table",    true},            
            {"MyFunction", "myfunction", AnotherFunction.Contents(),       "Function", "Function", true}
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

NavigationTable.Nested = () as table =>
    let
        objects = #table(
            {"Name",       "Key",  "Data",                "ItemKind", "ItemName", "IsLeaf"},{
            {"Nested A",   "n1",   CreateNavTable("AAA"), "Database",    "Database",    false},
            {"Nested B",   "n2",   CreateNavTable("BBB"), "Folder",    "Folder",    false},
            {"Nested C",   "n3",   CreateNavTable("CCC"), "Sheet",    "Sheet",    false}
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

CreateNavTable = (message as text) as table => 
    let
        objects = #table(
            {"Name",  "Key",   "Data",                           "ItemKind", "ItemName", "IsLeaf"},{
            {"Item1", "item1", #table({"Column1"}, {{message}}), "Table",    "Table",    true},
            {"Item2", "item2", #table({"Column1"}, {{message}}), "Table",    "Table",    true}
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

// Common library code
Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;