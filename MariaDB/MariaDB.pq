// This file contains your Data Connector logic
section MariaDB;

DefaultPort = 3306;

// MariaDB Information Schema
INFORMATION_SCHEMA_TABLE_NAME = "TABLE_NAME";

[DataSource.Kind="MariaDB", Publish="MariaDB.Publish"]
shared MariaDB.Contents = Value.ReplaceType(MariaDBDatabaseImplOdbc, MariaDBDatabaseType);

// The server parameter has a full name to overcome the limitation of the Data Source Settings dialog in Power BI Desktop:
/*
Note: We currently recommend you do not include a Label for your data source if your function has required parameters, 
as users will not be able to distinguish between the different credentials they have entered. We are hoping to improve this 
in the future (i.e. allowing data connectors to display their own custom data source paths).
Source: https://github.com/Microsoft/DataConnectors/blob/master/docs/m-extensions.md#data-source-path-format
*/
MariaDBDatabaseType = type function (
    #"MariaDB Data Source" as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("GetData_Server_FieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("GetData_Server_FieldDescription"),        
        Documentation.SampleValues = {"servername:portnumber;databasename"}
    ]),
    optional database as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("GetData_Database_FieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("GetData_Database_FieldDescription"),
        Documentation.SampleValues = {"databasename"}
    ]))
    as table meta [
        Documentation.Name = Extension.LoadString("GetData_Title"),
        Documentation.LongDescription = "<p>Returns a navigation table.</p>
        <ul>
        <li>Without a <code>databasename</code>, returns a table of databases on the specified MariaDB server <code>servername</code>.
        <li>With a <code>databasename</code>, returns or a table of tables, views, and stored functions from the specified MariaDB database <code>databasename</code> on the server <code>servername</code>.
        </ul>
        
        <p><code>databasename</code> can be provided in either of the input parameters:</p>
        <ul>
        <li>In the <b>MariaDB Data Source</b> string after a semicolon. This approach allows using database-specific credentials. See details below.
        <li>As the optional <b>Database</b> parameter. This approach allows using same credentials for all databases on the specified server <code>servername</code>.
        </ul>
        <p>The <b>MariaDB Data Source</b> string uniquely identifies a data source in Power BI and allows using different credentials for each data source.
        Credentials for a data source are configured in Power BI <i>Data source settings</i> screen. 
        MariaDB Power BI connector supports Basic authentication per server or per database.
        E.g. it is possible to connect with different credentials to databases residing on the same MariaDB server.</p>",
        Documentation.Examples = {[
            Description = "Returns a table of MariaDB tables, views, and stored functions from the MariaDB database <code>databasename</code> on server <code>servername</code>.",
            Code = "MariaDB.Contents(""servername"", ""databasename"")",
            Result = "#table({""Name"", ""Description"", ""Data"", ""Kind""}, {
       {""airlines"", null, #table(...), ""Table""},
       {""airports"", null, #table(...), ""Table""},
       {""flights"", null, #table(...), ""Table""}
       })"
        ],[
            Description = Text.Format("Returns a table of databases on the specified MariaDB server using the default port #{0} to connect. Equivalent to <code>MariaDB.Contents(""servername:#{0}"")</code>.", {DefaultPort}),
            Code = "MariaDB.Contents(""servername"")",
            Result = "#table({""Name"", ""Description"", ""Data"", ""Kind""}, {
       {""mysql"", null, #table(...), ""Database""},
       {""flights"", null, #table(...), ""Database""}
       })"
        ],[
            Description = "Returns a table of databases on the specified MariaDB server <code>servername</code> using the provided port number <code>portnumber</code> to connect.",
            Code = "MariaDB.Contents(""servername:portnumber"")",
            Result = "#table({""Name"", ""Description"", ""Data"", ""Kind""}, {
       {""mysql"", null, #table(...), ""Database""},
       {""flights"", null, #table(...), ""Database""}
       })"
        ],[
            Description = "Returns a table of MariaDB tables, views, and stored functions from the MariaDB database <code>databasename</code> on server <code>servername</code>. 
            The result is similar to <code>MariaDB.Contents(""servername"", ""databasename"")</code>, but the string <code>servername;databasename</code> identifies a unique data source and allows using dedicated credentials for the database <code>databasename</code>.",
            Code = "MariaDB.Contents(""servername;databasename"")",
            Result = "#table({""Name"", ""Description"", ""Data"", ""Kind""}, {
       {""airlines"", null, #table(...), ""Table""},
       {""airports"", null, #table(...), ""Table""},
       {""flights"", null, #table(...), ""Table""}
       })"
        ]}
    ];

MariaDBDatabaseImplOdbc = (server as text, optional db as text) as table =>
    let
        Address = GetAddress(server),
        ServerHost = Address[Host],
        ServerPort = Address[Port],
        ServerDatabase = Address[Database],
        database = if db <> null and db <> "" then db else ServerDatabase,
        // Get the current credential, and check what type of authentication we're using
        Credential = Extension.CurrentCredential(),
        CredentialRecord = if (Credential[AuthenticationKind]?) = "UsernamePassword" then 
                [ UID = Credential[Username], PWD = Credential[Password] ]
            // unknown authentication kind - return an error
            else
                error "Username and Password credentials required.", 
        CredentialConnectionString = Record.Combine({
            [Driver = ODBCDriver, Server = ServerHost, Port = ServerPort],
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
            server = json[#"MariaDB Data Source"]
        in
            { "MariaDB.Contents", server},
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

GetAddress = (MariaDBServer as text) as record =>
    let
        list = Text.Split(MariaDBServer, ";"),
        server = List.First(list),
        database = if List.Count(list) > 1 then List.Last(List.FirstN(list, 2)) else null,
        Address = Uri.Parts("http://" & server),
        BadServer = Address[Host] = "" or Address[Scheme] <> "http" or Address[Path] <> "/" or Address[Query] <> [] or Address[Fragment] <> ""
            or Address[UserName] <> "" or Address[Password] <> "",
        Port = if Address[Port] = 80 and not Text.EndsWith(server, ":80") then 
                DefaultPort 
            else Address[Port],
        Host = Address[Host],
        Result = [Host=Host, Port=Port, Database=database]
    in
        if BadServer then 
            error "Invalid server name"
        else Result;

// ODBC helpers
ODBCDriver = "MariaDB ODBC 3.1 Driver";
