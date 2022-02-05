using DatabaseSchemaReader.DataSchema;
using System;
using System.Collections.Generic;
using System.Text;

namespace DatabaseSchemaReader.CodeGen.GraphGL
{
    public static class GraphQLdBContext
    {

        //private static CodeWriterSettings _codeWriterSettings;// = new CodeWriterSettings { CodeTarget = CodeTarget.PocoGraphGL };
        private static bool _isUsingPluralized = false;
        public static string GetGraphGLUsingStatements(CodeWriterSettings codeWriterSettings)
        {
            _isUsingPluralized = (codeWriterSettings.Namer != null);
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("using " + codeWriterSettings.Namespace + ".Models;");
            sb.AppendLine("using Microsoft.EntityFrameworkCore;");
            sb.AppendLine("");
            sb.AppendLine("namespace " + codeWriterSettings.Namespace + ".Data");
            return sb.ToString();
        }
        public static string BeginClass()
        {
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine("    /// <summary>");
            sb.AppendLine("    /// The Entity Framework Database Context.");
            sb.AppendLine("    /// </summary>");
            sb.AppendLine("    public class AppDbContext : DbContext");
            sb.AppendLine("    {");
            sb.AppendLine("        public AppDbContext(DbContextOptions options) : base(options)");
            sb.AppendLine("        {");
            sb.AppendLine("        }");
            sb.AppendLine("");

            return sb.ToString();
        }
        public static string EndClass()
        {
            StringBuilder sb = new StringBuilder();         
            sb.AppendLine("    }");
            sb.AppendLine("}");
            return sb.ToString();
        }
        public static string AddContext(string table)
        {
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("        public DbSet<" + NameFixer.MakeSingular(table) + "> " + table + " { get; set; }");
            return sb.ToString();
        }

        public static string BeginReferentialIntegrity()
        {
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("");
            sb.AppendLine("		protected override void OnModelCreating(ModelBuilder modelBuilder)");
            sb.AppendLine("		{");
            return sb.ToString();
        }
        public static string EndReferentialIntegrity() => "		}";
        
        public static string AddDBReferentialIntegrity(DatabaseConstraint foreignKeyReverseGetLookUp)
        {
            StringBuilder sb = new StringBuilder();

            string primaryKey = foreignKeyReverseGetLookUp.RefersToConstraint;
            string table = NameFixer.MakeSingular(foreignKeyReverseGetLookUp.TableName);
            string reftable = NameFixer.MakeSingular(foreignKeyReverseGetLookUp.RefersToTable);
            string tablePlural = foreignKeyReverseGetLookUp.TableName;

            //Check if they have turned off Plrualised Naming
            if (_isUsingPluralized)
            {
                tablePlural = new PluralizingNamer().NameCollection(table);
            }

            sb.AppendLine("");
            sb.AppendLine("		    modelBuilder");
            sb.AppendLine("		    .Entity<" + reftable + "> ()");
            sb.AppendLine("		    .HasMany(p => p." + tablePlural + ")");
            sb.AppendLine("		    .WithOne(p => p." + reftable + "!)");
            sb.AppendLine("		    .HasForeignKey(p => p." + reftable + primaryKey + ");");
            sb.AppendLine("");
            sb.AppendLine("			modelBuilder");
            sb.AppendLine("		    .Entity<" + table + "> ()");
            sb.AppendLine("		    .HasOne(p => p." + reftable + ")");
            sb.AppendLine("		    .WithMany(p => p." + tablePlural + ")");
            sb.AppendLine("		    .HasForeignKey(p => p." + reftable + primaryKey + ");");
            sb.AppendLine("");
            return sb.ToString();
        }
    }
}
