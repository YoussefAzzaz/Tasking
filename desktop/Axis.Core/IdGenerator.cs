using System;
using System.Security.Cryptography;
using System.Text;

namespace Axis.Core;

public static class IdGenerator
{
    // The Axis application-wide namespace for deterministic IDs
    public static readonly Guid AxisNamespace = Guid.Parse("3f2b8c1e-6d4a-4e7b-9a52-1c8d0f7e4b11");

    /// <summary>
    /// Generates a deterministic UUIDv5 (SHA-1 based) from the Axis namespace and a given name.
    /// </summary>
    public static Guid GenerateDeterministicId(string name)
    {
        return GenerateDeterministicId(AxisNamespace, name);
    }

    public static Guid GenerateDeterministicId(Guid namespaceId, string name)
    {
        if (name == null) throw new ArgumentNullException(nameof(name));

        // Convert the namespace UUID to network byte order (big-endian)
        byte[] namespaceBytes = namespaceId.ToByteArray();
        SwapByteOrder(namespaceBytes);

        // Convert the name to UTF-8 bytes
        byte[] nameBytes = Encoding.UTF8.GetBytes(name);

        // Compute the SHA-1 hash
        using var algorithm = SHA1.Create();
        algorithm.TransformBlock(namespaceBytes, 0, namespaceBytes.Length, null, 0);
        algorithm.TransformFinalBlock(nameBytes, 0, nameBytes.Length);
        byte[] hash = algorithm.Hash!;

        // The UUID uses the first 16 bytes of the hash
        byte[] newGuid = new byte[16];
        Array.Copy(hash, 0, newGuid, 0, 16);

        // Set the 4 most significant bits (bits 12 through 15) of the time_hi_and_version field to the appropriate 4-bit version number (5)
        newGuid[6] = (byte)((newGuid[6] & 0x0F) | (5 << 4));

        // Set the 2 most significant bits (bits 6 and 7) of the clock_seq_hi_and_reserved to zero and one, respectively
        newGuid[8] = (byte)((newGuid[8] & 0x3F) | 0x80);

        // Convert the resulting UUID to local byte order (for .NET Guid)
        SwapByteOrder(newGuid);

        return new Guid(newGuid);
    }

    // Swaps the byte order for the first three fields (time_low, time_mid, time_hi_and_version)
    // between big-endian (network order used by standard UUIDs) and little-endian (used by .NET Guid).
    private static void SwapByteOrder(byte[] guid)
    {
        SwapBytes(guid, 0, 3);
        SwapBytes(guid, 1, 2);
        SwapBytes(guid, 4, 5);
        SwapBytes(guid, 6, 7);
    }

    private static void SwapBytes(byte[] guid, int left, int right)
    {
        byte temp = guid[left];
        guid[left] = guid[right];
        guid[right] = temp;
    }

    public static string GetUserSettingsId(string userId) => GenerateDeterministicId($"settings_{userId}").ToString();
    public static string GetDailyPlanId(string date) => GenerateDeterministicId($"plan_{date}").ToString();
    public static string GetJournalEntryId(string date) => GenerateDeterministicId($"journal_{date}").ToString();
    public static string GetHabitLogId(string habitId, string date) => GenerateDeterministicId($"habitlog_{habitId}_{date}").ToString();
    public static string GetXpEventId(string eventId) => GenerateDeterministicId($"xp_{eventId}").ToString();
    public static string GetBadgeUnlockId(string badgeId, string userId) => GenerateDeterministicId($"badge_{badgeId}_{userId}").ToString();
    public static string GetRecurringTaskInstanceId(string taskId, string date) => GenerateDeterministicId($"task_{taskId}_{date}").ToString();
}
