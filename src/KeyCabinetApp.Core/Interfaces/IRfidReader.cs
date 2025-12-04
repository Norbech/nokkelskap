namespace KeyCabinetApp.Core.Interfaces;

/// <summary>
/// Interface for handling RFID card input.
/// The RFID reader can behave as a keyboard wedge or HID device.
/// </summary>
public interface IRfidReader
{
    /// <summary>
    /// Event raised when an RFID card is scanned
    /// </summary>
    event EventHandler<string>? CardScanned;

    /// <summary>
    /// Starts listening for RFID card scans
    /// </summary>
    void StartListening();

    /// <summary>
    /// Stops listening for RFID card scans
    /// </summary>
    void StopListening();

    /// <summary>
    /// Indicates whether the reader is currently listening
    /// </summary>
    bool IsListening { get; }
}
