using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Media;
using System.Windows.Threading;
using System.Windows.Forms;

namespace KeyCabinetApp.LocalServerLauncher;

/// <summary>
/// Interaction logic for MainWindow.xaml
/// </summary>
public partial class MainWindow : Window
{
    private readonly HttpClient _http = new() { Timeout = TimeSpan.FromMilliseconds(800) };
    private readonly DispatcherTimer _pollTimer;

    private readonly bool _autoStartOnLoad;
    private readonly bool _startMinimized;

    private readonly bool _trayEnabled;
    private readonly bool _noBrowser;
    private readonly bool _openBrowser;
    private readonly bool _fullScreenBrowser;

    private bool _pendingBrowserOpen;
    private bool _browserOpened;
    private bool _exitRequested;

    private NotifyIcon? _trayIcon;

    private Process? _webProcess;
    private Process? _agentProcess;

    private readonly string _baseDir;
    private readonly string _webDir;
    private readonly string _agentDir;
    private readonly string _logsDir;
    private readonly string _runDir;

    private const string Urls = "http://127.0.0.1:5000";
    private static readonly Uri HealthUri = new("http://127.0.0.1:5000/health");

    public MainWindow()
    {
        InitializeComponent();

        var args = Environment.GetCommandLineArgs();
        _autoStartOnLoad = !args.Any(a => string.Equals(a, "--no-autostart", StringComparison.OrdinalIgnoreCase));
        _startMinimized = args.Any(a => string.Equals(a, "--minimized", StringComparison.OrdinalIgnoreCase));

        _trayEnabled = args.Any(a => string.Equals(a, "--tray", StringComparison.OrdinalIgnoreCase))
            || !args.Any(a => string.Equals(a, "--no-tray", StringComparison.OrdinalIgnoreCase));
        _noBrowser = args.Any(a => string.Equals(a, "--no-browser", StringComparison.OrdinalIgnoreCase));
        _openBrowser = args.Any(a => string.Equals(a, "--browser", StringComparison.OrdinalIgnoreCase));
        _fullScreenBrowser = !args.Any(a => string.Equals(a, "--no-fullscreen", StringComparison.OrdinalIgnoreCase));

        _baseDir = AppContext.BaseDirectory;
        _webDir = Path.Combine(_baseDir, "web");
        _agentDir = Path.Combine(_baseDir, "agent");
        _logsDir = Path.Combine(_baseDir, "logs");
        _runDir = Path.Combine(_baseDir, ".run");

        _pollTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromSeconds(1)
        };
        _pollTimer.Tick += async (_, _) => await RefreshStatusAsync();

        if (_trayEnabled)
        {
            SetupTrayIcon();

            StateChanged += (_, _) =>
            {
                if (WindowState == WindowState.Minimized)
                {
                    HideToTray();
                }
            };
        }

        Loaded += async (_, _) =>
        {
            InfoText.Text = $"Bundle: {_baseDir}";

            if (_startMinimized)
            {
                WindowState = WindowState.Minimized;
                if (_trayEnabled)
                {
                    HideToTray();
                }
            }

            TryAttachFromPidFiles();
            await RefreshStatusAsync();

            if (_autoStartOnLoad)
            {
                // If something is already running (autostart/scripts/another launcher instance),
                // don't restart it. Just keep polling.
                var healthy = await IsHealthyAsync();
                if (!healthy && !IsAnyRunning())
                {
                    await StartAsync();
                }
            }
        };

