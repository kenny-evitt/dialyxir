defmodule Dialyxir.Warnings.NegativeGuardFail do
  @behaviour Dialyxir.Warning

  @impl Dialyxir.Warning
  @spec warning() :: :neg_guard_fail
  def warning(), do: :neg_guard_fail

  @impl Dialyxir.Warning
  @spec format_short([String.t()]) :: String.t()
  def format_short(_) do
    "Guard test can never succeed."
  end

  @impl Dialyxir.Warning
  @spec format_long([String.t()]) :: String.t()
  def format_long([guard, args]) do
    pretty_args = Dialyxir.PrettyPrint.pretty_print_args(args)

    """
    Guard test:
    not #{guard}#{pretty_args}

    can never succeed.
    """
  end

  def format_long([arg1, infix, arg2]) do
    pretty_infix = Dialyxir.PrettyPrint.pretty_print_infix(infix)

    """
    Guard test:
    not #{arg1} #{pretty_infix} #{arg2}

    can never succeed.
    """
  end

  @impl Dialyxir.Warning
  @spec explain() :: String.t()
  def explain() do
    """
    The function guard either presents an impossible guard or the only
    calls will never succeed against the guards.

    Example:

    defmodule Example do
      def ok(ok = "ok") when not is_bitstring(ok) do
        :ok
      end
    end

    or

    defmodule Example do
      def ok() do
        ok(:ok)
      end

      defp ok(ok) when not is_atom(ok) do
        :ok
      end
    end
    """
  end
end
