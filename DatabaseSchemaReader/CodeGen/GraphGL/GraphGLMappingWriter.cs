using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using DatabaseSchemaReader.DataSchema;

namespace DatabaseSchemaReader.CodeGen.GraphGL
{
    class GraphGLMappingWriter
    {
        private readonly DatabaseTable _table;
        private readonly CodeWriterSettings _codeWriterSettings;
        private readonly MappingNamer _mappingNamer;
        private readonly ClassBuilder _cb;
        private DatabaseTable _inheritanceTable;
        private List<DatabaseConstraint> _foreignKeyResolverLookUps;

        public GraphGLMappingWriter(DatabaseTable table, CodeWriterSettings codeWriterSettings, MappingNamer mappingNamer, List<DatabaseConstraint> foreignKeyResolverLookUps)
        {
            if (table == null) throw new ArgumentNullException("table");
            if (mappingNamer == null) throw new ArgumentNullException("mappingNamer");

            _codeWriterSettings = codeWriterSettings;
            _mappingNamer = mappingNamer;
            _foreignKeyResolverLookUps = foreignKeyResolverLookUps;
            _table = table;
            _cb = new ClassBuilder();
        }

        /// <summary>
        /// Gets the name of the mapping class.
        /// </summary>
        /// <value>
        /// The name of the mapping class.
        /// </value>
        public string MappingClassName { get; private set; }

        public string Write()
        {
            // Name of the single C# file that holds all the dB table object classes 
            MappingClassName = _mappingNamer.NameMappingClass(_table.NetName);

            _cb.AppendLine("using System.Linq;");
            _cb.AppendLine("using " + _codeWriterSettings.Namespace + ".Data;");
            _cb.AppendLine("using " + _codeWriterSettings.Namespace + ".Models;");
            _cb.AppendLine("using HotChocolate;");
            _cb.AppendLine("using HotChocolate.Types;");

            // Generate this GraphQL Models: Input, Payload, Mappings, Descriptors and Resolvers
            using (_cb.BeginNest("namespace " + _codeWriterSettings.Namespace + "." + _table.NetName + "s"))
            {
                AddType();
                //The following records and classes only have a dependancy on "using HotChocolate.Types;"
                //I've combined them into one file for project management (as the dBs will typically have a large number of tables to warrent a code generator)
                //_cb.AppendLine("using HotChocolate.Types;");
                AddInput();
                AddInputType();
                AddPayload();
                AddPayloadType();
            }
            return _cb.ToString();
        }

        private void AddType()
        {
            using (_cb.BeginNest("public class " + _table.NetName + "Type: ObjectType<" + _table.NetName + ">", "Record mapping GraphQL type to " + _table.Name + " table"))
            {
                using (_cb.BeginNest("protected override void Configure(IObjectTypeDescriptor<" + _table.NetName + "> descriptor)", _table.Name + " Constructor"))
                {
                    _cb.AppendLine(@"descriptor.Description(""Represents any executable " + _table.NetName + @"."");");
                    _cb.AppendLine("");
                    WritePayloadTypeDescriptors();

                    WritePayloadForeignTableDescriptors();
                }

                AddResolvers();
            }
            _cb.AppendLine("");
        }

        private void WritePayloadForeignTableDescriptors()
        {
            // EXAMPLE OUTPUT
            //descriptor
            //.Field(c => c.Platform)
            //.ResolveWith<Resolvers>(c => c.GetPlatform(default!, default!))
            //.UseDbContext<AppDbContext>()
            //.Description("This is the platform to which the command belongs.");

            char letter = _table.Name[0];

            foreach (var fKey in _table.ForeignKeys)
            {
                if (Equals(fKey.ReferencedTable(_table.DatabaseSchema), _inheritanceTable))
                    continue;

                string fKeyTableName = NameFixer.MakeSingular(fKey.RefersToTable);

                StringBuilder sb = new StringBuilder();
                sb.Append("descriptor.Field(");
                sb.Append(letter);
                sb.Append(" => ");
                sb.Append(letter);
                sb.Append(".");
                sb.Append(fKeyTableName);
                sb.Append(")");
                sb.Append(".ResolveWith<Resolvers>(");
                sb.Append(letter);
                sb.Append(" => ");
                sb.Append(letter);
                sb.Append(".Get");
                sb.Append(fKeyTableName);
                sb.Append("(default!, default!)).UseDbContext<AppDbContext>()");
                sb.Append(@".Description(""This is the " + fKeyTableName + " to which the " + _table.NetName + @" relates."");");
                _cb.AppendLine(sb.ToString());
            }
        }

