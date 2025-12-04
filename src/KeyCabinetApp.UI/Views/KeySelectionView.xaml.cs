using System.Windows.Controls;
using System.Windows.Input;
using KeyCabinetApp.Core.Entities;
using KeyCabinetApp.UI.ViewModels;
using MaterialDesignThemes.Wpf;
using KeyEntity = KeyCabinetApp.Core.Entities.Key;

namespace KeyCabinetApp.UI.Views;

public partial class KeySelectionView : UserControl
{
    public KeySelectionView()
    {
        InitializeComponent();
    }

    private void Card_MouseEnter(object sender, MouseEventArgs e)
    {
        if (sender is Card card)
        {
            ElevationAssist.SetElevation(card, Elevation.Dp8);
        }
    }

    private void Card_MouseLeave(object sender, MouseEventArgs e)
    {
        if (sender is Card card)
        {
            ElevationAssist.SetElevation(card, Elevation.Dp4);
        }
    }

    private void Card_Click(object sender, MouseButtonEventArgs e)
    {
        if (sender is Card card && card.Tag is KeyEntity key && DataContext is KeySelectionViewModel viewModel)
        {
            viewModel.SelectedKey = key;
            if (viewModel.OpenKeyCommand.CanExecute(null))
            {
                viewModel.OpenKeyCommand.Execute(null);
            }
        }
    }
}
