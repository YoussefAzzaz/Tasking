namespace Axis.Core.Schema;

/// <summary>
/// PowerSync client-side schema definition for C# (.NET) desktop app.
/// Matches the SQLite schema and Postgres public schema with strict user_id multi-tenant isolation.
/// </summary>
public static class PowerSyncSchema
{
    public const string TasksTable = "tasks";
    public const string ProjectsTable = "projects";
    public const string TagsTable = "tags";
    public const string HabitsTable = "habits";
    public const string HabitLogsTable = "habit_logs";
    public const string NotesTable = "notes";
    public const string FocusSessionsTable = "focus_sessions";
    public const string LogsTable = "logs";

    public static readonly string[] SyncedTables = new[]
    {
        TasksTable,
        ProjectsTable,
        TagsTable,
        HabitsTable,
        HabitLogsTable,
        NotesTable,
        FocusSessionsTable,
        LogsTable
    };
}