        private void AddResolvers()
        {
            string tableNamePascalCase = NameFixer.ToCamelCase(_table.NetName);
            using (_cb.BeginNest("public class Resolvers", "Resolvers"))
            {
                // EXAMPLE OUTPUT
                //public IQueryable<Command> GetCommands(Platform platform, [ScopedService] AppDbContext context)
                //{
                //    return context.Commands.Where(p => p.PlatformId == platform.Id);
                //}

                var reverseLookUps = _foreignKeyResolverLookUps.Where(s => s.RefersToTable == _table.Name);
                foreach (var lookup in reverseLookUps)
                {
                    string reverseTable = NameFixer.MakeSingular(lookup.TableName);
                    string table = NameFixer.MakeSingular(lookup.RefersToTable);
                    using (_cb.BeginNest("public IQueryable<" + reverseTable + "> Get" + lookup.TableName + "(" + table + " " + NameFixer.ToCamelCase(table) + ", [ScopedService] AppDbContext context)"))
                    {
                        char letter = table[0];
                        StringBuilder sb = new StringBuilder();
                        sb.Append("return context.");
                        sb.Append(lookup.TableName);
                        sb.Append(".Where(");
                        sb.Append(letter);
                        sb.Append(" => ");
                        sb.Append(letter);
                        sb.Append(".");
                        sb.Append(table);
                        sb.Append(lookup.RefersToConstraint); //The Primary Key column name - typically "Id"
                        sb.Append(" == ");
                        sb.Append(NameFixer.ToCamelCase(table));
                        sb.Append(".");
                        sb.Append(lookup.RefersToConstraint);
                        sb.AppendLine(");");

                        _cb.AppendLine(sb.ToString());
                    }

                }

                foreach (var fKey in _table.ForeignKeys)
                {
                    if (Equals(fKey.ReferencedTable(_table.DatabaseSchema), _inheritanceTable))
                        continue;

                    string fKeyTableName = NameFixer.MakeSingular(fKey.RefersToTable);

                    using (_cb.BeginNest("public " + fKeyTableName + " Get" + fKeyTableName + "(" + _table.NetName + " " + tableNamePascalCase + ", [ScopedService] AppDbContext context)", "Resolvers"))
                    {
                        _cb.AppendLine(" return context." + fKey.RefersToTable + ".FirstOrDefault(p => p.Id == " + tableNamePascalCase + "." + fKey.Columns[0] + ");");
                    }
                }
            }
        }

        private void AddInput()
        {
            _cb.AppendXmlSummary("Record mapping GraphQL input to " + _table.Name + " table");
            _cb.AppendLine("public record Add" + _table.NetName + "Input(" + WriteParameterOfArgs() + ");");
            _cb.AppendLine("");
        }

        private void AddInputType()
        {
            using (_cb.BeginNest("public class Add" + _table.NetName + "InputType: InputObjectType<Add" + _table.NetName + "Input>", "Class mapping GraphQL input type to " + _table.Name + " table"))
            {
                using (_cb.BeginNest("protected override void Configure(IInputObjectTypeDescriptor<Add" + _table.NetName + "Input> descriptor)", "Input Type Constructor"))
                {
                    _cb.AppendLine(@"descriptor.Description(""Represents the input type for the " + _table.NetName + @"."");");
                    _cb.AppendLine("");
                    WriteInputTypeDescriptors();

                    _cb.AppendLine("base.Configure(descriptor);");
                }
            }
            _cb.AppendLine("");
        }

        private void AddPayload()
        {
            _cb.AppendXmlSummary("Record mapping GraphQL input payload to " + _table.Name + " table");
            _cb.AppendLine("public record Add" + _table.NetName + "Payload(" + _table.NetName + " " + NameFixer.ToCamelCase(_table.NetName) + ");");
            _cb.AppendLine("");
        }

