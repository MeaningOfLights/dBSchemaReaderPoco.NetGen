
# dB Schema Reader Poco .Net Gen

A cross-database GraphQL HotChocolate POCO generator.

Any ADO provider can be read  (SqlServer, SqlServer CE 4, MySQL, SQLite, System.Data.OracleClient, ODP, Devart, PostgreSql, DB2...) into a single standard model. 

For .net Core, we support SqlServer, SqlServer CE 4, SQLite, PostgreSql, MySQL and Oracle (even if the database clients are not yet available in .net Core, we are ready for them).


## Purpose

* To read database schema's' from most ADO providers
* Simple .net code generation:
  * Generate POCO classes GraphQL - NEW!
  * Generate POCO classes for tables, and NHibernate or EF Code First mapping files - OLD!
  * Generate simple ADO classes to use stored procedures - OLD!
* Simple sql generation:
  * Generate table DDL (and translate to another SQL syntax, eg SqlServer to Oracle or SQLite)
  * Generate CRUD stored procedures (for SqlServer, Oracle, MySQL, DB2)
* Copy a database schema and data from any provider (SqlServer, Oracle etc) to a new SQLite database (and, with limitations, to SqlServer CE 4)
* Compare two schemas to generate a migration script
* Simple cross-database migrations generator


## Credits

CREDIT - Original https://dbschemareader.codeplex.com/

CREDIT - DB SCHEMA READER:
https://github.com/martinjw/dbschemareader

CREDIT - GRAPHQL Poco.Net Gen:
https://github.com/MeaningOfLights/dBSchemaReaderPoco.NetGen


## History

1.05	Support got GraphQL attributes [UseProjections], [Parent] and Decimal Types with annotations 
1.04	Support for Many-To-Many relationships
1.03	Validation of Database Schema for GraphQL POCO Models
1.02	Completed GraphQL POCO Model generation with Foreign Keys, Resolvers, Descriptors & etc
1.01	Build in support for GraphQL POCO Models	


## Not yet supported

Denormalised, meta-meta, inheritance and NoSQL databases.

## TO DO

* Add Update functionaity
* Resolvers are mapped using Froeign Keys, it would be better using the actual column names. Sometime they're not named the same!
* Related to the above TODO, support for Primary Keys other than "Id". See ""BakersYchange"" sample for the problems non-Id PK columns cause: DatabaseSchemaViewer > TestDatabases
* Support for StoredProcedures & Functions
* Support Enum DataTypes (in PostGres)
* Command Line usage to run on Mac & Linux 

## Designing the DataBase

The tool contains a button Validate Schema for GraphQL - run this and it will tell you all the issues by detecting the following:

- It's a HotChocolate convention that database table names to be plural. 

- It's a HotChocolate convention that column names are singular. 

- When using special database types such as Database ENUMS they may not translate to a .Net DataType. In this case you see in the output these unknown types are object datatypes.
Its critical that you go and fix all these up manually, in the case of ENUMS you would manually declare them in the codebase.

- Always use "Id" as the column name for every primary key. For foreign key columns, always use the foreign key table name and the primary key Id. 
- For example a Employee table with a foriegn key "OccupationId" is easily seen to map to the "Occupation" table and its primary key "Id".

- Apart from ""Id"" avoid column names less than 3 letters, aim for a word or two.

- Avoid the same column name like 'SharedAppId' in multple tables, instead use the Table-Id naming relationship syntax convention. 
- *You can't' use polymorphic foreign keys (joins across multiple tables) you'll need to do a ReferenceTable-Table-Id naming convention. 

- Sometimes it''s not possible to honor the Table-Id convention. A common scenario is having columns named 'CreatedBy' and 'ModifiedBy' and that's fine
unless they're foreign keys to the User table. If it was one then the field should be called 'UserId' instead of 'CreatedBy', however we can't have
two columns named UserId. Therefore in this case we keep 'CreatedBy' and 'ModifiedBy' and manually tweak the codebase to suit.

- It's also important to choose column names wisely as they make up the variable names in the codebase. Use CamelCase column names as underscores 
don't look good. This means that when working with Postgres databases all table and column names need to be enclosed with "double quotes".

- Avoid Acronyms like DOB, use Dob or DateOfBirth instead.

- You can use Single Table Inheritance https://www.martinfowler.com/eaaCatalog/singleTableInheritance.html (eg a single table to hold all the 
settings/values of multiple small tables: Id|ParentCodeId|CodeId|Setting|Value|Description|IsDeleted). 

- NOT VALIDATED YET - Polymorphic Foreign Keys are WIP and manual tweaks to the code are required.


Avoid Table Names that are HotChocolate Keywords:

- Location
- FieldCoordinate
- NameString
- SchemaCoordinate

Avoid Column Names:

- Setting


### Instructions with handy tips!


## CODING CHANGES
You may need to delete the bin/obj folders in the\dBSchemaReaderPoco.NetGen\DatabaseSchemaReader & Viewer project before seeing your changes take affect.


## COMPILING

BUILD DatabaseSchemaReader.csproj - that will fail.

Then run the project and ignore the one error:

Severity	Code	Description	Project	File	Line	Suppression State
Error	MSB3644	The reference assemblies for .NETFramework,Version=v4.5 were not found. To resolve this, install the Developer Pack
(SDK/Targeting Pack) for this framework version or retarget your application.


## RUNNING

After compiling and running it will load a browser and show a 404 page..

While its running manually visit both these pages:
https://localhost:5001/ui/voyager and https://localhost:5001/graphql/

If you haven't created a Database yet the scripts are located here:
https://github.com/MeaningOfLights/dBSchemaReaderPoco.NetGen/tree/master/DatabaseSchemaViewer/TestDatabases



# After Generating the GraphQL DataBase POCOs

After generating, open the solution in Visual Studio and make sure the Nuget Packages are referenced.

Go through all the errors, typically pressing Ctrl + Space over any red squiggle lines and fixing any issues.