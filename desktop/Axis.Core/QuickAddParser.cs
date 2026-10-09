using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using System.Linq;

namespace Axis.Core;

public class QuickAddResult
{
    public string Title { get; set; } = "";
    public int? Priority { get; set; }
    public List<string> Tags { get; set; } = new();
    public string? Project { get; set; }
    
    [System.Text.Json.Serialization.JsonPropertyName("due_date")]
    public string? DueDate { get; set; }
    
    [System.Text.Json.Serialization.JsonPropertyName("due_time")]
    public string? DueTime { get; set; }
    
    public int? Estimate { get; set; }
    public string? Recurrence { get; set; }
}

public static class QuickAddParser
{
    public static QuickAddResult Parse(string text)
    {
        var result = new QuickAddResult();
        string remaining = text;

        // 1. Priority: p1, p2, p3
        var priorityMatch = Regex.Match(remaining, @"\b(p[1-3])\b", RegexOptions.IgnoreCase);
        if (priorityMatch.Success)
        {
            result.Priority = int.Parse(priorityMatch.Groups[1].Value.Substring(1));
            remaining = remaining.Replace(priorityMatch.Value, "");
        }

        // 2. Project: #name
        var projectMatch = Regex.Match(remaining, @"#(\w+)");
        if (projectMatch.Success)
        {
            result.Project = projectMatch.Groups[1].Value;
            remaining = remaining.Replace(projectMatch.Value, "");
        }

        // 3. Tags: @name
        var tagMatches = Regex.Matches(remaining, @"@(\w+)");
        foreach (Match match in tagMatches)
        {
            result.Tags.Add(match.Groups[1].Value);
            remaining = remaining.Replace(match.Value, "");
        }

        // 4. Estimate: 30m, 1h, 45m
        var estimateMatch = Regex.Match(remaining, @"\bfor (\d+)(m|h)\b", RegexOptions.IgnoreCase);
        if (!estimateMatch.Success)
        {
            estimateMatch = Regex.Match(remaining, @"\b(\d+)(m|h)\b", RegexOptions.IgnoreCase);
        }

        if (estimateMatch.Success)
        {
            int val = int.Parse(estimateMatch.Groups[1].Value);
            result.Estimate = estimateMatch.Groups[2].Value.ToLower() == "h" ? val * 60 : val;
            remaining = remaining.Replace(estimateMatch.Value, "");
        }

        // 5. Recurrence: every day, every 3 days ac
        var recMatch = Regex.Match(remaining, @"\bevery (day|(\d+) days?)( ac)?\b", RegexOptions.IgnoreCase);
        if (recMatch.Success)
        {
            string freq = "DAILY";
            string intervalPart = "";
            if (recMatch.Groups[2].Success)
            {
                intervalPart = $";INTERVAL={recMatch.Groups[2].Value}";
            }
            string completionPart = recMatch.Groups[3].Success && !string.IsNullOrWhiteSpace(recMatch.Groups[3].Value) ? ";COMPLETION=1" : "";
            result.Recurrence = $"RRULE:FREQ={freq}{intervalPart}{completionPart}";
            remaining = remaining.Replace(recMatch.Value, "");
        }

        // 6. Time: at 8pm, at 14:30, 18:00
        var timeMatch = Regex.Match(remaining, @"\bat (\d{1,2}(:\d{2})?(am|pm)?)\b", RegexOptions.IgnoreCase);
        if (!timeMatch.Success)
        {
            timeMatch = Regex.Match(remaining, @"\b(\d{1,2}:\d{2})\b", RegexOptions.IgnoreCase);
        }

        if (timeMatch.Success)
        {
            string timeStr = timeMatch.Groups[1].Value;
            if (DateTime.TryParse(timeStr, out var parsedTime))
            {
                result.DueTime = parsedTime.ToString("HH:mm");
            }
            remaining = remaining.Replace(timeMatch.Value, "");
        }

        // 7. Date: today, tmr, YYYY-MM-DD
        var dateMatch = Regex.Match(remaining, @"\b(today|tmr|\d{4}-\d{2}-\d{2})\b", RegexOptions.IgnoreCase);
        if (dateMatch.Success)
        {
            result.DueDate = dateMatch.Value.ToLower();
            remaining = remaining.Replace(dateMatch.Value, "");
        }

        // Cleanup
        result.Title = Regex.Replace(remaining, @"\s+", " ").Trim();

        // Default DueDate to today if time is specified but date is not
        if (result.DueTime != null && result.DueDate == null)
        {
            result.DueDate = "today";
        }

        return result;
    }
}