        Closing += async (_, e) =>
        {
            if (_trayEnabled && !_exitRequested)
            {
                // Keep tray icon running; just hide the window.
                e.Cancel = true;
                if (StopOnCloseCheckBox.IsChecked == true)
                {
                    await StopAsync();
                }
                HideToTray();
                return;
            }

            if (StopOnCloseCheckBox.IsChecked == true)
            {
                e.Cancel = true;
                await StopAsync();
                e.Cancel = false;
            }

            _trayIcon?.Dispose();
        };
    }

    private async void StartStopButton_Click(object sender, RoutedEventArgs e)
    {
        StartStopButton.IsEnabled = false;
        try
        {
            if (IsAnyRunning())
            {
                await StopAsync();
            }
            else
            {
                await StartAsync();
            }
        }
        finally
        {
            StartStopButton.IsEnabled = true;
        }
    }

    private void OpenUrl_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "http://127.0.0.1:5000",
                UseShellExecute = true
            });
        }
        catch
        {
            // Ignore
        }
    }

    private bool IsAnyRunning()
        => (_webProcess is { HasExited: false }) || (_agentProcess is { HasExited: false });

    private async Task StartAsync()
    {
        InfoText.Text = "Starter...";

        if (!Directory.Exists(_webDir) || !Directory.Exists(_agentDir))
        {
            InfoText.Text = "Fant ikke web/ og agent/ ved siden av launcher. Legg denne .exe i bundle-mappa.";
            return;
        }

        Directory.CreateDirectory(_logsDir);
        Directory.CreateDirectory(_runDir);

        // If web/agent is already running (e.g., via autostart tasks), attach and just start polling.
        TryAttachFromPidFiles();
        if (IsAnyRunning() || await IsHealthyAsync())
        {
            _pollTimer.Start();
            await RefreshStatusAsync();
            InfoText.Text = "Kjører allerede.";
            return;
        }

        // Decide whether to open browser after startup.
        // Default behavior: open browser when running interactively (not minimized), unless --no-browser.
        var interactive = !_startMinimized;
        var shouldOpenBrowser = !_noBrowser && (_openBrowser || interactive);
        if (shouldOpenBrowser)
        {
            _pendingBrowserOpen = true;
            _browserOpened = false;
        }

        // Copy editable config overrides if present.
        var configDir = Path.Combine(_baseDir, "config");
        var webConfigSrc = Path.Combine(configDir, "appsettings.web.json");
        var agentConfigSrc = Path.Combine(configDir, "appsettings.agent.json");
        if (File.Exists(webConfigSrc))
        {
            File.Copy(webConfigSrc, Path.Combine(_webDir, "appsettings.json"), overwrite: true);
        }
        if (File.Exists(agentConfigSrc))
        {
            File.Copy(agentConfigSrc, Path.Combine(_agentDir, "appsettings.json"), overwrite: true);
        }

        // Clean up stale pid files (if any). Do not kill existing processes here.
        CleanupStalePidFile(Path.Combine(_runDir, "web.pid"));
        CleanupStalePidFile(Path.Combine(_runDir, "agent.pid"));

        _webProcess = StartHiddenProcess(
            workingDir: _webDir,
            exeOrDllBaseName: "KeyCabinetApp.Web",
            args: new[] { "--urls", Urls },
            stdoutLogPath: Path.Combine(_logsDir, "web.out.log"),
            stderrLogPath: Path.Combine(_logsDir, "web.err.log"));

        File.WriteAllText(Path.Combine(_runDir, "web.pid"), _webProcess.Id.ToString());

        _agentProcess = StartHiddenProcess(
            workingDir: _agentDir,
            exeOrDllBaseName: "KeyCabinetApp.HardwareAgent",
            args: Array.Empty<string>(),
            stdoutLogPath: Path.Combine(_logsDir, "agent.out.log"),
            stderrLogPath: Path.Combine(_logsDir, "agent.err.log"));

        File.WriteAllText(Path.Combine(_runDir, "agent.pid"), _agentProcess.Id.ToString());

        _pollTimer.Start();
        await RefreshStatusAsync();
    }

    private async Task StopAsync()
    {
        _pollTimer.Stop();
        InfoText.Text = "Stopper...";

        // Stop whatever the bundle pid files point to (works for autostart scripts too)
        StopPidFileProcess(Path.Combine(_runDir, "web.pid"));
        StopPidFileProcess(Path.Combine(_runDir, "agent.pid"));

        StopProcessSafe(_webProcess);
        StopProcessSafe(_agentProcess);

        _webProcess = null;
        _agentProcess = null;

        // Clean pid files
        TryDelete(Path.Combine(_runDir, "web.pid"));
        TryDelete(Path.Combine(_runDir, "agent.pid"));

        await RefreshStatusAsync();
    }

    private async Task RefreshStatusAsync()
    {
        // If started elsewhere (autostart/scripts), attach so Stop works.
        TryAttachFromPidFiles();

        var healthy = await IsHealthyAsync();
        if (healthy)
        {
            SetLamp(Colors.SeaGreen);
            StatusText.Text = "Kjører";
            StartStopButton.Content = "Stopp";

            UpdateTrayTooltip("Kjorer");

            if (_pendingBrowserOpen && !_browserOpened)
            {
                _browserOpened = true;
                _pendingBrowserOpen = false;
                OpenBrowser(Urls, fullscreen: _fullScreenBrowser);
            }

            return;
        }

        var webRunning = _webProcess is { HasExited: false };
        var agentRunning = _agentProcess is { HasExited: false };

        if (!webRunning && !agentRunning)
        {
            SetLamp(Colors.DarkRed);
            StatusText.Text = "Stoppet";
            StartStopButton.Content = "Start";

            UpdateTrayTooltip("Stoppet");
            return;
        }

        SetLamp(Colors.DarkGoldenrod);
        StatusText.Text = "Starter...";
        StartStopButton.Content = "Stopp";

        UpdateTrayTooltip("Starter");
    }

    private void UpdateTrayTooltip(string status)
    {
        try
        {
            if (_trayIcon is null) return;

            // NotifyIcon.Text has a hard limit (~63 chars). Keep it short and safe.
            var text = $"KeyCabinet: {status}";
            if (text.Length > 63) text = text.Substring(0, 63);
            _trayIcon.Text = text;
        }
        catch
        {
            // ignore
        }
    }

    private void SetupTrayIcon()
    {
        _trayIcon = new NotifyIcon
        {
            Visible = true,
            Text = "KeyCabinet Server",
            Icon = System.Drawing.SystemIcons.Application
        };

        UpdateTrayTooltip("Starter");

        var menu = new ContextMenuStrip();

        var openUiItem = new ToolStripMenuItem("Open UI", null, (_, _) => Dispatcher.Invoke(ShowFromTray));
        var openWebItem = new ToolStripMenuItem("Open Web", null, (_, _) => Dispatcher.Invoke(() => OpenBrowser(Urls, fullscreen: false)));

        var startItem = new ToolStripMenuItem("Start", null, (_, _) =>
            Dispatcher.BeginInvoke(new Action(async () => await StartAsync())));

        var stopItem = new ToolStripMenuItem("Stop", null, (_, _) =>
            Dispatcher.BeginInvoke(new Action(async () => await StopAsync())));

        var exitItem = new ToolStripMenuItem("Exit", null, (_, _) => Dispatcher.Invoke(() =>
        {
            _exitRequested = true;
            _trayIcon?.Dispose();
            Close();
        }));

        menu.Items.Add(openUiItem);
        menu.Items.Add(openWebItem);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(startItem);
        menu.Items.Add(stopItem);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(exitItem);

        _trayIcon.ContextMenuStrip = menu;
        _trayIcon.DoubleClick += (_, _) => Dispatcher.Invoke(ToggleTrayWindow);
    }

    private void ToggleTrayWindow()
    {
        if (IsVisible)
        {
            HideToTray();
        }
        else
        {
            ShowFromTray();
        }
    }

    private void HideToTray()
    {
        ShowInTaskbar = false;
        Hide();
    }

    private void ShowFromTray()
    {
        ShowInTaskbar = true;
        Show();
        WindowState = WindowState.Normal;
        Activate();
    }

    private static void OpenBrowser(string url, bool fullscreen)
    {
        try
        {
            if (fullscreen)
            {
                var edge = FindBrowserExe("msedge.exe", new[]
                {
                    Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Microsoft", "Edge", "Application", "msedge.exe"),
                    Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Microsoft", "Edge", "Application", "msedge.exe")
                });

                if (!string.IsNullOrWhiteSpace(edge))
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = edge,
                        Arguments = "--new-window --start-fullscreen " + QuoteIfNeeded(url),
                        UseShellExecute = false
                    });
                    return;
                }

                var chrome = FindBrowserExe("chrome.exe", new[]
                {
                    Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Google", "Chrome", "Application", "chrome.exe"),
                    Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Google", "Chrome", "Application", "chrome.exe")
                });

                if (!string.IsNullOrWhiteSpace(chrome))
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = chrome,
                        Arguments = "--new-window --start-fullscreen " + QuoteIfNeeded(url),
                        UseShellExecute = false
                    });
                    return;
                }
            }

            Process.Start(new ProcessStartInfo
            {
                FileName = url,
                UseShellExecute = true
            });
        }
        catch
        {
            // ignore
        }
    }

    private static string? FindBrowserExe(string exeName, IEnumerable<string> preferredPaths)
    {
        foreach (var p in preferredPaths)
        {
            try
            {
                if (!string.IsNullOrWhiteSpace(p) && File.Exists(p)) return p;
            }
            catch { }
        }

        try
        {
            var env = Environment.GetEnvironmentVariable("PATH") ?? string.Empty;
            foreach (var dir in env.Split(';').Where(s => !string.IsNullOrWhiteSpace(s)))
            {
                var cand = Path.Combine(dir.Trim(), exeName);
                if (File.Exists(cand)) return cand;
            }
        }
        catch
        {
            // ignore
        }

        return null;
    }

    private void TryAttachFromPidFiles()
    {
        _webProcess ??= TryGetProcessFromPidFile(Path.Combine(_runDir, "web.pid"));
        _agentProcess ??= TryGetProcessFromPidFile(Path.Combine(_runDir, "agent.pid"));

        if (_webProcess is { HasExited: true }) _webProcess = null;
        if (_agentProcess is { HasExited: true }) _agentProcess = null;
    }

    private static Process? TryGetProcessFromPidFile(string pidFile)
    {
        try
        {
            if (!File.Exists(pidFile)) return null;
            var pidRaw = File.ReadAllText(pidFile).Trim();
            if (!int.TryParse(pidRaw, out var pid)) return null;
            var p = Process.GetProcessById(pid);
            return p.HasExited ? null : p;
        }
        catch
        {
            return null;
        }
    }

    private static void CleanupStalePidFile(string pidFile)
    {
        try
        {
            if (!File.Exists(pidFile)) return;
            var pidRaw = File.ReadAllText(pidFile).Trim();
            if (!int.TryParse(pidRaw, out var pid))
            {
                TryDelete(pidFile);
                return;
            }

            try
            {
                var p = Process.GetProcessById(pid);
                if (p.HasExited) TryDelete(pidFile);
            }
            catch
            {
                // Process doesn't exist
                TryDelete(pidFile);
            }
        }
        catch
        {
            // ignore
        }
    }

    private async Task<bool> IsHealthyAsync()
    {
        try
        {
            using var cts = new CancellationTokenSource(TimeSpan.FromMilliseconds(900));
            using var resp = await _http.GetAsync(HealthUri, cts.Token);
            return resp.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }

    private void SetLamp(System.Windows.Media.Color color)
    {
        StatusLamp.Fill = new SolidColorBrush(color);
    }

    private static Process StartHiddenProcess(
        string workingDir,
        string exeOrDllBaseName,
        string[] args,
        string stdoutLogPath,
        string stderrLogPath)
    {
        var exePath = Path.Combine(workingDir, exeOrDllBaseName + ".exe");
        var dllPath = Path.Combine(workingDir, exeOrDllBaseName + ".dll");

        string fileName;
        string arguments;

        if (File.Exists(exePath))
        {
            fileName = exePath;
            arguments = JoinArgs(args);
        }
        else if (File.Exists(dllPath))
        {
            var dotnet = ResolveDotNetExe();
            if (string.IsNullOrWhiteSpace(dotnet) || !File.Exists(dotnet))
            {
                throw new InvalidOperationException("dotnet.exe ble ikke funnet. Installer .NET 8 Hosting Bundle.");
            }

            fileName = dotnet;
            arguments = JoinArgs(new[] { dllPath }.Concat(args).ToArray());
        }
        else
        {
            throw new FileNotFoundException($"Fant ikke {exePath} eller {dllPath}");
        }

        var psi = new ProcessStartInfo
        {
            FileName = fileName,
            Arguments = arguments,
            WorkingDirectory = workingDir,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };

        var p = new Process { StartInfo = psi, EnableRaisingEvents = true };
        if (!p.Start())
        {
            throw new InvalidOperationException("Kunne ikke starte prosess.");
        }

        StartPumpToFile(p.StandardOutput, stdoutLogPath);
        StartPumpToFile(p.StandardError, stderrLogPath);
        return p;
    }

    private static void StartPumpToFile(StreamReader reader, string path)
    {
        _ = Task.Run(async () =>
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(path) ?? ".");
                await using var fs = new FileStream(path, FileMode.Append, FileAccess.Write, FileShare.ReadWrite);
                await using var sw = new StreamWriter(fs) { AutoFlush = true };

                while (true)
                {
                    var line = await reader.ReadLineAsync();
                    if (line is null) break;
                    await sw.WriteLineAsync(line);
                }
            }
            catch
            {
                // Ignore log errors
            }
        });
    }

    private static string JoinArgs(IEnumerable<string> args)
        => string.Join(" ", args.Select(QuoteIfNeeded));

    private static string QuoteIfNeeded(string arg)
    {
        if (string.IsNullOrEmpty(arg)) return "\"\"";
        return arg.Contains(' ') ? "\"" + arg.Replace("\"", "\\\"") + "\"" : arg;
    }

    private static string? ResolveDotNetExe()
    {
        var pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
        var pfx86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);

        var candidates = new[]
        {
            Path.Combine(pf, "dotnet", "dotnet.exe"),
            Path.Combine(pfx86, "dotnet", "dotnet.exe")
        };

        foreach (var c in candidates)
        {
            if (!string.IsNullOrWhiteSpace(c) && File.Exists(c)) return c;
        }

        try
        {
            var env = Environment.GetEnvironmentVariable("PATH") ?? string.Empty;
            foreach (var dir in env.Split(';').Where(s => !string.IsNullOrWhiteSpace(s)))
            {
                var cand = Path.Combine(dir.Trim(), "dotnet.exe");
                if (File.Exists(cand)) return cand;
            }
        }
        catch
        {
            // ignore
        }

        return null;
    }

    private static void StopProcessSafe(Process? p)
    {
        if (p is null) return;
        try
        {
            if (!p.HasExited)
            {
                p.Kill(entireProcessTree: true);
                p.WaitForExit(2000);
            }
        }
        catch
        {
            // Ignore
        }
    }

    private static void StopPidFileProcess(string pidFile)
    {
        try
        {
            if (!File.Exists(pidFile)) return;
            var pidRaw = File.ReadAllText(pidFile).Trim();
            if (!int.TryParse(pidRaw, out var pid)) return;

            try
            {
                var p = Process.GetProcessById(pid);
                p.Kill(entireProcessTree: true);
            }
            catch
            {
                // ignore
            }
        }
        catch
        {
            // ignore
        }
        finally
        {
            TryDelete(pidFile);
        }
    }

    private static void TryDelete(string path)
    {
        try
        {
            if (File.Exists(path)) File.Delete(path);
        }
        catch
        {
            // ignore
        }
    }
}