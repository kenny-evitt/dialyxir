defmodule Dialyxir.PrettyPrint do
  defp parse(str) do
    {:ok, tokens, _} =
      str
      |> to_charlist()
      |> :struct_lexer.string()

    {:ok, list} = :struct_parser.parse(tokens)
    list
  end

  @spec pretty_print(String.t()) :: String.t()
  def pretty_print(str) do
    try do
      str
      |> parse()
      |> List.first()
      |> do_pretty_print()
    rescue
      _ ->
        throw({:error, :parsing, str})
    end
  end

  def pretty_print_pattern('pattern ' ++ rest) do
    "pattern " <> pretty_print(rest)
  end

  def pretty_print_pattern(pattern), do: pretty_print(pattern)

  def pretty_print_contract(str) do
    pretty_print(str)
  end

  @spec pretty_print_type(String.t()) :: String.t()
  def pretty_print_type(str) do
    prefix = "@spec a("
    suffix = ") :: :ok\ndef a() do\n  :ok\nend"
    pretty = pretty_print(str)

    """
    @spec a(#{pretty}) :: :ok
    def a() do
      :ok
    end
    """
    |> Code.format_string!()
    |> Enum.join("")
    |> String.trim_leading(prefix)
    |> String.trim_trailing(suffix)
    |> String.replace("\n      ", "\n")
  end

  @spec pretty_print_args(String.t()) :: String.t()
  def pretty_print_args(str) do
    prefix = "@spec a"
    suffix = " :: :ok\ndef a() do\n  :ok\nend"
    pretty = pretty_print(str)

    """
    @spec a#{pretty} :: :ok
    def a() do
      :ok
    end
    """
    |> Code.format_string!()
    |> Enum.join("")
    |> String.trim_leading(prefix)
    |> String.trim_trailing(suffix)
    |> String.replace("\n      ", "\n")
  end

  defp do_pretty_print({:any}) do
    "_"
  end

  defp do_pretty_print({:byte_list, byte_list}) do
    byte_list
    |> Enum.into(<<>>, fn byte ->
      <<byte::8>>
    end)
    |> inspect()
  end

  defp do_pretty_print({:atom, 'false'}) do
    "false"
  end

  defp do_pretty_print({:atom, 'true'}) do
    "true"
  end

  defp do_pretty_print({:atom, atom}) do
    module_name = strip_elixir(atom)

    if module_name == to_string(atom) do
      ":#{atom}"
    else
      "#{module_name}"
    end
  end

  defp do_pretty_print({:binary_part, value, _, size}) do
    "#{do_pretty_print(value)} :: #{do_pretty_print(size)}"
  end

  defp do_pretty_print({:binary_part, value, size}) do
    "#{do_pretty_print(value)} :: #{do_pretty_print(size)}"
  end

  # TODO: Not sure if this is completely correct. But this seems to line up with actual code.
  defp do_pretty_print(
         {:binary,
          [{:binary_part, {:any}, {:int, 64}}, {:binary_part, {:any}, {:any}, {:size, {:int, 8}}}]}
       ) do
    "String.t()"
  end

  defp do_pretty_print({:binary, binary_parts}) do
    binary_parts = Enum.map_join(binary_parts, ", ", &do_pretty_print/1)
    "<<#{binary_parts}>>"
  end

  defp do_pretty_print({:binary, value, size}) do
    "<<#{do_pretty_print(value)} :: #{do_pretty_print(size)}>>"
  end

  defp do_pretty_print({:contract, {:args, args}, {:return, return}}) do
    "#{do_pretty_print(args)} :: #{do_pretty_print(return)}"
  end

  defp do_pretty_print({:empty_list, :paren}) do
    "()"
  end

  defp do_pretty_print({:empty_list, :square}) do
    "[]"
  end

  defp do_pretty_print({:empty_map}) do
    "%{}"
  end

  defp do_pretty_print({:function, {:args, args}, {:return, return}}) do
    "(#{do_pretty_print(args)} -> #{do_pretty_print(return)})"
  end

  defp do_pretty_print({:int, int}) do
    "#{int}"
  end

  defp do_pretty_print({:list, :paren, items}) do
    "(#{Enum.map_join(items, ", ", &do_pretty_print/1)})"
  end

  defp do_pretty_print({:list, :square, items}) do
    "[#{Enum.map_join(items, ", ", &do_pretty_print/1)}]"
  end

  defp do_pretty_print({:map_entry, key, value}) do
    "#{do_pretty_print(key)} => #{do_pretty_print(value)}"
  end

  defp do_pretty_print({:map, map_keys}) do
    struct_name = struct_name(map_keys)

    if struct_name do
      keys = Enum.reject(map_keys, &struct_name_entry?/1)

      "%#{struct_name}{#{Enum.map_join(keys, ", ", &do_pretty_print/1)}}"
    else
      "%{#{Enum.map_join(map_keys, ", ", &do_pretty_print/1)}}"
    end
  end

  defp do_pretty_print({:named_value, name, value}) do
    "#{do_pretty_print(name)} :: #{do_pretty_print(value)}"
  end

  defp do_pretty_print({:name, name}) do
    name
    |> to_string()
    |> strip_var_version()
  end

  defp do_pretty_print({nil}) do
    "nil"
  end

  defp do_pretty_print({:pattern, pattern_items}) do
    "<#{Enum.map_join(pattern_items, ", ", &do_pretty_print/1)}>"
  end

  defp do_pretty_print({:pipe_list, head, tail}) do
    "#{do_pretty_print(head)} | #{do_pretty_print(tail)}"
  end

  defp do_pretty_print({:range, from, to}) do
    "#{from}..#{to}"
  end

  defp do_pretty_print({:rest}) do
    "..."
  end

  defp do_pretty_print({:size, size}) do
    "size(#{do_pretty_print(size)})"
  end

  defp do_pretty_print({:tuple, tuple_items}) do
    "{#{Enum.map_join(tuple_items, ", ", &do_pretty_print/1)}}"
  end

  defp do_pretty_print({:type, type}) do
    "#{type}()"
  end

  defp do_pretty_print({:type, module, type}) do
    "#{strip_elixir(module)}.#{type}()"
  end

  defp do_pretty_print({:type_list, type, types}) do
    "#{type}#{do_pretty_print(types)}"
  end

  defp strip_elixir(string) do
    string
    |> to_string()
    |> String.trim("Elixir.")
  end

  defp strip_var_version(var_name) do
    String.replace(var_name, ~r/^V(.+)@\d+$/, "\\1")
  end

  defp struct_name(map_keys) do
    entry = Enum.find(map_keys, &struct_name_entry?/1)

    if entry do
      {:map_entry, _, {:atom, struct_name}} = entry
      strip_elixir(struct_name)
    end
  end

  defp struct_name_entry?({:map_entry, {:atom, '__struct__'}, _value}), do: true
  defp struct_name_entry?(_), do: false
end
