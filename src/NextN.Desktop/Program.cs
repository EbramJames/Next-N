using NextN.Desktop.Common;
using NextN.Desktop.Manager;

namespace NextN.Desktop;

internal class Program
{
    public static EventWaitHandle? ProgramStarted;
    // Retain the single-instance mutex for the entire lifetime of the process on non-Windows platforms.
    private static Mutex? _singleInstanceMutex;

    [STAThread]
    public static void Main(string[] args)
    {
        try
        {
            if (!OnStartup(args))
            {
                Environment.Exit(0);
                return;
            }

            BuildAvaloniaApp()
                .StartWithClassicDesktopLifetime(args);
        }
        catch (Exception ex)
        {
            try
            {
                Logging.SaveLog("FatalStartupException", ex);
                File.WriteAllText(Utils.GetLogPath("crash.log"), ex.ToString());
            }
            catch { }
            Console.Error.WriteLine(ex);
            throw;
        }
    }

    private static bool OnStartup(string[]? args)
    {
        if (Utils.IsWindows())
        {
            var exePathKey = $"NextN_{Utils.GetMd5(Utils.GetExePath())}";
            var rebootas = (args ?? []).Any(t => t == Global.RebootAs);
            ProgramStarted = new EventWaitHandle(false, EventResetMode.AutoReset, exePathKey, out var bCreatedNew);
            if (!rebootas && !bCreatedNew)
            {
                ProgramStarted.Set();
                return false;
            }
        }
        else
        {
            _singleInstanceMutex = new Mutex(true, Global.AppSlug, out var bOnlyOneInstance);
            if (!bOnlyOneInstance)
            {
                return false;
            }
        }

        if (!AppManager.Instance.InitApp())
        {
            return false;
        }

        AppManager.Instance.WindowDialog = new WindowDialog();
        return true;
    }

    // Avalonia configuration, don't remove; also used by visual designer.
    public static AppBuilder BuildAvaloniaApp()
    {
        var builder = AppBuilder.Configure<App>()
            .UsePlatformDetect()
            .WithFontByDefault()
#if DEBUG
            .WithDeveloperTools()
#endif
            .LogToTrace()
            .UseReactiveUI(_ => { });

        if (OperatingSystem.IsMacOS())
        {
            var showInDock = Design.IsDesignMode || AppManager.Instance.Config.UiItem.MacOSShowInDock;
            builder = builder.With(new MacOSPlatformOptions { ShowInDock = showInDock });
        }

        return builder;
    }
}
