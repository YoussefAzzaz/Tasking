using System;
using System.Collections.Generic;
using System.Linq;

namespace Axis.Core;

public class BusyBlock
{
    public TimeSpan Start { get; set; }
    public TimeSpan End { get; set; }
}

public class SchedulableTask
{
    public string Id { get; set; } = "";
    public int? EstimateMin { get; set; }
}

public class ProposedSlot
{
    [System.Text.Json.Serialization.JsonPropertyName("id")]
    public string Id { get; set; } = "";
    
    [System.Text.Json.Serialization.JsonPropertyName("start")]
    public string Start { get; set; } = "";
    
    [System.Text.Json.Serialization.JsonPropertyName("end")]
    public string End { get; set; } = "";
}

public class SchedulerResult
{
    public List<ProposedSlot> Proposed { get; set; } = new();
    public List<string> Unplaced { get; set; } = new();
    public int AvailableMin { get; set; }
    public int PlannedMin { get; set; }
}

public static class AutoScheduler
{
    public static SchedulerResult Schedule(
        string date, 
        string nowTime, 
        string workStart, 
        string workEnd, 
        int bufferMin, 
        int defaultEstimateMin, 
        List<BusyBlock> busy, 
        List<SchedulableTask> tasks)
    {
        var result = new SchedulerResult();
        
        var start = TimeSpan.Parse(workStart);
        var end = TimeSpan.Parse(workEnd);
        var now = TimeSpan.Parse(nowTime);

        // If today, don't schedule before 'now'
        if (date == DateTime.UtcNow.ToString("yyyy-MM-dd") && now > start)
        {
            start = now;
        }

        var sortedBusy = busy.OrderBy(b => b.Start).ToList();

        // Calculate total available minutes
        int totalBusy = 0;
        foreach (var b in sortedBusy)
        {
            var bStart = b.Start < start ? start : b.Start;
            var bEnd = b.End > end ? end : b.End;
            if (bEnd > bStart)
            {
                totalBusy += (int)(bEnd - bStart).TotalMinutes;
            }
        }
        
        int totalWindow = (end > start) ? (int)(end - start).TotalMinutes : 0;
        result.AvailableMin = totalWindow - totalBusy;

        TimeSpan currentPointer = start;
        int busyIndex = 0;

        foreach (var task in tasks)
        {
            int duration = task.EstimateMin ?? defaultEstimateMin;
            bool placed = false;

            while (currentPointer + TimeSpan.FromMinutes(duration) <= end)
            {
                // Find next busy block that intersects or is ahead
                while (busyIndex < sortedBusy.Count && sortedBusy[busyIndex].End <= currentPointer)
                {
                    busyIndex++;
                }

                if (busyIndex < sortedBusy.Count && sortedBusy[busyIndex].Start < currentPointer + TimeSpan.FromMinutes(duration))
                {
                    // Collision with busy block
                    currentPointer = sortedBusy[busyIndex].End;
                    // Add buffer after busy? In simple greedy, just jump to End.
                }
                else
                {
                    // We can place it!
                    var slotEnd = currentPointer + TimeSpan.FromMinutes(duration);
                    result.Proposed.Add(new ProposedSlot
                    {
                        Id = task.Id,
                        Start = currentPointer.ToString(@"hh\:mm"),
                        End = slotEnd.ToString(@"hh\:mm")
                    });
                    
                    result.PlannedMin += duration;
                    currentPointer = slotEnd + TimeSpan.FromMinutes(bufferMin);
                    placed = true;
                    break;
                }
            }

            if (!placed)
            {
                result.Unplaced.Add(task.Id);
            }
        }

        return result;
    }
}
