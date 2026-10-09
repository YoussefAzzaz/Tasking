using System;
using System.IO;
using System.Text.Json;
using System.Linq;
using Xunit;
using Axis.Core;

namespace Axis.Core.Tests;

public class QuickAddParserTests
{
    private class VectorData
    {
        public string input { get; set; } = "";
        public QuickAddResult expected { get; set; } = new();
    }

    private class VectorsFile
    {
        public string now { get; set; } = "";
        public string timezone { get; set; } = "";
        public System.Collections.Generic.List<VectorData> vectors { get; set; } = new();
    }

    [Fact]
    public void VerifyAgainstContract()
    {
        string path = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "../../../../../contract/quickadd.json");
        string json = File.ReadAllText(path);
        
        var data = JsonSerializer.Deserialize<VectorsFile>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
        Assert.NotNull(data);

        foreach (var vector in data.vectors)
        {
            var parsed = QuickAddParser.Parse(vector.input);
            
            Assert.Equal(vector.expected.Title, parsed.Title);
            Assert.Equal(vector.expected.Priority, parsed.Priority);
            Assert.Equal(vector.expected.Project, parsed.Project);
            Assert.True(vector.expected.DueDate == parsed.DueDate, $"Mismatch on DueDate for '{vector.input}'. Expected: {vector.expected.DueDate}, Actual: {parsed.DueDate}");
            Assert.True(vector.expected.DueTime == parsed.DueTime, $"Mismatch on DueTime for '{vector.input}'. Expected: {vector.expected.DueTime}, Actual: {parsed.DueTime}");
            Assert.Equal(vector.expected.Estimate, parsed.Estimate);
            Assert.Equal(vector.expected.Recurrence, parsed.Recurrence);
            
            // Compare tags
            Assert.Equal(vector.expected.Tags.OrderBy(t => t), parsed.Tags.OrderBy(t => t));
        }
    }
}
