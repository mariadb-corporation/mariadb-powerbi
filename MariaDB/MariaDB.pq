// This file contains your Data Connector logic
section MariaDB;

// MariaDB Information Schema
INFORMATION_SCHEMA_TABLE_NAME = "TABLE_NAME";

[DataSource.Kind="MariaDB", Publish="MariaDB.Publish"]
shared MariaDB.Database = Value.ReplaceType(MariaDBDatabaseImplOdbc, MariaDBDatabaseType);

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

CredentialConnectionString = "";

MariaDBDatabaseImpl = (server as text, optional database as text) as table =>
    let
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
        //AdoDotNetDataSource = AdoDotNet.DataSource(AdoNetProvider, CredentialConnectionString),
        //NavTable = NavigationTable.Simple(AdoDotNetDataSource)
        //fn = Record.FieldNames(CredentialConnectionString),
        //m1 = List.Accumulate(fn, 0, (state, current) => Text.Combine({if state is text then state else "", Text.From(current), ": ", Text.From(Record.Field(CredentialConnectionString, current)), ", "})),
        //NavTable = CreateNavTable(m1),
        //TableNamesList = AdoNet.TableNames(AdoDotNetDataSource, database),
        NavTable = NavigationTable.FromDatabase(CredentialConnectionString, database)
    in
        NavTable;

MariaDBDatabaseImplOdbc = (server as text, optional database as text) as table =>
    let
        // Get the current credential, and check what type of authentication we're using
        Credential = Extension.CurrentCredential(),
        CredentialRecord = if (Credential[AuthenticationKind]?) = "UsernamePassword" then 
                [ UID = Credential[Username], PWD = Credential[Password] ]
            // unknown authentication kind - return an error
            else
                error "Username and Password credentials required.", 
        CredentialConnectionString = Record.Combine({
            [Driver = ODBCDriver, Server = server],
            if database <> null then [Database = database] else [],
            CredentialRecord
        }),
        OdbcDataSource = Odbc.DataSource(CredentialConnectionString, [
            // Enables client side connection pooling for the ODBC driver.
            // Most drivers will want to set this value to true.
            ClientConnectionPooling = true,
            // When HierarchialNavigation is set to true, the navigation tree
            // will be organized by Database -> Schema -> Table. When set to false,
            // all tables will be displayed in a flat list using fully qualified names. 
            HierarchicalNavigation = true,
            // Use the SqlCapabilities record to specify driver capabilities that are not
            // discoverable through ODBC 3.8, and to override capabilities reported by
            // the driver. 
            SqlCapabilities = [
                SupportsTop = false,
                LimitClauseKind = LimitClauseKind.Limit,
                Sql92Conformance = 8 /* SQL_SC_SQL92_FULL */,
                GroupByCapabilities = 4 /* SQL_GB_NO_RELATION */,
                FractionalSecondsScale = 3
            ],
            SoftNumbers = true,
            HideNativeQuery = true,
            // Use the SQLGetInfo record to override values returned by the driver.
            SQLGetInfo = [
                SQL_SQL92_PREDICATES = 0x0000FFFF,
                SQL_AGGREGATE_FUNCTIONS = 0xFF
            ]
            ]),
        Filtered = if database <> null then OdbcDataSource{[Name = database]}[Data] else OdbcDataSource
    in
        Filtered;

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

// ODBC helpers
ODBCDriver = "MariaDB ODBC 3.1 Driver";

// References:
// Power Query ODBC: https://docs.microsoft.com/en-us/power-query/odbc#limitclause
// MariaDB: https://mariadb.com/kb/en/limit/
/*ODBC.LimitClause = (skip as nullable number, take as number) as record =>
    let
        limit = Text.Format("LIMIT #{0}#{1}", if (skip <> null) then Text.Combine({skip, ", "}) else "", {take})
    in
        [
            Text = limit,
            Location = "AfterQuerySpecification"
        ];*/

// ADO.NET helpers
// MySqlConnector for ADO.NET has to be installed:
// https://mariadb.com/kb/en/mysqlconnector-for-adonet/
// ADO.NET Provider name should be registered in .NET Framework Machine.config > system.data > DbProviderFactories
AdoNetProvider = "MySql.Data.MySqlClient";

AdoNet.Tables = (ConnectionString as record, DatabaseName as text) as table =>
    let 
        AdoDotNetDataSource = AdoDotNet.DataSource(AdoNetProvider, ConnectionString),
        TablesFunction = AdoDotNetDataSource{[CollectionName = "Tables"]}[Data],
        Tables = TablesFunction(null, DatabaseName, null, null)
    in
        Tables;

AdoNet.TableNames = (ConnectionString as record, DatabaseName as text) as list =>
    let 
        Tables = AdoNet.Tables(ConnectionString, DatabaseName),
        TableNames = Table.Column(Tables, INFORMATION_SCHEMA_TABLE_NAME),
        DistinctTableNames = List.Distinct(TableNames)
    in
        DistinctTableNames;

AdoNet.TableContents = (ConnectionString as record, TableName as text, optional limit as number) as table =>
    let
        Query = Text.Combine({
            Text.Format("SELECT * FROM #{0}", {TableName}),
            if limit = null or Number.IsNaN(limit) then "" else Text.Format(" LIMIT #{0}", {Number.Round(limit)})
        }),
        Result = AdoDotNet.Query(AdoNetProvider, ConnectionString, Query)
    in
        Result;

// Navigation Table support
NavigationTable.RowFromTable = (ConnectionString as record, TableName as text) as list =>
    let
        PreviewRowCountLimit = null,
        // Structure: {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}
        Row = {TableName, TableName, AdoNet.TableContents(ConnectionString, TableName, PreviewRowCountLimit),  "Table",    "Table",    true}
    in
        Row;

NavigationTable.FromDatabase = (ConnectionString as record, Database as text) as table =>
    let
        TableNames = AdoNet.TableNames(ConnectionString, Database),
        NavRows = List.Accumulate(TableNames, 0, (state, current) => List.Combine({
            if state is list then state else {},
            { NavigationTable.RowFromTable(ConnectionString, current) }
        })),
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            NavRows
            ),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

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