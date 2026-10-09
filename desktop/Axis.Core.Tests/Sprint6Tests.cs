using System;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Linq;
using Xunit;
using Axis.Core;
using System.Collections.Generic;

namespace Axis.Core.Tests;

public class Sprint6Tests
{
    private class FilterVector
    {
        public FilterTask task { get; set; } = new();
        public FilterQuery query { get; set; } = new();
        public bool expected_match { get; set; }
    }
    private class FilterFile { public List<FilterVector> vectors { get; set; } = new(); }

    private class StreakVector
    {
        public string schedule_type { get; set; } = "";
        public string? schedule_val { get; set; }
        public List<StreakLog> logs { get; set; } = new();
        public string current_date { get; set; } = "";
        public int expected_streak { get; set; }
    }
    private class StreakFile { public List<StreakVector> vectors { get; set; } = new(); }

    private class XpVector
    {
        public int? current_xp { get; set; }
        public int? expected_level { get; set; }
        public int? daily_tasks_done { get; set; }
        public int? daily_focus_sessions { get; set; }
        public int? expected_tasks_counted { get; set; }
        public int? expected_focus_counted { get; set; }
    }
    private class XpFile { public List<XpVector> vectors { get; set; } = new(); }


    [Fact]
    public void TestFilters()
    {
        string path = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "../../../../../contract/filters.json");
        var data = JsonSerializer.Deserialize<FilterFile>(File.ReadAllText(path), new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
        Assert.NotNull(data);

        foreach (var v in data.vectors)
        {
            var match = FilterEngine.Matches(v.task, v.query);
            Assert.Equal(v.expected_match, match);
        }
    }

    [Fact]
    public void TestStreaks()
    {
        string path = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "../../../../../contract/streaks.json");
        var data = JsonSerializer.Deserialize<StreakFile>(File.ReadAllText(path), new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
        Assert.NotNull(data);

        foreach (var v in data.vectors)
        {
            var streak = StreakEngine.CalculateStreak(v.schedule_type, v.logs, v.current_date);
            Assert.Equal(v.expected_streak, streak);
        }
    }

    [Fact]
    public void TestXp()
    {
        string path = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "../../../../../contract/xp.json");
        var data = JsonSerializer.Deserialize<XpFile>(File.ReadAllText(path), new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
        Assert.NotNull(data);

        foreach (var v in data.vectors)
        {
            if (v.current_xp.HasValue)
            {
                Assert.Equal(v.expected_level, GamificationEngine.CalculateLevel(v.current_xp.Value));
            }

            if (v.daily_tasks_done.HasValue)
            {
                Assert.Equal(v.expected_tasks_counted, GamificationEngine.ApplyDailyTaskCap(v.daily_tasks_done.Value));
            }

            if (v.daily_focus_sessions.HasValue)
            {
                Assert.Equal(v.expected_focus_counted, GamificationEngine.ApplyDailyFocusCap(v.daily_focus_sessions.Value));
            }
        }
    }
}
