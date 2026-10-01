using System;
using System.IO;
using System.Text.Json;
using Xunit;
using Axis.Core;

namespace Axis.Core.Tests;

public class IdGeneratorTests
{
    private class VectorData
    {
        public string name { get; set; } = "";
        public string uuidv5 { get; set; } = "";
    }

    private class VectorsFile
    {
        public string Namespace { get; set; } = "";
        public System.Collections.Generic.Dictionary<string, VectorData> Vectors { get; set; } = new();
    }

    [Fact]
    public void VerifyAgainstContract()
    {
        // Adjust the path according to test execution directory (usually bin/Debug/net...)
        string path = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "../../../../../contract/ids.json");
        string json = File.ReadAllText(path);
        
        var data = JsonSerializer.Deserialize<VectorsFile>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
        Assert.NotNull(data);

        Assert.Equal(IdGenerator.AxisNamespace.ToString(), data.Namespace);

        foreach (var kvp in data.Vectors)
        {
            var vector = kvp.Value;
            var generated = IdGenerator.GenerateDeterministicId(vector.name);
            Assert.Equal(vector.uuidv5, generated.ToString());
        }

        // Test specific convenience methods
        Assert.Equal(data.Vectors["user_settings"].uuidv5, IdGenerator.GetUserSettingsId("user123"));
        Assert.Equal(data.Vectors["daily_plans"].uuidv5, IdGenerator.GetDailyPlanId("2026-10-01"));
        Assert.Equal(data.Vectors["journal_entries"].uuidv5, IdGenerator.GetJournalEntryId("2026-10-01"));
        Assert.Equal(data.Vectors["habit_logs"].uuidv5, IdGenerator.GetHabitLogId("habit123", "2026-10-01"));
        Assert.Equal(data.Vectors["xp_events"].uuidv5, IdGenerator.GetXpEventId("event456"));
        Assert.Equal(data.Vectors["badge_unlocks"].uuidv5, IdGenerator.GetBadgeUnlockId("first_task", "user123"));
        Assert.Equal(data.Vectors["recurring_task_instances"].uuidv5, IdGenerator.GetRecurringTaskInstanceId("123", "2026-10-01"));
    }
}
