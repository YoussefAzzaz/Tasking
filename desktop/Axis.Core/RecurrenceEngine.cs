using System;
using System.Collections.Generic;
using System.Linq;

namespace Axis.Core;

public static class RecurrenceEngine
{
    public static string CalculateNextDueDate(string rrule, string mode, string currentDueDateStr, string completionDateStr)
    {
        if (string.IsNullOrWhiteSpace(rrule) || !rrule.StartsWith("RRULE:"))
            return currentDueDateStr;

        if (!DateTime.TryParse(currentDueDateStr, out var currentDueDate)) return currentDueDateStr;
        if (!DateTime.TryParse(completionDateStr, out var completionDate)) return currentDueDateStr;

        // Parse RRULE
        var parts = rrule.Substring(6).Split(';');
        var rules = new Dictionary<string, string>();
        foreach (var p in parts)
        {
            var kv = p.Split('=');
            if (kv.Length == 2) rules[kv[0]] = kv[1];
        }

        string freq = rules.ContainsKey("FREQ") ? rules["FREQ"] : "DAILY";
        int interval = rules.ContainsKey("INTERVAL") ? int.Parse(rules["INTERVAL"]) : 1;

        DateTime baseDate = mode == "after_completion" ? completionDate : currentDueDate;
        DateTime nextDate = baseDate;

        if (freq == "DAILY")
        {
            nextDate = baseDate.AddDays(interval);
        }
        else if (freq == "WEEKLY")
        {
            if (rules.ContainsKey("BYDAY"))
            {
                var days = rules["BYDAY"].Split(',');
                var dayMap = new Dictionary<string, DayOfWeek> {
                    {"MO", DayOfWeek.Monday}, {"TU", DayOfWeek.Tuesday}, {"WE", DayOfWeek.Wednesday},
                    {"TH", DayOfWeek.Thursday}, {"FR", DayOfWeek.Friday}, {"SA", DayOfWeek.Saturday}, {"SU", DayOfWeek.Sunday}
                };
                
                var targetDays = days.Select(d => dayMap[d]).ToList();
                
                // Find next day in the targetDays
                for (int i = 1; i <= 7 * interval; i++)
                {
                    var candidate = baseDate.AddDays(i);
                    if (targetDays.Contains(candidate.DayOfWeek))
                    {
                        // If we are stepping into a new week, we might need to handle interval > 1
                        // But for simplicity of this subset, we assume interval applies to weeks, 
                        // and we just find the next day in the list.
                        nextDate = candidate;
                        break;
                    }
                }
            }
            else
            {
                nextDate = baseDate.AddDays(7 * interval);
            }
        }
        else if (freq == "MONTHLY")
        {
            if (rules.ContainsKey("BYMONTHDAY"))
            {
                int day = int.Parse(rules["BYMONTHDAY"]);
                nextDate = baseDate.AddMonths(interval);
                
                int daysInMonth = DateTime.DaysInMonth(nextDate.Year, nextDate.Month);
                nextDate = new DateTime(nextDate.Year, nextDate.Month, Math.Min(day, daysInMonth));
            }
            else
            {
                nextDate = baseDate.AddMonths(interval);
            }
        }

        // Fixed mode catch-up
        if (mode == "fixed" && nextDate <= completionDate)
        {
            // If the next date is still in the past or today (meaning we missed several),
            // calculate the proper future date based on the interval pattern.
            // A simple iterative approach for the subset:
            while (nextDate <= completionDate)
            {
                var nStr = CalculateNextDueDate(rrule, mode, nextDate.ToString("yyyy-MM-dd"), nextDate.ToString("yyyy-MM-dd"));
                if (nStr == currentDueDateStr) break;
                nextDate = DateTime.Parse(nStr);
            }
        }

        return nextDate.ToString("yyyy-MM-dd");
    }
}
