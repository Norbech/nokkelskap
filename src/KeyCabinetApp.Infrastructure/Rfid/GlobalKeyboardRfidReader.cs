using KeyCabinetApp.Core.Interfaces;
using Microsoft.Extensions.Logging;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

namespace KeyCabinetApp.Infrastructure.Rfid;

/// <summary>
/// RFID reader that uses a global Windows keyboard hook to capture RFID scans
/// from any application, without requiring window focus.
/// </summary>
public class GlobalKeyboardRfidReader : IRfidReader, IDisposable
{
    private readonly ILogger<GlobalKeyboardRfidReader> _logger;
    private bool _isListening;
    private IntPtr _hookId = IntPtr.Zero;
    private LowLevelKeyboardProc? _hookCallback;
    private Thread? _hookThread;
    private uint _hookThreadId;
    private readonly ManualResetEventSlim _hookReady = new(false);
    private readonly StringBuilder _buffer = new StringBuilder();
    private DateTime _lastKeyPress = DateTime.MinValue;
    private readonly int _bufferTimeout = 300; // milliseconds
    private System.Timers.Timer? _bufferTimer;

    public event EventHandler<string>? CardScanned;

    public GlobalKeyboardRfidReader(ILogger<GlobalKeyboardRfidReader> logger)
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
        _hookReady.Reset();

        _hookThread = new Thread(HookThreadMain)
        {
            IsBackground = true,
            Name = "GlobalKeyboardRfidHook"
        };

        _hookThread.Start();

        // Wait briefly for hook installation
        if (!_hookReady.Wait(TimeSpan.FromSeconds(2)))
        {
            _logger.LogWarning("Timed out waiting for global keyboard hook thread to initialize");
        }
    }

    public void StopListening()
    {
        if (!_isListening)
            return;

        _isListening = false;
        _buffer.Clear();
        _bufferTimer?.Stop();

        // Ask hook thread to quit its message loop
        if (_hookThreadId != 0)
        {
            PostThreadMessage(_hookThreadId, WM_QUIT, UIntPtr.Zero, IntPtr.Zero);
        }

        if (_hookThread != null)
        {
            if (!_hookThread.Join(TimeSpan.FromSeconds(2)))
            {
                _logger.LogWarning("Global keyboard hook thread did not stop within timeout");
            }
            _hookThread = null;
        }

        _logger.LogInformation("Global keyboard hook stopped");
    }

    private void HookThreadMain()
    {
        try
        {
            _hookThreadId = GetCurrentThreadId();

            _hookCallback = HookCallback;
            _hookId = SetWindowsHookEx(WH_KEYBOARD_LL, _hookCallback, IntPtr.Zero, 0);

            if (_hookId == IntPtr.Zero)
            {
                var error = Marshal.GetLastWin32Error();
                _logger.LogError("Failed to install global keyboard hook (SetWindowsHookEx returned 0). Win32Error={Error}", error);
                _hookReady.Set();
                return;
            }

            _logger.LogInformation("Global keyboard hook installed - RFID reader active (works from any window)");
            _hookReady.Set();

            // Message loop is required for low-level hooks to reliably receive events.
            while (GetMessage(out var msg, IntPtr.Zero, 0, 0) != 0)
            {
                TranslateMessage(ref msg);
                DispatchMessage(ref msg);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in global keyboard hook thread");
        }
        finally
        {
            if (_hookId != IntPtr.Zero)
            {
                UnhookWindowsHookEx(_hookId);
                _hookId = IntPtr.Zero;
            }

            _hookThreadId = 0;
            _hookReady.Set();

            _logger.LogInformation("Global keyboard hook removed");
        }
    }

    private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0 && _isListening)
        {
            int vkCode = Marshal.ReadInt32(lParam);

            // Check if this is a key down event
            if (wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN)
            {
                // Handle Enter key
                if (vkCode == VK_RETURN)
                {
                    _bufferTimer?.Stop();
                    ProcessBuffer();
                }
                else
                {
                    // Convert virtual key code to character
                    char key = GetCharFromVirtualKey(vkCode);
                    if (key != '\0')
                    {
                        var now = DateTime.UtcNow;
                        var timeSinceLastKey = (now - _lastKeyPress).TotalMilliseconds;
                        _lastKeyPress = now;

                        // If there's a long gap, clear the buffer (new scan starting)
                        if (timeSinceLastKey > _bufferTimeout && _buffer.Length > 0)
                        {
                            _buffer.Clear();
                        }

                        _buffer.Append(key);

                        // Restart the timer
                        _bufferTimer?.Stop();
                        _bufferTimer?.Start();
                    }
                }
            }
        }

        return CallNextHookEx(_hookId, nCode, wParam, lParam);
    }

    private void ProcessBuffer()
    {
        if (_buffer.Length == 0)
            return;

        var cardData = _buffer.ToString().Trim();
        _buffer.Clear();

        // Validate that this looks like an RFID card
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

    private static char GetCharFromVirtualKey(int vkCode)
    {
        // Handle numbers (0-9)
        if (vkCode >= 0x30 && vkCode <= 0x39)
            return (char)vkCode;

        // Handle numpad numbers (0-9)
        if (vkCode >= 0x60 && vkCode <= 0x69)
            return (char)(vkCode - 0x60 + '0');

        // Handle letters (A-Z)
        if (vkCode >= 0x41 && vkCode <= 0x5A)
            return (char)vkCode;

        return '\0';
    }

    private bool IsValidRfidFormat(string data)
    {
        // Accept if it's at least 4 characters and contains only alphanumeric
        return data.Length >= 4 && data.All(c => char.IsLetterOrDigit(c));
    }

    private string MaskCardData(string cardData)
    {
        if (cardData.Length <= 4)
            return "****";
        return cardData.Substring(0, 2) + new string('*', cardData.Length - 4) + cardData.Substring(cardData.Length - 2);
    }

    public void Dispose()
    {
        StopListening();
        _bufferTimer?.Dispose();
    }

    #region Windows API

    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_SYSKEYDOWN = 0x0104;
    private const int VK_RETURN = 0x0D;
    private const uint WM_QUIT = 0x0012;

    [StructLayout(LayoutKind.Sequential)]
    private struct MSG
    {
        public IntPtr hwnd;
        public uint message;
        public UIntPtr wParam;
        public IntPtr lParam;
        public uint time;
        public POINT pt;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT
    {
        public int x;
        public int y;
    }

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern int GetMessage(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax);

    [DllImport("user32.dll")]
    private static extern bool TranslateMessage(ref MSG lpMsg);

    [DllImport("user32.dll")]
    private static extern IntPtr DispatchMessage(ref MSG lpMsg);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool PostThreadMessage(uint idThread, uint msg, UIntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll")]
    private static extern uint GetCurrentThreadId();

    #endregion
}
