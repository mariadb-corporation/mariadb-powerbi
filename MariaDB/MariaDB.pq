// This file contains your Data Connector logic
section MariaDB;

// MariaDB Information Schema
INFORMATION_SCHEMA_TABLE_NAME = "TABLE_NAME";

[DataSource.Kind="MariaDB", Publish="MariaDB.Publish"]
shared MariaDB.Database = Value.ReplaceType(MariaDBDatabaseImplOdbc, MariaDBDatabaseType);

// The server parameter has a full name to overcome the limitation of the Data Source Settings dialog in Power BI Desktop:
/*
Note: We currently recommend you do not include a Label for your data source if your function has required parameters, 
as users will not be able to distinguish between the different credentials they have entered. We are hoping to improve this 
in the future (i.e. allowing data connectors to display their own custom data source paths).
Source: https://github.com/Microsoft/DataConnectors/blob/master/docs/m-extensions.md#data-source-path-format
*/
MariaDBDatabaseType = type function (
    #"Maria DB Server" as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("GetData_Server_FieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("GetData_Server_FieldDescription"),
        Documentation.SampleValues = {"servername", "servername:portnumber"}
    ]),
    optional database as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("GetData_Database_FieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("GetData_Database_FieldDescription")
    ]))
    as table meta [
        Documentation.Name = Extension.LoadString("GetData_Title")
    ];

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

// Data Source Kind description
MariaDB = [
    TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath),
            server = json[server]
        in
            { "MariaDB.Database", server},
    Authentication = [
        UsernamePassword = []
    ]//,
    // Label not in use following Microsoft recommendation (also see the "MariaDBDatabaseImplOdbc" note above):
    // https://github.com/Microsoft/DataConnectors/blob/master/docs/m-extensions.md#data-source-path-format
    //Label = Extension.LoadString("DataSourceLabel")
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
