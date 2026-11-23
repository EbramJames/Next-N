using NextN.Desktop.Base;

namespace NextN.Desktop.Views;

public partial class FullConfigTemplateWindow : WindowBase<FullConfigTemplateViewModel>
{
    private static Config _config;

    public FullConfigTemplateWindow()
    {
        InitializeComponent();

        _config = AppManager.Instance.Config;
        Loaded += Window_Loaded;
        btnCancel.Click += (_, _) => Close();

        this.WhenActivated(disposables =>
        {
            this.Bind(ViewModel, vm => vm.EnableFullConfigTemplate4Ray, v => v.rayFullConfigTemplateEnable.IsChecked).DisposeWith(disposables);
            this.Bind(ViewModel, vm => vm.FullConfigTemplate4Ray, v => v.rayFullConfigTemplate.Text).DisposeWith(disposables);
            this.Bind(ViewModel, vm => vm.FullTunConfigTemplate4Ray, v => v.rayFullTunConfigTemplate.Text).DisposeWith(disposables);
            this.Bind(ViewModel, vm => vm.AddProxyOnly4Ray, v => v.togAddProxyProtocolOutboundOnly4Ray.IsChecked).DisposeWith(disposables);
            this.Bind(ViewModel, vm => vm.ProxyDetour4Ray, v => v.txtProxyDetour4Ray.Text).DisposeWith(disposables);
            this.Bind(ViewModel, vm => vm.EnableFullConfigTemplate4Singbox, v => v.sbFullConfigTemplateEnable.IsChecked).DisposeWith(disposables);
            this.Bind(ViewModel, vm => vm.FullConfigTemplate4Singbox, v => v.sbFullConfigTemplate.Text).DisposeWith(disposables);
            this.Bind(ViewModel, vm => vm.FullTunConfigTemplate4Singbox, v => v.sbFullTunConfigTemplate.Text).DisposeWith(disposables);
            this.Bind(ViewModel, vm => vm.AddProxyOnly4Singbox, v => v.togAddProxyProtocolOutboundOnly4Singbox.IsChecked).DisposeWith(disposables);
            this.Bind(ViewModel, vm => vm.ProxyDetour4Singbox, v => v.txtProxyDetour4Singbox.Text).DisposeWith(disposables);

            this.BindCommand(ViewModel, vm => vm.SaveCmd, v => v.btnSave).DisposeWith(disposables);
        });
    }

    private void linkFullConfigTemplateDoc_Click(object sender, RoutedEventArgs e)
    {
        ProcUtils.ProcessStart($"{Global.ProjectUrl}#configuration-templates");
    }

    private void Window_Loaded(object? sender, RoutedEventArgs e)
    {
        btnCancel.Focus();
    }
}
