defmodule MqttSensorsWeb.ChartsLive do
  use MqttSensorsWeb, :live_view
  # import Ecto.Query
  alias MqttSensors.Repo
  # alias MqttSensors.Sensor.Dh

  alias HcData
  alias MqttSensors.UltrasonicSensor
  # alias MqttSensors.Sensor.Joystick
  alias Phoenix.PubSub
  require Logger

  @topics ~w(dh_data hc_sr04_data keypad_press)

  @impl true
  def mount(_params, _session, socket) do
    Logger.info("This Process ->> #{inspect(self())}. Chart LiveView Socket = #{inspect(socket)}",
      ansi_color: :magenta
    )

    for topic <- @topics do
      IO.puts("Mounting for #{topic}")
      PubSub.subscribe(MqttSensors.PubSub, topic)
      # assign(socket, String.to_atom("#{topic}_x_value"), 0)
      # stream(socket, String.to_atom("#{topic}_stream"), [])
    end

    # For test data
    # assign(socket, :x_value, 0)
    # schedule_send_data(-1)

    # {:ok, socket}

    {:ok,
     socket
     |> assign(:hc_sr04_data_x_value, 0)
     |> stream(:hc_sr04_data_stream, [])
     |> assign(:dh_data_x_value, 0)
     |> stream(:dh_data_stream, [])}
  end

  @impl true
  def render(assigns) do
    dbg(assigns.streams.dh_data_stream)
    dbg(assigns.streams.hc_sr04_data_stream)

    ~H"""
    <div class="w-full">
      <div class="container">
        <article id="plot_article_hc">
          <div
            phx-update="stream"
            class="axis"
            id="plot_x_hc"
            style="--c: 20; --cx: 1; --cy: 19; --dsize: 6;"
          >
            <%= for {id, sent} <- @streams.hc_sr04_data_stream do %>
              <div class="dot" id={id} style={sent[:style]}></div>
            <% end %>
          </div>
        </article>
        <article id="plot_article_dh">
          <div
            phx-update="stream"
            class="axis"
            id="plot_x_dh"
            style="--c: 20; --cx: 1; --cy: 19; --dsize: 6;"
          >
            <%= for {id, sent} <- @streams.dh_data_stream do %>
              <div class="dot" id={id} style={sent[:style]}></div>
            <% end %>
          </div>
        </article>
      </div>
    </div>
    """
  end

  # This handles messages from other Elixir Processes
  # def handle_info({:test_update, %{topic: topic, time: time, x: x, y: y}}, socket) do
  #   IO.puts(topic)
  #   map = %{id: time, style: "--x: #{x}; --y: #{y}"}
  #
  #   schedule_send_data(x)
  #
  #   {:noreply,
  #    socket
  #    # |> stream_insert(String.to_existing_atom("#{topic}_stream"), map, limit: -10)
  #    |> stream_insert(:data_stream, map)}
  # end

  # publish #=> %{
  #   dup: false,
  #   via: #Port<0.37>,
  #   payload: "Temp: 27.0; Humidity: 54.0",
  #   topic: "esp32/sensor_data",
  #   properties: :undefined,
  #   qos: 0,
  #   retain: false,
  #   packet_id: :undefined,
  #   client_pid: #PID<0.674.0>
  # }

  @impl true
  def handle_info({:clear_stream, topic}, socket) do
    IO.puts("Clearing Stream")

    # Before we clear it, save all records to DB. Batch update.
    GenServer.cast(module_name(topic), :persist_stream)

    {:noreply,
     socket
     |> stream(String.to_existing_atom("#{topic}_stream"), [], reset: true)}
  end

  defp module_name(topic) do
    IO.puts("Module Name Topic => #{topic}")

    case topic do
      "hc_sr04_data" -> UltrasonicSensor
      "dh_data" -> DhTemperature
      "keypad_press" -> KeypadPress
      _ -> IO.puts("Error: Invalid Topic")
    end
  end

  # This handles messages from other Elixir Processes
  # Match on topic - one handle_info for each topic to update LV state
  @impl true
  def handle_info({:update, %{topic: topic, time: time, data: data}}, socket) do
    IO.puts("LV Handle Info Topic = #{topic}")
    id = socket.assigns[String.to_existing_atom("#{topic}_x_value")]
    dbg(id)

    maps =
      case topic do
        "hc_sr04_data" ->
          [
            %{
              id: id,
              style: "--x: #{id}; --y: #{data[:ins]}; --dcolor: green"
            }
          ]

        "dh_data" ->
          [
            %{
              id: Integer.to_string(id) <> "_t",
              style: "--x: #{id}; --y: #{data[:temp]}; --dcolor: red"
            },
            %{
              id: Integer.to_string(id) <> "_h",
              style: "--x: #{id}; --y: #{data[:hum]}; --dcolor: blue"
            }
          ]

        "keypad_press" ->
          [%{}]

        _ ->
          IO.puts("Error: Invalid Update")
      end

    # IO.puts("X Value: #{socket.assigns.x_value}")
    # IO.puts("Map being Inserted")
    # dbg(map)

    at_capacity = socket.assigns[String.to_existing_atom("#{topic}_x_value")] >= 19

    next_x =
      if at_capacity do
        0
      else
        socket.assigns[String.to_existing_atom("#{topic}_x_value")] + 1
      end

    if at_capacity do
      send(self(), {:clear_stream, topic})
      # stream(socket, :data_stream, [], reset: true)
    end

    # Using stream/4 vs stream_insert to insert multiple
    {:noreply,
     socket
     |> assign(String.to_existing_atom("#{topic}_x_value"), next_x)
     |> stream(String.to_existing_atom("#{topic}_stream"), maps)}
  end

  @impl true
  def handle_info({:DOWN, _reference, _process, _pid, _status}, socket) do
    IO.puts("Down Received. Task Destroyed.")
    {:noreply, socket}
  end

  # defp schedule_send_data(x_value) do
  #   # Send every 5 secs
  #   x = x_value + 1
  #   random_y = :rand.uniform(20)
  #
  #   Process.send_after(
  #     self(),
  #     {:test_update, %{topic: "whatever", time: x, x: x, y: random_y}},
  #     5000
  #   )
  # end

  # Only getting Inches value for now - which is why two int
  # defp parse_string(input_string) do
  #   case String.split(input_string, ";") do
  #     [part1, part2] ->
  #       # [_str, inches] = String.split(part1, ": ")
  #       # ins = parseInt(int)
  #       ins = String.split(part1, ": ") |> Enum.at(1) |> parseInt()
  #       # [_str, centis] = String.split(part2, ": ")
  #       # cms = parseInt(centis)
  #       cms = String.split(part2, ": ") |> Enum.at(1) |> parseInt()
  #
  #       # {:ok, String.split(part1, ": ") |> Enum.at(1) |> parseInt(), String.split(part2, ": ") |> Enum.at(1) |> parseInt())
  #       {:ok, ins, cms}
  #
  #     _ ->
  #       {:error, "Invalid string format. Expected 'In: X; Cm: Y'"}
  #   end
  # end
  #
  # defp parseInt(str) do
  #   case String.to_integer(str) do
  #     # Handle cases where conversion fails, default to 0
  #     integer_val -> integer_val
  #     nil -> 0
  #   end
  # end

  # Private
  # defp parse_topic(%{topic: topic}) do
  #   String.split(topic, "/", trim: true)
  # end
end
