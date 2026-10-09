using System;
using System.Collections.Generic;
using System.Linq;

namespace Axis.Core;

public class FilterTask
{
    public string Id { get; set; } = "";
    public int? Priority { get; set; }
    public List<string> Tags { get; set; } = new();
    public string? DueDate { get; set; }
}

public class FilterQuery
{
    public List<int>? Priority { get; set; }
    public List<string>? Tags { get; set; }
    public string? DueBefore { get; set; }
}

public static class FilterEngine
{
    public static bool Matches(FilterTask task, FilterQuery query)
    {
        if (query.Priority != null && query.Priority.Count > 0)
        {
            if (task.Priority == null || !query.Priority.Contains(task.Priority.Value))
                return false;
        }

        if (query.Tags != null && query.Tags.Count > 0)
        {
            if (task.Tags == null) return false;
            // Intersection must not be empty (or must contain all? Usually "contains any of" for tags in filters)
            // Let's do contains all for strict matching, or contains any? 
            // In typical productivity apps, selecting tags implies OR (contains any of selected) or AND.
            // Let's implement OR (contains any).
            if (!query.Tags.Any(t => task.Tags.Contains(t)))
                return false;
        }

        if (!string.IsNullOrWhiteSpace(query.DueBefore))
        {
            if (string.IsNullOrWhiteSpace(task.DueDate)) return false;
            
            if (string.Compare(task.DueDate, query.DueBefore) >= 0)
                return false;
        }

        return true;
    }
}
