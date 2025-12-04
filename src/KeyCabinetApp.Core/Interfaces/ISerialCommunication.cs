namespace KeyCabinetApp.Core.Interfaces;

/// <summary>
/// Interface for RS485 serial communication with the key cabinet controller board.
/// Implementation is configurable to support different protocols.
/// </summary>
public interface ISerialCommunication
{
    /// <summary>
    /// Opens the serial port connection
    /// </summary>
    Task<bool> ConnectAsync();

    /// <summary>
    /// Closes the serial port connection
    /// </summary>
    void Disconnect();

    /// <summary>
    /// Checks if the serial port is currently connected
    /// </summary>
    bool IsConnected { get; }

    /// <summary>
    /// Sends a command to open a specific key slot
    /// </summary>
    /// <param name="slotId">The slot ID to open</param>
    /// <returns>True if command was sent successfully</returns>
    Task<bool> OpenSlotAsync(int slotId);

    /// <summary>
    /// Requests status for a specific slot (if supported by hardware)
    /// </summary>
    /// <param name="slotId">The slot ID to query</param>
    /// <returns>Status string or null if not supported</returns>
    Task<string?> GetSlotStatusAsync(int slotId);

    /// <summary>
    /// Sends a raw command to the controller
    /// </summary>
    /// <param name="command">Byte array of the command</param>
    /// <returns>Response bytes if any</returns>
    Task<byte[]?> SendCommandAsync(byte[] command);
}
