using System;

namespace Axis.Core;

public static class GamificationEngine
{
    public const int DailyTaskCap = 25;
    public const int DailyFocusEventCap = 120;

    public static int CalculateLevel(int xp)
    {
        if (xp < 0) return 1;
        double n = (50.0 + Math.Sqrt(2500.0 + 200.0 * xp)) / 100.0;
        return (int)Math.Floor(n);
    }

    public static int XpToReachLevel(int level)
    {
        if (level < 1) return 0;
        return 50 * level * (level - 1);
    }

    public static int ApplyDailyTaskCap(int count)
    {
        return Math.Min(count, DailyTaskCap);
    }

    public static int ApplyDailyFocusCap(int count)
    {
        return Math.Min(count, DailyFocusEventCap);
    }
}
