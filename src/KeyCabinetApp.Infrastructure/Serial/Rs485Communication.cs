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
    /// <summary>
    /// When enabled, the agent will try to find a working COM port if PortName is missing.
    /// Useful when Windows assigns different COM numbers across machines.
    /// </summary>
    public bool AutoDetectPort { get; set; } = true;
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

    private const int Rev2FrameLength = 8;

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
            lock (_lock)
            {
                if (_serialPort?.IsOpen == true)
                {
                    _logger.LogInformation("Serial port already connected");
                    return true;
                }

                var availablePorts = Array.Empty<string>();
                try
                {
                    availablePorts = SerialPort.GetPortNames();
                }
                catch
                {
                    // Ignore enumeration issues.
                }

                static string NormalizePort(string p) => (p ?? string.Empty).Trim();

                var configuredPort = NormalizePort(_config.PortName);
                var configuredIsAuto = string.IsNullOrWhiteSpace(configuredPort) ||
                                       configuredPort.Equals("AUTO", StringComparison.OrdinalIgnoreCase);

                var candidatePorts = new List<string>();
                if (!configuredIsAuto)
                {
                    candidatePorts.Add(configuredPort);
                }
                if (_config.AutoDetectPort || configuredIsAuto)
                {
                    foreach (var p in availablePorts)
                    {
                        var np = NormalizePort(p);
                        if (string.IsNullOrWhiteSpace(np)) continue;
                        if (candidatePorts.Any(x => x.Equals(np, StringComparison.OrdinalIgnoreCase))) continue;
                        candidatePorts.Add(np);
                    }

                    // Some Windows machines can show USB serial devices in Device Manager while
                    // SerialPort.GetPortNames() returns none (driver not loaded / device error).
                    // In that case, probing common COM numbers may still find a usable port.
                    if (availablePorts.Length == 0)
                    {
                        for (var i = 1; i <= 20; i++)
                        {
                            var probe = $"COM{i}";
                            if (candidatePorts.Any(x => x.Equals(probe, StringComparison.OrdinalIgnoreCase))) continue;
                            candidatePorts.Add(probe);
                        }
                    }
                }

                if (candidatePorts.Count == 0)
                {
                    _logger.LogWarning(
                        "No serial ports detected on this machine (SerialPort.GetPortNames returned none). " +
                        "If you expect a USB-RS485 adapter, check drivers/Device Manager (often CH340/FTDI driver)." );
                    return false;
                }

                Exception? lastException = null;
                foreach (var port in candidatePorts)
                {
                    try
                    {
                        _serialPort?.Dispose();
                        _serialPort = new SerialPort
                        {
                            PortName = port,
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

                        if (!configuredIsAuto && !port.Equals(configuredPort, StringComparison.OrdinalIgnoreCase))
                        {
                            _logger.LogWarning(
                                "Configured serial port {ConfiguredPort} was not usable; using {DetectedPort} instead",
                                configuredPort,
                                port);
                        }

                        _logger.LogInformation("Serial port {PortName} opened successfully", port);
                        return true;
                    }
                    catch (Exception ex)
                    {
                        lastException = ex;

                        // If this is the configured port and autodetect is disabled, stop early.
                        if (!_config.AutoDetectPort && !configuredIsAuto)
                        {
                            break;
                        }

                        // Otherwise, try next candidate port.
                        try
                        {
                            _serialPort?.Dispose();
                        }
                        catch
                        {
                            // ignore
                        }
                        finally
                        {
                            _serialPort = null;
                        }
                    }
                }

                var portsText = availablePorts.Length == 0 ? "(none)" : string.Join(", ", availablePorts.OrderBy(p => p));
                _logger.LogError(lastException,
                    "Failed to open any serial port. Configured={PortName}. Candidates={Candidates}. Available ports: {AvailablePorts}",
                    _config.PortName,
                    string.Join(", ", candidatePorts),
                    portsText);

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

            if (response.Length == 0)
            {
                _logger.LogWarning("No response received for slot {SlotId}", slotId);
                return false;
            }

            if (!TryValidateRev2Frame(response, out var validationError))
            {
                _logger.LogWarning("Invalid response frame for slot {SlotId}: {Error}. Raw={Raw}",
                    slotId, validationError, BitConverter.ToString(response));
                return false;
            }

            // Observed behavior (trace): controller echoes the exact frame back.
            // Be slightly tolerant: require address+command+slot to match.
            if (!Rev2ResponseMatchesRequest(commandBytes, response))
            {
                _logger.LogWarning(
                    "Unexpected response for slot {SlotId}. TX={Tx} RX={Rx}",
                    slotId,
                    BitConverter.ToString(commandBytes),
                    BitConverter.ToString(response));
                return false;
            }

            _logger.LogDebug("Valid response received for slot {SlotId}: {Response}", slotId, BitConverter.ToString(response));
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

                    // Read response. For the observed Serial_Rev2 protocol, the response is an 8-byte frame
                    // AA .. .. .. .. .. .. 55. We wait up to ReadTimeout for a full frame.
                    var response = ReadRev2Frame(_serialPort, _config.ReadTimeout);
                    TraceFrame("RX", response);
                    return response;
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

    private static bool Rev2ResponseMatchesRequest(byte[] request, byte[] response)
    {
        if (request.Length < Rev2FrameLength || response.Length < Rev2FrameLength)
        {
            return false;
        }

        // Layout (based on observed frames):
        // [0]=0xAA, [1]=addr, [2]=cmd, [3]=0x00, [4]=0x00, [5]=slotOrValue, [6]=xor, [7]=0x55
        return response[0] == request[0]
            && response[7] == request[7]
            && response[1] == request[1]
            && response[2] == request[2]
            && response[5] == request[5];
    }

    private static bool TryValidateRev2Frame(byte[] frame, out string? error)
    {
        error = null;

        if (frame.Length != Rev2FrameLength)
        {
            error = $"Expected {Rev2FrameLength} bytes, got {frame.Length}";
            return false;
        }

        if (frame[0] != 0xAA)
        {
            error = "Missing 0xAA start byte";
            return false;
        }

        if (frame[7] != 0x55)
        {
            error = "Missing 0x55 end byte";
            return false;
        }

        byte xor = 0;
        for (var i = 1; i <= 5; i++)
        {
            xor ^= frame[i];
        }

        if (frame[6] != xor)
        {
            error = $"Checksum mismatch (expected {xor:X2}, got {frame[6]:X2})";
            return false;
        }

        return true;
    }

    private static byte[] ReadRev2Frame(SerialPort serialPort, int timeoutMs)
    {
        var deadline = DateTime.UtcNow.AddMilliseconds(Math.Max(1, timeoutMs));
        var buffer = new List<byte>(64);

        while (DateTime.UtcNow < deadline)
        {
            var available = serialPort.BytesToRead;
            if (available > 0)
            {
                var tmp = new byte[available];
                var read = serialPort.Read(tmp, 0, tmp.Length);
                if (read > 0)
                {
                    buffer.AddRange(tmp.AsSpan(0, read).ToArray());

                    if (TryExtractRev2Frame(buffer, out var frame))
                    {
                        return frame;
                    }
                }
            }

            Thread.Sleep(10);
        }

        return Array.Empty<byte>();
    }

    private static bool TryExtractRev2Frame(List<byte> buffer, out byte[] frame)
    {
        frame = Array.Empty<byte>();

        // Scan for a valid 8-byte frame starting with 0xAA and ending with 0x55.
        for (var start = 0; start <= buffer.Count - Rev2FrameLength; start++)
        {
            if (buffer[start] != 0xAA)
            {
                continue;
            }

            if (buffer[start + 7] != 0x55)
            {
                continue;
            }

            var candidate = buffer.GetRange(start, Rev2FrameLength).ToArray();
            if (TryValidateRev2Frame(candidate, out _))
            {
                frame = candidate;
                // Drop bytes up to end of extracted frame to avoid unbounded growth.
                buffer.RemoveRange(0, start + Rev2FrameLength);
                return true;
            }
        }

        // Keep the tail in case we have a partial frame.
        if (buffer.Count > 256)
        {
            buffer.RemoveRange(0, buffer.Count - 256);
        }

        return false;
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
