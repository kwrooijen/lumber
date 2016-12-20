defmodule Mix.Tasks.Lumber.Gen.Elm do
  use Mix.Task

  def run(args) do
    path = get_file_path(args)
    eval = EEx.eval_file("templates/elm.eex")
    File.write!(path, eval)
  end

  defp get_file_path([head | _]), do: head
  defp get_file_path([]) do
      opts = Application.get_env(:lumber, :elm, [])
      file = opts[:output_file] || "Lumber.elm"
      path = opts[:output_path] || "./"
      Path.join(file, path)
  end
end
