using System;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Linq;
using Xunit;
using Axis.Core;

namespace Axis.Core.Tests;

public class Sprint5Tests
{
    private class RecVector
    {
        public string rrule { get; set; } = "";
        public string mode { get; set; } = "";
        public string current_due_date { get; set; } = "";
        public string completion_date { get; set; } = "";
        public string expected_next_due { get; set; } = "";
    }

    private class RecFile
    {
        public System.Collections.Generic.List<RecVector> vectors { get; set; } = new();
    }

    private class SchedVector
    {
        public SchedInput input { get; set; } = new();
        public SchedExpected expected { get; set; } = new();
    }

    private class SchedInput
    {
        public string date { get; set; } = "";
        public string now { get; set; } = "";
        public string work_start { get; set; } = "";
        public string work_end { get; set; } = "";
        public int buffer_min { get; set; }
        public int default_estimate_min { get; set; }
        public System.Collections.Generic.List<BusyJson> busy { get; set; } = new();
        public System.Collections.Generic.List<TaskJson> tasks { get; set; } = new();
    }

    private class BusyJson { public string start { get; set; } = ""; public string end { get; set; } = ""; }
    private class TaskJson { public string id { get; set; } = ""; public int? estimate_min { get; set; } }

    private class SchedExpected
    {
        public System.Collections.Generic.List<ProposedSlot> proposed { get; set; } = new();
        public System.Collections.Generic.List<string> unplaced { get; set; } = new();
        public int available_min { get; set; }
        public int planned_min { get; set; }
    }

    private class SchedFile
    {
        public System.Collections.Generic.List<SchedVector> vectors { get; set; } = new();
    }

    [Fact]
    public void TestRecurrence()
    {
        string path = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "../../../../../contract/recurrence.json");
        var data = JsonSerializer.Deserialize<RecFile>(File.ReadAllText(path));
        Assert.NotNull(data);

        foreach (var v in data.vectors)
        {
            var next = RecurrenceEngine.CalculateNextDueDate(v.rrule, v.mode, v.current_due_date, v.completion_date);
            Assert.Equal(v.expected_next_due, next);
        }
    }

    [Fact]
    public void TestScheduler()
    {
        string path = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "../../../../../contract/scheduler.json");
        var data = JsonSerializer.Deserialize<SchedFile>(File.ReadAllText(path));
        Assert.NotNull(data);

        foreach (var v in data.vectors)
        {
            var busy = v.input.busy.Select(b => new BusyBlock { Start = TimeSpan.Parse(b.start), End = TimeSpan.Parse(b.end) }).ToList();
            var tasks = v.input.tasks.Select(t => new SchedulableTask { Id = t.id, EstimateMin = t.estimate_min }).ToList();

            var result = AutoScheduler.Schedule(
                v.input.date, v.input.now, v.input.work_start, v.input.work_end,
                v.input.buffer_min, v.input.default_estimate_min, busy, tasks
            );

            Assert.Equal(v.expected.available_min, result.AvailableMin);
            Assert.Equal(v.expected.planned_min, result.PlannedMin);
            Assert.Equal(v.expected.unplaced, result.Unplaced);
            Assert.Equal(v.expected.proposed.Count, result.Proposed.Count);
            for (int i = 0; i < result.Proposed.Count; i++)
            {
                Assert.Equal(v.expected.proposed[i].Id, result.Proposed[i].Id);
                Assert.Equal(v.expected.proposed[i].Start, result.Proposed[i].Start);
                Assert.Equal(v.expected.proposed[i].End, result.Proposed[i].End);
            }
        }
    }
}
