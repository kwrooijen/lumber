defmodule Lumber.Gen.Elm do
  @opts Application.get_env(:lumber, :elm, [])
  @fields [:string, :float, :list]

  def channels do
    Lumber.channels
    |> Enum.map(&( "\"#{&1}\""))
    |> Enum.join(", ")
  end

  def socket_on do
    Lumber.all_output_channels
    |> Enum.map(&(elem(&1, 1)))
    |> Enum.map(&make_socket/1)
    |> List.flatten
    |> Enum.join("    |> ")
  end

  def make_socket({channel, list}) do
    list |> Enum.map(fn({event, record}) ->
      record = record |> normalize_record
      """
      Phoenix.Socket.on "#{event}" ("#{channel}:" ++ addition) (msg << Phx#{record})
      """
    end)
  end

  def gen_phoenix_type do
    Lumber.all_output_types()
    |> Enum.map(&normalize_record/1)
    |> Enum.map(&("Phx" <> &1 <> " Encode.Value"))
    |> Enum.join("\n    | ")
  end

  def result_types do
    Lumber.all_output_channels()
    |> Enum.map(&from_tup/1)
    |> List.flatten
    |> Enum.sort
  end

  def record_fields(fields) do
    fields
    |> Enum.map(&field_to_string/1)
    |> Enum.join(", ")
  end

  defp field_to_string({name, type, opts}) do
    name = name
    |> Atom.to_string
    |> lower_camelize
    type = type
    |> parse_type
    |> add_maybe(opts[:required])
    "\n    #{name} : #{type}"
  end

  def to_parse({_mod, {channel, fields}}) do
    Enum.map(fields, &(to_parse_item(channel, &1)))
    |> Enum.join("\n\n")
  end
  def to_parse_item(channel, {event, record}) do
    record = record |> normalize_record
    name = "#{channel |> String.capitalize}#{event |> normalize_event}"
      """
              Phx#{record} payload ->
                  decodeGeneric
                      ("#{channel}", "#{event}")
                      #{name}
                      decode#{record}
                      payload
      """
  end


  def fields_to_decode(fields) do
    fields
    |> Enum.map(&field_to_decode/1)
    |> Enum.join(" |: ")
  end

  def field_to_decode({name, type, opts}) do
    type = type |> type_to_decoder(opts)
    "( \"#{name}\" := #{type})"
  end

  def fields_to_encode(fields) do
    fields
    |> Enum.map(&field_to_encode/1)
    |> Enum.join(", ")
  end

  def field_to_encode({name, type, opts}) do
    type = type |> type_to_encoder(opts)
    name_camelized = name |> lower_camelize
    "\n    ( \"#{name}\", #{type} obj.#{name_camelized})"
  end

  def type_to_encoder([type], opts) do
    "Encode.list <| List.map (#{type_to_encoder(type, opts)})"
    |> add_maybe_encoder(opts[:required])
  end
  def type_to_encoder(:atom, opts) do
    "Encode.string"
    |> add_maybe_encoder(opts[:required])
  end
  def type_to_encoder(:integer, opts) do
    "Encode.int"
    |> add_maybe_encoder(opts[:required])
  end
  def type_to_encoder(:boolean, opts) do
    "Encode.bool"
    |> add_maybe_encoder(opts[:required])
  end
  def type_to_encoder(type, opts) when type in @fields do
    "Encode.#{type}"
    |> add_maybe_encoder(opts[:required])
  end
  def type_to_encoder(type, opts) do
    type = type |> normalize_record
    "encode#{type}"
    |> add_maybe_encoder(opts[:required])
  end

  def type_to_decoder([type], opts) do
    "Decode.list (#{type_to_decoder(type, opts)})"
    |> add_maybe_decoder(opts[:required])
  end
  def type_to_decoder(:atom, opts) do
    "Decode.string"
    |> add_maybe_decoder(opts[:required])
  end
  def type_to_decoder(:integer, opts) do
    "Decode.int"
    |> add_maybe_decoder(opts[:required])
  end
  def type_to_decoder(:boolean, opts)  do
    "Decode.bool"
    |> add_maybe_decoder(opts[:required])
  end
  def type_to_decoder(type, opts) when type in @fields do
    "Decode.#{type}"
    |> add_maybe_decoder(opts[:required])
  end
  def type_to_decoder(type, opts) do
    type = type |> normalize_record
    "decode#{type}"
    |> add_maybe_decoder(opts[:required])
  end


  def lowercase_first(string) do
    {c, rest} = String.split_at(string, 1)
    String.downcase(c) <> rest
  end

  defp parse_type(type) when type in [:string, :atom], do: "String"
  defp parse_type(:integer), do: "Int"
  defp parse_type(:float), do: "Float"
  defp parse_type(:boolean), do: "Bool"
  defp parse_type([type]), do: "List (#{parse_type(type)})"
  defp parse_type(elixir), do: normalize_record(elixir)

  defp add_maybe(type, true), do: type
  defp add_maybe(type, false), do: "Maybe (#{type})"

  defp add_maybe_encoder(type, true), do: type
  defp add_maybe_encoder(type, false), do: "maybeEncode #{type}"

  defp add_maybe_decoder(type, true), do: type
  defp add_maybe_decoder(type, false), do: "maybeDecode #{type}"


  defp from_tup({_module, {channel, list}}) do
    channel = channel |> String.capitalize
    Enum.map(list, &(output_to_string(&1, channel)))
  end

  defp output_to_string({event, record}, channel) do
    event = event |> normalize_event
    record = record |> normalize_record
    "#{channel}#{event} #{record}"
  end

  defp normalize_event(event) do
    event
    |> String.replace(":", "_")
    |> Macro.camelize
  end

  def normalize_record(record) do
    replaces = @opts[:replace_record] || []
    record = record
    |> Atom.to_string
    |> String.replace(".", "")
    Enum.reduce(replaces, record, fn({old, new}, acc) -> String.replace(acc, old, new) end)
  end

  defp lower_camelize(""), do: ""
  defp lower_camelize(atom) when is_atom(atom) do
    atom
    |> Atom.to_string
    |> lower_camelize
  end
  defp lower_camelize(string) do
      {head, tail} = string
      |> Macro.camelize
      |> String.split_at(1)
      String.downcase(head) <> tail
  end
end
