using KeyCabinetApp.Core.Interfaces;
using Microsoft.Extensions.Logging;
using System.IO.Ports;
using System.Text.Json;

namespace KeyCabinetApp.Infrastructure.Serial;

/// <summary>
/// Configuration for RS485 serial communication
/// </summary>
public class SerialConfig
{
    public string PortName { get; set; } = "COM3";
    public int BaudRate { get; set; } = 9600;
    public int DataBits { get; set; } = 8;
    public Parity Parity { get; set; } = Parity.None;
    public StopBits StopBits { get; set; } = StopBits.One;
    public int ReadTimeout { get; set; } = 1000;
    public int WriteTimeout { get; set; } = 1000;

    /// <summary>
    /// When enabled, logs TX/RX frames (hex) to a trace file.
    /// Useful for reverse-engineering / debugging controller protocols.
    /// </summary>
    public bool TraceEnabled { get; set; } = false;

    /// <summary>
    /// Optional path to write trace lines to. If not set, defaults to
    /// %APPDATA%\KeyCabinetApp\serial-trace.log
    /// </summary>
    public string? TraceFilePath { get; set; }
    
    /// <summary>
    /// Command templates for each slot. Key = SlotId, Value = hex bytes to send
    /// Example: { "1": "01 05 00 01 FF 00", "2": "01 05 00 02 FF 00" }
    /// </summary>
    public Dictionary<int, string> SlotCommands { get; set; } = new();
    
    /// <summary>
    /// Optional: Status request commands for each slot
    /// </summary>
    public Dictionary<int, string> StatusCommands { get; set; } = new();
}

/// <summary>
/// RS485 serial communication driver for key cabinet controller
/// Configurable to support different protocols
/// </summary>
public class Rs485Communication : ISerialCommunication, IDisposable
{
    private readonly SerialConfig _config;
    private readonly ILogger<Rs485Communication> _logger;
    private SerialPort? _serialPort;
    private readonly object _lock = new object();
    private readonly string _defaultTraceFilePath;