        private void AddPayloadType()
        {
            using (_cb.BeginNest("public class Add" + _table.NetName + "PayloadType: ObjectType<Add" + _table.NetName + "Payload>", "Class mapping GraphQL payload type to " + _table.Name + " table"))
            {
                using (_cb.BeginNest("protected override void Configure(IObjectTypeDescriptor<Add" + _table.NetName + "Payload> descriptor)", "Payload Type Constructor"))
                {
                    _cb.AppendLine(@"descriptor.Description(""Represents the payload to return for an added " + _table.NetName + @"."");");
                    _cb.AppendLine("");
                    WritePayloadTypeDescriptor();

                    _cb.AppendLine("base.Configure(descriptor);");
                }
            }
            _cb.AppendLine("");
        }

        private string WriteParameterOfArgs()
        {
            //string howTo, string commandLine, 
            StringBuilder sb = new StringBuilder();
            DataTypeWriter dataTypeWriter = new DataTypeWriter();
            foreach (var column in _table.Columns)
            {
                if (column.IsPrimaryKey) continue;
                sb.Append(dataTypeWriter.Write(column));
                sb.Append(" ");
                sb.Append(column.Name);
                sb.Append(", ");
            }
            return sb.ToString().TrimEnd(new char[] {',',' '});
        }

        private void WriteInputTypeDescriptors()
        {
            // EXAMPLE OUTPUT
            //descriptor
            //    .Field(c => c.HowTo)
            //    .Description("Represents the how-to for the command.");

            char letter = _table.Name[0];
            foreach (var column in _table.Columns)
            {
                if (column.IsPrimaryKey) continue;
                StringBuilder sb = new StringBuilder();
                sb.Append("descriptor.Field(");
                sb.Append(letter);
                sb.Append(" => ");
                sb.Append(letter);
                sb.Append(".");
                sb.Append(column.Name);
                sb.Append(")");
                sb.AppendLine(@".Description(""Represents the " + column.Name + " for the " + _table.NetName + @"."");");
                _cb.AppendLine(sb.ToString());
            }
        }

        private void WritePayloadTypeDescriptors()
        {
            // EXAMPLE OUTPUT
            //descriptor
            // .Field(c => c.Id)
            // .Description("Represents the added command.");

            char letter = _table.Name[0];
            foreach (var column in _table.Columns)
            {
                StringBuilder sb = new StringBuilder();
                sb.Append("descriptor.Field(");
                sb.Append(letter);
                sb.Append(" => ");
                sb.Append(letter);
                sb.Append(".");
                sb.Append(column.Name);
                sb.Append(")");
                sb.AppendLine(@".Description(""Represents the " + column.Name + " of the added " + _table.NetName + @"."");");
                _cb.AppendLine(sb.ToString());
            }
        }

        private void WritePayloadTypeDescriptor()
        {
            // EXAMPLE OUTPUT
            //descriptor
            // .Field(c => c.command)
            // .Description("Represents the added command.");

            char letter = _table.NetName[0];
            StringBuilder sb = new StringBuilder();
            sb.Append("descriptor.Field(");
            sb.Append(letter);
            sb.Append(" => ");
            sb.Append(letter);
            sb.Append(".");
            sb.Append(NameFixer.ToCamelCase(_table.NetName));
            sb.Append(")");
            sb.AppendLine(@".Description(""Represents the added " + _table.NetName + @"."");");
            _cb.AppendLine(sb.ToString());            
        }

        
        private void AddPrimaryKey()
        {
            if (_table.PrimaryKey == null || _table.PrimaryKey.Columns.Count == 0)
            {
                if (_table is DatabaseView)
                {
                    AddCompositePrimaryKeyForView();
                    return;
                }
                _cb.AppendLine("//TODO- you MUST add a primary key!");
                return;
            }
            if (_table.HasCompositeKey)
            {
                AddCompositePrimaryKey();
                return;
            }

            var idColumn = _table.PrimaryKeyColumn;

            if (_inheritanceTable != null)
            {
                _cb.AppendLine("KeyColumn(\"" + idColumn.Name + "\");");
                return;
            }

            var sb = new StringBuilder();
            sb.AppendFormat(CultureInfo.InvariantCulture, "Id(x => x.{0})", idColumn.NetName);
            if (idColumn.Name != idColumn.NetName)
            {
                sb.AppendFormat(CultureInfo.InvariantCulture, ".Column(\"{0}\")", idColumn.Name);
            }
            if (idColumn.IsAutoNumber)
            {
                sb.AppendFormat(CultureInfo.InvariantCulture, ".GeneratedBy.Identity()");
                //other GeneratedBy values (Guid, Assigned) are left to defaults
            }
            //one to one with generator foreign
            if (idColumn.IsForeignKey)
            {
                //primary key is also a foreign key
                var fk = _table.ForeignKeys.FirstOrDefault(x => x.RefersToTable == idColumn.ForeignKeyTableName);
                if (fk != null)
                {
                    var propertyName = _codeWriterSettings.Namer.ForeignKeyName(_table, fk);
                    sb.AppendFormat(CultureInfo.InvariantCulture, ".GeneratedBy.Foreign(\"{0}\")", propertyName);
                }
            }

            sb.Append(";");
            _cb.AppendLine(sb.ToString());
        }

