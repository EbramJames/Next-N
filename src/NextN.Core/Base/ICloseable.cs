namespace NextN.Core.Base;

public interface ICloseable
{
    public event EventHandler? RequestClose;
}
