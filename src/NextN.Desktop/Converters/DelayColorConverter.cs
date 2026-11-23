using Avalonia.Data.Converters;

namespace NextN.Desktop.Converters;

public class DelayColorConverter : IValueConverter
{
    private static readonly SolidColorBrush FastBrush = new(Color.Parse("#10B981"));
    private static readonly SolidColorBrush MediumBrush = new(Color.Parse("#F59E0B"));
    private static readonly SolidColorBrush SlowBrush = new(Color.Parse("#F43F5E"));

    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        var delay = value?.ToString().ToInt() ?? -1;

        return delay switch
        {
            <= 0 => SlowBrush,
            <= 250 => FastBrush,
            <= 600 => MediumBrush,
            _ => SlowBrush
        };
    }

    public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        return null;
    }
}
