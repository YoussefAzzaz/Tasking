using System;

namespace Axis.Core.Schema;

public abstract class BaseEntity
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string UserId { get; set; } = string.Empty;
    public string CreatedAt { get; set; } = DateTime.UtcNow.ToString("o");
    public string UpdatedAt { get; set; } = DateTime.UtcNow.ToString("o");
}

public class TaskEntity : BaseEntity
{
    public string Title { get; set; } = string.Empty;
    public string? Notes { get; set; }
    public string Status { get; set; } = "todo"; // todo, done, skipped
    public int Priority { get; set; } = 0;
    public string? ProjectId { get; set; }
    public string? Tags { get; set; }
    public string? DueDate { get; set; }
    public string? DueTime { get; set; }
    public int? EstimateMin { get; set; }
    public string? RecurrenceRule { get; set; }
    public string? RecurrenceMode { get; set; }
    public string? CompletedAt { get; set; }
}

public class ProjectEntity : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string Color { get; set; } = "#6366F1";
}

public class TagEntity : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string Color { get; set; } = "#6366F1";
}

public class HabitEntity : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string? Icon { get; set; } = "fitness";
    public string Color { get; set; } = "#10B981";
    public string? Kind { get; set; }
    public int TargetValue { get; set; } = 20;
    public string? Unit { get; set; }
    public string ScheduleType { get; set; } = "daily";
    public string? RemindTime { get; set; }
    public int SortOrder { get; set; } = 999;
}

public class HabitLogEntity : BaseEntity
{
    public string HabitId { get; set; } = string.Empty;
    public string LogDate { get; set; } = string.Empty;
    public string Status { get; set; } = "done";
    public double Value { get; set; } = 1.0;
    public string? Note { get; set; }
}

public class NoteEntity : BaseEntity
{
    public string Title { get; set; } = string.Empty;
    public string BodyMd { get; set; } = string.Empty;
    public int Pinned { get; set; } = 0;
    public string Category { get; set; } = "note";
    public string? Mood { get; set; }
    public string? Energy { get; set; }
}

public class FocusSessionEntity : BaseEntity
{
    public string? TaskId { get; set; }
    public string Kind { get; set; } = "pomodoro";
    public int PlannedMin { get; set; } = 25;
    public int ActualMin { get; set; } = 25;
    public string StartedAt { get; set; } = DateTime.UtcNow.ToString("o");
    public string? EndedAt { get; set; }
    public int Completed { get; set; } = 0;
    public int XpEarned { get; set; } = 0;
}

public class LogEntity : BaseEntity
{
    public string? TaskId { get; set; }
    public string EventType { get; set; } = string.Empty;
    public int XpEarned { get; set; } = 0;
    public string Timestamp { get; set; } = DateTime.UtcNow.ToString("o");
}
