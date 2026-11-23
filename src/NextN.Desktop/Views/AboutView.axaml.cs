using System.Runtime.InteropServices;
using DialogHostAvalonia;

namespace NextN.Desktop.Views;

public partial class AboutView : UserControl
{
    public AboutView()
    {
        InitializeComponent();

        txtVersion.Text = $"v{Utils.GetVersionInfo()}  •  {RuntimeInformation.OSArchitecture}";

        btnOpenGithub.Click += (_, _) => ProcUtils.ProcessStart(Global.ProjectUrl);
        btnOpenIssues.Click += (_, _) => ProcUtils.ProcessStart($"{Global.ProjectUrl}/issues");
        btnClose.Click += (_, _) => DialogHost.Close(null);
    }
}
