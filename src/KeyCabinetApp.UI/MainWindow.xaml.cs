using System.Windows;
using System.Windows.Input;
using KeyCabinetApp.UI.ViewModels;
using KeyCabinetApp.Core.Interfaces;

namespace KeyCabinetApp.UI;

public partial class MainWindow : Window
{
    private readonly MainViewModel _viewModel;
    private readonly IRfidReader _rfidReader;

    public MainWindow(MainViewModel viewModel, IRfidReader rfidReader)
    {
        InitializeComponent();
        
        _viewModel = viewModel;
        _rfidReader = rfidReader;
        
        DataContext = _viewModel;

        // Make fullscreen for kiosk mode
        WindowStyle = WindowStyle.None;
        WindowState = WindowState.Maximized;
        
        // Handle RFID keyboard input
        PreviewTextInput += OnPreviewTextInput;
        PreviewKeyDown += OnPreviewKeyDown;
    }

    private void OnPreviewTextInput(object sender, TextCompositionEventArgs e)
    {
        if (_rfidReader is Infrastructure.Rfid.KeyboardWedgeRfidReader reader)
        {
            reader.ProcessKeyInput(e.Text);
        }
    }

    private void OnPreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter && _rfidReader is Infrastructure.Rfid.KeyboardWedgeRfidReader reader)
        {
            reader.ProcessEnterKey();
        }

        // Allow Escape to exit fullscreen (for development/testing)
        if (e.Key == Key.Escape)
        {
            if (WindowState == WindowState.Maximized)
            {
                WindowState = WindowState.Normal;
                WindowStyle = WindowStyle.SingleBorderWindow;
            }
        }

        // F11 to toggle fullscreen
        if (e.Key == Key.F11)
        {
            if (WindowState == WindowState.Maximized)
            {
                WindowState = WindowState.Normal;
                WindowStyle = WindowStyle.SingleBorderWindow;
            }
            else
            {
                WindowStyle = WindowStyle.None;
                WindowState = WindowState.Maximized;
            }
        }
    }
}
