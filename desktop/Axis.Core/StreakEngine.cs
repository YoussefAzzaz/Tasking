using System;
using System.Collections.Generic;
using System.Linq;

namespace Axis.Core;

public class StreakLog
{
    public string Date { get; set; } = "";
    public string Status { get; set; } = ""; // "done", "skipped"
}

public static class StreakEngine
{
    public static int CalculateStreak(string scheduleType, List<StreakLog> logs, string currentDateStr)
    {
        if (logs == null || logs.Count == 0) return 0;
        if (!DateTime.TryParse(currentDateStr, out var currentDate)) return 0;

        var logDict = logs.ToDictionary(l => l.Date, l => l.Status);

        int streak = 0;
        DateTime pointer = currentDate;
        
        // If today is logged as done, count it and move pointer to yesterday.
        // If today is skipped, we don't count it for streak, but it doesn't break it. Move pointer.
        // If today is missing, we don't break streak yet. Move pointer to yesterday.

        if (logDict.ContainsKey(pointer.ToString("yyyy-MM-dd")))
        {
            var status = logDict[pointer.ToString("yyyy-MM-dd")];
            if (status == "done") streak++;
        }
        else
        {
            // Today is missing, but maybe it's not due yet or they haven't done it.
            // If today was required and missed, the streak might technically be "at risk" but traditionally streak counts up to yesterday if today is unlogged.
        }

        pointer = pointer.AddDays(-1);

        while (true)
        {
            string dateKey = pointer.ToString("yyyy-MM-dd");
            
            bool isScheduled = true;
            if (scheduleType == "weekdays")
            {
                isScheduled = pointer.DayOfWeek != DayOfWeek.Saturday && pointer.DayOfWeek != DayOfWeek.Sunday;
            }

            if (logDict.ContainsKey(dateKey))
            {
                var status = logDict[dateKey];
                if (status == "done")
                {
                    streak++;
                }
                else if (status == "skipped")
                {
                    // Skipped doesn't add to streak, but doesn't break it
                }
                else
                {
                    // Unknown status breaks it
                    break;
                }
            }
            else
            {
                // Missing log
                if (isScheduled)
                {
                    // If it was a scheduled day and missing, streak breaks
                    break;
                }
                // If not scheduled, we can safely ignore the missing log and continue backwards
            }

            pointer = pointer.AddDays(-1);
        }

        return streak;
    }
}