    public Rs485Communication(SerialConfig config, ILogger<Rs485Communication> logger)
    {
        _config = config;
        _logger = logger;
        _defaultTraceFilePath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "KeyCabinetApp",
            "serial-trace.log");
    }

    public bool IsConnected => _serialPort?.IsOpen ?? false;

    public async Task<bool> ConnectAsync()
    {
        return await Task.Run(() =>
        {
            try
            {
                lock (_lock)
                {
                    if (_serialPort?.IsOpen == true)
                    {
                        _logger.LogInformation("Serial port already connected");
                        return true;
                    }

                    _serialPort = new SerialPort
                    {
                        PortName = _config.PortName,
                        BaudRate = _config.BaudRate,
                        DataBits = _config.DataBits,
                        Parity = _config.Parity,
                        StopBits = _config.StopBits,
                        ReadTimeout = _config.ReadTimeout,
                        WriteTimeout = _config.WriteTimeout,
                        Handshake = Handshake.None,
                        DtrEnable = false,
                        RtsEnable = false
                    };

                    _serialPort.Open();
                    _logger.LogInformation("Serial port {PortName} opened successfully", _config.PortName);
                    return true;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to open serial port {PortName}", _config.PortName);
                return false;
            }
        });
    }

    public void Disconnect()
    {
        try
        {
            lock (_lock)
            {
                if (_serialPort?.IsOpen == true)
                {
                    _serialPort.Close();
                    _logger.LogInformation("Serial port {PortName} closed", _config.PortName);
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error closing serial port");
        }
    }

    public async Task<bool> OpenSlotAsync(int slotId)
    {
        try
        {
            if (!_config.SlotCommands.TryGetValue(slotId, out var commandHex))
            {
                _logger.LogWarning("No command configured for slot {SlotId}", slotId);
                return false;
            }

            var commandBytes = ParseHexString(commandHex);
            if (commandBytes == null || commandBytes.Length == 0)
            {
                _logger.LogError("Invalid command hex for slot {SlotId}: {CommandHex}", slotId, commandHex);
                return false;
            }

            var response = await SendCommandAsync(commandBytes);

            if (response == null)
            {
                // SendCommandAsync uses null to signal failures/timeouts.
                return false;
            }

            if (response.Length > 0)
            {
                _logger.LogDebug("Received response for slot {SlotId}: {Response}", slotId, BitConverter.ToString(response));
            }
            else
            {
                _logger.LogWarning("No response received for slot {SlotId} (bytes written OK)", slotId);
            }

            // Assume success if we managed to write (and optionally got a response).
            // Add protocol-specific validation here once the expected RX frames are known.
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error opening slot {SlotId}", slotId);
            return false;
        }
    }

    public async Task<string?> GetSlotStatusAsync(int slotId)
    {
        try
        {
            if (!_config.StatusCommands.TryGetValue(slotId, out var commandHex))
            {
                _logger.LogDebug("No status command configured for slot {SlotId}", slotId);
                return null;
            }

            var commandBytes = ParseHexString(commandHex);
            if (commandBytes == null || commandBytes.Length == 0)
            {
                return null;
            }

            var response = await SendCommandAsync(commandBytes);
            
            if (response != null && response.Length > 0)
            {
                return BitConverter.ToString(response);
            }

            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting status for slot {SlotId}", slotId);
            return null;
        }
    }

    public async Task<byte[]?> SendCommandAsync(byte[] command)
    {
        return await Task.Run(() =>
        {
            try
            {
                lock (_lock)
                {
                    if (_serialPort == null || !_serialPort.IsOpen)
                    {
                        _logger.LogError("Serial port is not open");
                        return null;
                    }

                    _logger.LogDebug("Sending command: {Command}", BitConverter.ToString(command));
                    TraceFrame("TX", command);

                    // Clear buffers
                    _serialPort.DiscardInBuffer();
                    _serialPort.DiscardOutBuffer();

                    // Send command
                    _serialPort.Write(command, 0, command.Length);

                    // Wait a bit for response
                    Thread.Sleep(100);

                    // Try to read response
                    if (_serialPort.BytesToRead > 0)
                    {
                        byte[] response = new byte[_serialPort.BytesToRead];
                        _serialPort.Read(response, 0, response.Length);
                        TraceFrame("RX", response);
                        return response;
                    }

                    TraceFrame("RX", Array.Empty<byte>());
                    return Array.Empty<byte>();
                }
            }
            catch (TimeoutException ex)
            {
                _logger.LogWarning(ex, "Timeout sending command");
                return null;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error sending command");
                return null;
            }
        });
    }

    private void TraceFrame(string direction, byte[] bytes)
    {
        if (!_config.TraceEnabled)
        {
            return;
        }

        try
        {
            var tracePath = string.IsNullOrWhiteSpace(_config.TraceFilePath)
                ? _defaultTraceFilePath
                : _config.TraceFilePath;

            var directory = Path.GetDirectoryName(tracePath);
            if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }

            var hex = bytes.Length == 0 ? "" : BitConverter.ToString(bytes).Replace("-", " ");
            var line = $"{DateTime.UtcNow:O} {direction} {hex}{Environment.NewLine}";
            File.AppendAllText(tracePath, line);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to write serial trace");
        }
    }

    /// <summary>
    /// Parses hex string like "01 05 00 01 FF 00" into byte array
    /// </summary>
    private byte[]? ParseHexString(string hex)
    {
        try
        {
            var hexValues = hex.Split(new[] { ' ', '-', ':', ',' }, StringSplitOptions.RemoveEmptyEntries);
            var bytes = new byte[hexValues.Length];
            
            for (int i = 0; i < hexValues.Length; i++)
            {
                bytes[i] = Convert.ToByte(hexValues[i], 16);
            }
            
            return bytes;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error parsing hex string: {Hex}", hex);
            return null;
        }
    }

    public void Dispose()
    {
        Disconnect();
        _serialPort?.Dispose();
    }
}
