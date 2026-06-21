/**
 * Lightweight re-entrancy guard shared by WBS triggers and CPMEngine.
 * CPMEngine sets isRunning = true around its own DML so the WBS_Item /
 * WBS_Dependency triggers don't recurse while the schedule is being written.
 */
public class TriggerHelper {
    public static Boolean isRunning = false;
}
