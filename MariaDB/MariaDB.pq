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
        ConnectionString =
        [
            server = server,
            database = database
        ],
        // Get the current credential, and check what type of authentication we're using
        Credential = Extension.CurrentCredential(),
        CredentialConnectionString =
            if (Credential[AuthenticationKind]?) = "UsernamePassword" then 
                Record.Combine({ConnectionString,[ UID = Credential[Username], PWD = Credential[Password] ]})
            // unknown authentication kind - return an error
            else
                error "Username and Password credentials required.", 
        AdoDotNetDataSource = AdoDotNet.DataSource(Provider, CredentialConnectionString),
        // The first level of the navigation table will be the name of the database the user
        // passed in. Rather than repeating it again, we'll select it ({[Name = database]}) 
        // and access the next level of the navigation table.
        Database = AdoDotNetDataSource//{[Name = database]}[Data]
    in
        Database;

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
