using System.Windows.Input;

namespace KeyCabinetApp.UI.ViewModels;

public class AdminViewModel : ViewModelBase
{
    public AdminViewModel()
    {
        CloseCommand = new RelayCommand(_ => CloseRequested?.Invoke(this, EventArgs.Empty));
    }

    public ICommand CloseCommand { get; }

    public event EventHandler? CloseRequested;
}