        private void AddCompositePrimaryKeyForView()
        {
            var sb = new StringBuilder();
            sb.Append("CompositeId()");
            //we map ALL columns as the key.
            foreach (var column in _table.Columns)
            {
                sb.AppendFormat(CultureInfo.InvariantCulture,
                                ".KeyProperty(x => x.{0}, \"{1}\")",
                                column.NetName,
                                column.Name);
            }
            sb.Append(";");
            _cb.AppendLine(sb.ToString());
            _cb.AppendLine("ReadOnly();");
        }

            private void AddCompositePrimaryKey()
        {
            if (_inheritanceTable != null)
            {
                foreach (var col in _table.PrimaryKey.Columns)
                {
                    _cb.AppendLine("KeyColumn(\"" + col + "\");");
                }
                return;
            }

            var sb = new StringBuilder();
            //our convention is always to generate a key class with property name Key
            sb.Append("CompositeId(x => x.Key)");

            // KL: Ensuring composite primary key is generated in order of define key and not
            // simply the order of the tables.
            foreach (var col in _table.PrimaryKey.Columns)
            {
                DatabaseColumn column = _table.FindColumn(col);

                const string keyType = "KeyProperty";
                var name = _codeWriterSettings.Namer.PrimaryKeyName(column);
                // KL: Mapping the foreign keys separately. KeyReference was causing issues.
                //var keyType = "KeyReference";
                //if (column.ForeignKeyTable == null)
                //{
                //    keyType = "KeyProperty";
                //}
                sb.AppendFormat(CultureInfo.InvariantCulture,
                                                ".{0}(x => x.{1}, \"{2}\")",
                                                keyType,
                                                name,
                                                column.Name);
            }
            sb.Append(";");
            _cb.AppendLine(sb.ToString());
        }


        private void WriteColumns()
        {
            //map the columns
            // KL: Only write empty columns. Then, foreign keys.
            foreach (var column in _table.Columns.Where(c => !c.IsPrimaryKey && !c.IsForeignKey))
            {
                WriteColumn(column);
            }

            // KL: Writing foreign key separately
            foreach (var fKey in _table.ForeignKeys)
            {
                if (Equals(fKey.ReferencedTable(_table.DatabaseSchema), _inheritanceTable))
                    continue;

                WriteForeignKey(fKey);
            }
        }


        private void WriteColumn(DatabaseColumn column)
        {
            //if (column.IsForeignKey)
            //{
            //    // KL: Needed to write foreign keys in their own step in order to support composite
            //    //WriteForeignKey(column);
            //    return;
            //}

            var propertyName = column.NetName;
            var sb = new StringBuilder();
            sb.AppendFormat(CultureInfo.InvariantCulture, "Map(x => x.{0})", propertyName);
            if (propertyName != column.Name)
            {
                sb.AppendFormat(CultureInfo.InvariantCulture, ".Column(\"{0}\")", column.Name);
            }

            if (column.IsComputed)
            {
                sb.Append(".ReadOnly().Generated.Always()");
            }
            else
            {

                var dt = column.DataType;
                if (dt != null)
                {
                    //nvarchar(max) may be -1
                    if (dt.IsString && column.Length > 0 && column.Length < 1073741823)
                    {
                        sb.AppendFormat(CultureInfo.InvariantCulture, ".Length({0})", column.Length.GetValueOrDefault());
                    }
                }

                if (!column.Nullable)
                {
                    sb.Append(".Not.Nullable()");
                }
            }

            sb.Append(";");
            _cb.AppendLine(sb.ToString());
        }

