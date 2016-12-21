defmodule Mix.Tasks.Lumber.Gen.Elm do
  use Mix.Task

  def run(args) do
    file = Application.app_dir(:lumber, "priv/templates/elm.eex")
    eval = EEx.eval_file(file)
    path = get_file_path(args)
    File.write!(path, eval)
  end

  defp get_file_path([head | _]), do: head
  defp get_file_path([]) do
      opts = Application.get_env(:lumber, :elm, [])
      path = opts[:output_path] || "./"
      file = opts[:output_file] || "Lumber.elm"
      Path.join(path, file)
  end
end
