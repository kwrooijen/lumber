defmodule Lumber do
  def channels do
    lumbers = Lumber.all_output_channels ++ Lumber.all_input_channels
    lumbers
    |> Enum.map(&(elem(&1, 1)) |> elem(0))
    |> Enum.uniq
  end

  def all_input_channels do
    :code.all_loaded
    |> Enum.map(&(elem(&1, 0)))
    |> Enum.filter(&is_lumber_input_module?/1)
    |> Enum.map(&({&1, &1.lumber_inputs}))
  end

  def all_output_channels do
    :code.all_loaded
    |> Enum.map(&(elem(&1, 0)))
    |> Enum.filter(&is_lumber_output_module?/1)
    |> Enum.map(&({&1, &1.lumber_outputs}))
  end

  def all_output_types do
    Lumber.all_output_channels()
    |> Enum.map(&(elem(&1, 1) |> elem(1)))
    |> List.flatten
    |> Enum.map(&(elem(&1, 1)))
  end

  defp is_lumber_input_module?(module) do
    module.module_info[:exports]
    |> Enum.member?({:lumber_inputs, 0})
  end

  defp is_lumber_output_module?(module) do
    module.module_info[:exports]
    |> Enum.member?({:lumber_outputs, 0})
  end

  defmacro __using__(channel: channel) do
    quote do
      require Logger
      import Lumber
      @lumber_channel unquote(channel)
    end
  end

  def def_lumber_input(lumber) do
    quote do
      lumbers = Module.get_attribute(__MODULE__, :lumber_inputs) || []
      Module.put_attribute(__MODULE__, :lumber_inputs, [unquote(lumber) | lumbers])
      def lumber_inputs do
        {@lumber_channel, @lumber_inputs}
      end
      defoverridable [lumber_inputs: 0]
    end
  end

  def def_lumber_output(lumber) do
    quote do
      lumbers = Module.get_attribute(__MODULE__, :lumber_outputs) || []
      Module.put_attribute(__MODULE__, :lumber_outputs, [unquote(lumber) | lumbers])
      def lumber_outputs do
        {@lumber_channel, @lumber_outputs}
      end
      defoverridable [lumber_outputs: 0]
    end
  end

  defmacro deftype(module, vars, block) do
    quote do
      vars = unquote(vars)
      defmodule unquote(module) do
        use Murk
         vars |> Enum.map(fn({key, value}) ->
          Module.put_attribute(unquote(module), key, value)
        end)
        defmurk unquote(block)
      end
    end
  end

  defmacro deftype(module, block) do
    quote do
      defmodule unquote(module) do
        use Murk
        defmurk unquote(block)
      end
    end
  end

  defmacro defin(event, module, payload, socket, do: block) do
    quote do
      unquote(def_lumber_input({event, module}))
      def handle_in(unquote(event), payload_var, unquote(socket)) do
        struct = unquote(module).new!(payload_var)
        if struct |> Murk.valid? do
          unquote(payload) = struct
          unquote(block)
        else
          Logger.error("Invalid defin struct #{inspect struct}")
          {:noreply, unquote(socket)}
        end
      end
    end
  end

  defmacro defout(event, module, block) do
    quote do
      defmodule unquote(module) do
        use Murk
        defmurk unquote(block)
      end
      intercepts = Module.get_attribute(__MODULE__, :phoenix_intercepts) || []
      Module.put_attribute(__MODULE__, :phoenix_intercepts, [unquote(event) | intercepts])
      unquote(def_lumber_output({event, module}))
      def handle_out(unquote(event), payload, socket) do
        struct = unquote(module).new!(payload)
        if Murk.valid?(struct) do
          push(socket, unquote(event), struct)
        else
          Logger.error("Invalid defout struct #{inspect struct}")
        end
        {:noreply, socket}
      end
    end
  end

  defmacro defout(event, module, payload, socket, do: block) do
    quote do
      intercept = Module.get_attribute(__MODULE__, :phoenix_intercepts) || []
      Module.put_attribute(__MODULE__, :phoenix_intercepts, [unquote(event) | intercepts])
      unquote(def_lumber_output({event, module}))
      def handle_out(unquote(event), payload_var, unquote(socket)) do
        struct = unquote(module).new!(payload_var)
        if struct |> Murk.valid? do
          unquote(payload) = struct
          unquote(block)
        else
          Logger.error("Invalid defout struct #{inspect struct}")
          {:noreply, unquote(socket)}
        end
      end
    end
  end
end