        //private void WriteForeignKey(DatabaseColumn column)
        //{
        //    var propertyName = column.NetName;
        //    var sb = new StringBuilder();
        //    sb.AppendFormat(CultureInfo.InvariantCulture, "References(x => x.{0})", propertyName);
        //    sb.AppendFormat(CultureInfo.InvariantCulture, ".Column(\"{0}\")", column.Name);
        //    //bad idea unless you expect the database to be inconsistent
        //    //sb.Append(".NotFound.Ignore()");
        //    //could look up cascade rule here
        //    sb.Append(";");
        //    _cb.AppendLine(sb.ToString());
        //}

        /// <summary>
        /// KL: Writes the foreign key an also supports composite foreign keys.
        /// </summary>
        /// <param name="foreignKey">The foreign key.</param>
        private void WriteForeignKey(DatabaseConstraint foreignKey)
        {
            var propertyName = _codeWriterSettings.Namer.ForeignKeyName(_table, foreignKey);
            if (string.IsNullOrEmpty(propertyName)) return;

            var isPrimaryKey = false;
            if (_table.PrimaryKey != null)
            {
                //the primary key is also this foreign key
                isPrimaryKey = _table.PrimaryKey.Columns.SequenceEqual(foreignKey.Columns);
            }
            //1:1 shared primary key 
            if (isPrimaryKey)
            {
                _cb.AppendFormat("HasOne(x => x.{0}).ForeignKey(\"{1}\");",
                    propertyName, foreignKey.Name);
                return;
            }

            var cols = foreignKey.Columns.Select(x => string.Format("\"{0}\"", x)).ToArray();

            var sb = new StringBuilder();
            sb.AppendFormat(CultureInfo.InvariantCulture, "References(x => x.{0})", propertyName);
            if (cols.Length > 1)
            {
                sb.AppendFormat(CultureInfo.InvariantCulture, ".Columns(new string[] {{ {0} }});", String.Join(", ", cols));
            }
            else
            {
                sb.AppendFormat(CultureInfo.InvariantCulture, ".Column(\"{0}\");", foreignKey.Columns.FirstOrDefault());
            }
            _cb.AppendLine(sb.ToString());
        }

        private void WriteForeignKeyCollection(DatabaseTable foreignKeyChild)
        {
            var foreignKeyTable = foreignKeyChild.Name;
            var childClass = foreignKeyChild.NetName;
            var fks = _table.InverseForeignKeys(foreignKeyChild);
            if (!fks.Any()) return; //corruption in our database

            _cb.AppendFormat("//Foreign key to {0} ({1})", foreignKeyTable, childClass);
            if (_table.IsSharedPrimaryKey(foreignKeyChild))
            {
                var fk = fks.First();
                if (fk.Columns.Count == 1)
                    _cb.AppendFormat("HasOne(x => x.{0}).Constrained();", childClass);
                //_cb.AppendFormat("References(x => x.{0}).Column(\"{1}\").ForeignKey(\"{2}\");",
                //      childClass, fkColumn, foreignKey.Name);
                //TODO composite keys
                return;
            }

            foreach (var fk in fks)
            {
                var sb = new StringBuilder();
                var propertyName = _codeWriterSettings.Namer.ForeignKeyCollectionName(_table.Name, foreignKeyChild, fk);
                var fkColumn = fk.Columns.FirstOrDefault();

                sb.AppendFormat(CultureInfo.InvariantCulture, "HasMany(x => x.{0})", propertyName);
                //defaults to x_id

                // KL: Only use .KeyColumn() if the foreign key is not composite
                if (fk.Columns.Count == 1)
                {
                    sb.AppendFormat(CultureInfo.InvariantCulture, ".KeyColumn(\"{0}\")", fkColumn);
                }
                // If composite key, generate .KeyColumns(...) with array of keys
                else
                {
                    var cols = fk.Columns.Select(x => string.Format("\"{0}\"", x)).ToArray();
                    sb.AppendFormat(CultureInfo.InvariantCulture, ".KeyColumns.Add(new string[] {{ {0} }})",
                                    String.Join(", ", cols));
                }
                sb.Append(".Inverse()");
                sb.AppendFormat(CultureInfo.InvariantCulture, ".ForeignKeyConstraintName(\"{0}\")", fk.Name);

                sb.Append(";");
                _cb.AppendLine(sb.ToString());
            }
        }
    }
}
