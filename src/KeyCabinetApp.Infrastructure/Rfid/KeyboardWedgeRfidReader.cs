using KeyCabinetApp.Core.Interfaces;
using Microsoft.Extensions.Logging;
using System.Text;
using System.Windows.Input;

namespace KeyCabinetApp.Infrastructure.Rfid;

/// <summary>
/// RFID reader implementation for keyboard wedge devices.
/// Captures keyboard input and detects RFID card scans.
/// 
/// Assumptions:
/// - RFID reader sends card data followed by Enter key
/// - Card data comes in quickly (within BufferTimeout)
/// - Normal keyboard input is slower and interleaved with pauses
/// </summary>
public class KeyboardWedgeRfidReader : IRfidReader
{
    private readonly ILogger<KeyboardWedgeRfidReader> _logger;
    private readonly StringBuilder _buffer = new StringBuilder();
    private readonly int _bufferTimeout = 100; // milliseconds
    private System.Timers.Timer? _bufferTimer;
    private bool _isListening;
    private DateTime _lastKeyPress = DateTime.MinValue;

    public event EventHandler<string>? CardScanned;

    public KeyboardWedgeRfidReader(ILogger<KeyboardWedgeRfidReader> logger)
    {
        _logger = logger;
        
        _bufferTimer = new System.Timers.Timer(_bufferTimeout);
        _bufferTimer.Elapsed += (s, e) => ProcessBuffer();
        _bufferTimer.AutoReset = false;
    }

    public bool IsListening => _isListening;

    public void StartListening()
    {
        if (_isListening)
            return;

        _isListening = true;
        _logger.LogInformation("RFID keyboard wedge reader started listening");
        
        // Note: Actual keyboard hook implementation would go here
        // For WPF, this is typically done at the Window level using PreviewTextInput
        // This class provides the logic; the UI layer will call ProcessKeyInput
    }

    public void StopListening()
    {
        if (!_isListening)
            return;

        _isListening = false;
        _buffer.Clear();
        _bufferTimer?.Stop();
        _logger.LogInformation("RFID keyboard wedge reader stopped listening");
    }

    /// <summary>
    /// Call this method from your WPF window's PreviewTextInput event
    /// </summary>
    public void ProcessKeyInput(string input)
    {
        if (!_isListening)
            return;

        var now = DateTime.UtcNow;
        var timeSinceLastKey = (now - _lastKeyPress).TotalMilliseconds;
        _lastKeyPress = now;

        // If there's a long gap, clear the buffer (new scan starting)
        if (timeSinceLastKey > _bufferTimeout && _buffer.Length > 0)
        {
            _buffer.Clear();
        }

        _buffer.Append(input);
        
        // Restart the timer
        _bufferTimer?.Stop();
        _bufferTimer?.Start();
    }

    /// <summary>
    /// Call this method from your WPF window's PreviewKeyDown event when Enter is pressed
    /// </summary>
    public void ProcessEnterKey()
    {
        if (!_isListening || _buffer.Length == 0)
            return;

        _bufferTimer?.Stop();
        ProcessBuffer();
    }

    private void ProcessBuffer()
    {
        if (_buffer.Length == 0)
            return;

        var cardData = _buffer.ToString().Trim();
        _buffer.Clear();

        // Validate that this looks like an RFID card
        // Typically RFID cards are numeric and have a minimum length
        if (cardData.Length >= 4 && IsValidRfidFormat(cardData))
        {
            _logger.LogInformation("RFID card detected: {CardId}", MaskCardData(cardData));
            CardScanned?.Invoke(this, cardData);
        }
        else
        {
            _logger.LogDebug("Ignored non-RFID input: {Length} characters", cardData.Length);
        }
    }

    private bool IsValidRfidFormat(string data)
    {
        // Customize this based on your RFID card format
        // Common formats:
        // - All numeric (e.g., "1234567890")
        // - Hex format (e.g., "A1B2C3D4")
        // - Mix of alphanumeric
        
        // For now, accept if it's at least 4 characters and contains alphanumeric
        return data.Length >= 4 && data.All(c => char.IsLetterOrDigit(c));
    }

    private string MaskCardData(string cardData)
    {
        if (cardData.Length <= 4)
            return "****";
        return cardData.Substring(0, 4) + new string('*', cardData.Length - 4);
    }
}
