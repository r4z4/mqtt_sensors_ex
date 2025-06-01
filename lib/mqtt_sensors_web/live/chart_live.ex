defmodule MqttSensorsWeb.ChartLive do
  use MqttSensorsWeb, :live_view
  # import Ecto.Query
  alias MqttSensors.Repo
  # alias Sensor.Dh
  alias Sensor.Hc
  # alias Sensor.Joystick
  alias Phoenix.PubSub
  require Logger

  @topics ~w(dh_data hc_sr04_data keypad_press)

  @impl true
  def mount(_params, _session, socket) do
    Logger.info("This Process ->> #{inspect(self())}. Chart LiveView Socket = #{inspect(socket)}",
      ansi_color: :magenta
    )

    PubSub.subscribe(MqttSensors.PubSub, "hc_sr04_data")

    # For test data
    # assign(socket, :x_value, 0)
    # schedule_send_data(-1)

    {:ok,
     socket
     |> assign(:x_value, 0)
     |> stream(:data_stream, [])}
  end

  @impl true
  def render(assigns) do
    dbg(assigns.streams.data_stream)

    ~H"""
    <div class="w-full">
      <div class="container">
        <article id="plot_article_dh">
          <div
            phx-update="stream"
            class="axis"
            id="plot_x_dh"
            style="--c: 20; --cx: 1; --cy: 19; --dsize: 6;"
          >
            <%= for {id, sent} <- @streams.data_stream do %>
              <div class="dot" id={id} style={sent[:style]}></div>
            <% end %>
          </div>
        </article>
        <article id="plot_article_hc">
          <div class="axis" id="plot_x_hc" style="--c: 20; --cx: 1; --cy: 19; --dsize: 6;"></div>
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
  def handle_info(:clear_stream, socket) do
    IO.puts("Clearing Stream")

    # Before we clear it, save all records to DB. Batch update.
    persist_stream(socket.assigns.streams.data_stream)

    {:noreply,
     socket
     |> stream(:data_stream, [], reset: true)}
  end

  # This handles messages from other Elixir Processes
  # Match on topic - one handle_info for each topic to update LV state
  @impl true
  def handle_info({:update, %{topic: topic, time: time, data: data}}, socket) do
    {:ok, int, cm} = parse_string(data[:payload])
    y = int

    map = %{id: socket.assigns.x_value, style: "--x: #{socket.assigns.x_value}; --y: #{y}"}

    # IO.puts("X Value: #{socket.assigns.x_value}")
    # IO.puts("Map being Inserted")
    # dbg(map)

    at_capacity = socket.assigns.x_value >= 19

    next_x =
      if at_capacity do
        0
      else
        socket.assigns.x_value + 1
      end

    if at_capacity do
      send(self(), :clear_stream)
      # stream(socket, :data_stream, [], reset: true)
    end

    {:noreply,
     socket
     |> assign(:x_value, next_x)
     |> stream_insert(:data_stream, map)}
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
  defp parse_string(input_string) do
    case String.split(input_string, ";") do
      [part1, _part2] ->
        case String.split(part1, ": ") do
          [_str, int] -> {:ok, parseInt(int), parseInt(int)}
        end

      _ ->
        {:error, "Invalid string format. Expected 'In: X; Cm: Y'"}
    end
  end

  defp parseInt(str) do
    case String.to_integer(str) do
      # Handle cases where conversion fails, default to 0
      integer_val -> integer_val
      nil -> 0
    end
  end

  # Private
  # defp parse_topic(%{topic: topic}) do
  #   String.split(topic, "/", trim: true)
  # end

  defp persist_stream(stream) do
    # Prepend current record to the accumulator
    Enum.reduce([], stream, fn record, acc -> [map_stream_record(record) | acc] end)
    |> Repo.insert_all(Repo)
  end

  defp map_stream_record(record) do
    %Hc{time: record[:time], inches: record[:ins], centimeters: record[:cms]}
  end
end
