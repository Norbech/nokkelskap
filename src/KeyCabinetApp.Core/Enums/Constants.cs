namespace KeyCabinetApp.Core.Enums;

public static class ActionTypes
{
    public const string OPEN = "OPEN";
    public const string REMOTE_OPEN = "REMOTE_OPEN";
    public const string FAILED_LOGIN = "FAILED_LOGIN";
    public const string SUCCESSFUL_LOGIN = "SUCCESSFUL_LOGIN";
    public const string CONFIG_CHANGE = "CONFIG_CHANGE";
    public const string USER_CREATED = "USER_CREATED";
    public const string USER_MODIFIED = "USER_MODIFIED";
    public const string KEY_CREATED = "KEY_CREATED";
    public const string KEY_MODIFIED = "KEY_MODIFIED";
    public const string SERIAL_ERROR = "SERIAL_ERROR";
}

public static class AuthMethods
{
    public const string RFID = "RFID";
    public const string PASSWORD = "PASSWORD";
    public const string REMOTE = "REMOTE";
    public const string NONE = "NONE";
}
