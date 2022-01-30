# dB Schema Reader Poco .Net Gen

A simple, cross-database facade over .Net 2.0 DbProviderFactories to read database metadata.

Any ADO provider can be read  (SqlServer, SqlServer CE 4, MySQL, SQLite, System.Data.OracleClient, ODP, Devart, PostgreSql, DB2...) into a single standard model. For .net Core, we support SqlServer, SqlServer CE 4, SQLite, PostgreSql, MySQL and Oracle (even if the database clients  are not yet available in .net Core, we are ready for them).


## Purpose

* Database schema read from most ADO providers
* Simple .net code generation:
  * Generate POCO classes for tables, and NHibernate or EF Code First mapping files
  * Generate simple ADO classes to use stored procedures
* Simple sql generation:
  * Generate table DDL (and translate to another SQL syntax, eg SqlServer to Oracle or SQLite)
  * Generate CRUD stored procedures (for SqlServer, Oracle, MySQL, DB2)
* Copy a database schema and data from any provider (SqlServer, Oracle etc) to a new SQLite database (and, with limitations, to SqlServer CE 4)
* Compare two schemas to generate a migration script
* Simple cross-database migrations generator


## History

https://github.com/martinjw/dbschemareader (originally https://dbschemareader.codeplex.com/)


## How it works

The Application reads database schemas by fetching all the Drivers installed on your Machine in the Form1 Constructor method:

        public Form1()
        {
            InitializeComponent();

            var TheDriverDataTable = DbProviderFactories.GetFactoryClasses();


TheDriverDataTable contains all the drivers on your machine. If you're missing one, for example the PostGres driver you can add it to your app.config or web.config:

  <system.data>
    <DbProviderFactories>
      <add name="Npgsql Data Provider" invariant="Npgsql" description=".Net Data Provider for PostgreSQL" type="Npgsql.NpgsqlFactory, Npgsql, Culture=neutral, PublicKeyToken=5d8b90d52f46fda7"/>
    </DbProviderFactories>
  </system.data>

The driver will now be listed in the DropDownList in the Application, for it to work you need the .Net Data Provider for PostgreSQL DLL in your bin folder. You can install the DLL dependancy via the NuGet package: Npgsql

After specifying the Driver and confirming the Connection String is correct, click the "Read Schema" button. If there are errors its due to missing drivers or incorrect connection string.

Once the Schema is read click the "Code Gen" button to generate a range of Plain Old Class Objects (NHibernate, EF, Ria, etc).



