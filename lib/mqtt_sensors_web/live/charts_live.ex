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

  @topics ~w(dh_data hc_sr04_data keypad_press photoresistor rotary_encoder rgb gyro ir)

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
     |> assign(:border_map, %{one: nil, two: nil, three: nil, four: nil, five: nil, six: nil})
     |> assign(:hc_sr04_data_x_value, 0)
     |> stream(:hc_sr04_data_stream, [])
     |> assign(:photoresistor, 0)
     |> assign(:hsl, "hsl(0, 100%, 0%)")
     |> assign(:encoder_rotate, 90.0)
     |> assign(:encoder_value, 0)
     |> assign(:rgb_css, "rgb(0,0,0)")
     |> stream(:gyro_stream, [])
     |> assign(:dh_data_x_value, 0)
     |> stream(:dh_data_stream, [])}
  end

  # class="border-2 border-solid p-4"

  @impl true
  def render(assigns) do
    # dbg(assigns.streams.dh_data_stream)
    # dbg(assigns.streams.hc_sr04_data_stream)

    ~H"""
    <h1 class="text-center text-white">Sensor Readings</h1>
    <div class="w-full">
      <div class="container">
        <article id="plot_article_hc" class={@border_map[:one]}>
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
        <article id="plot_article_dh" class={@border_map[:two]}>
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
      <div class="container">
        <article class={@border_map[:three]}>
          <div id="photoresistor">
            <div style={"margin: auto; width: 100px; height: 100px; background-color: #{@hsl}; border-radius: 50%"}>
            </div>
            <div class="m-auto text-center text-white">{@photoresistor}</div>
          </div>
        </article>
        <article class={@border_map[:four]}>
          <div id="rotary_encoder" class={"gauge #{if @encoder_value == 1, do: 'animate-ping'}"}>
            <div class="arc"></div>
            <div
              class="pointer"
              style={"transform: rotate(#{@encoder_rotate}deg) translateX(2px) translateY(-6px)"}
              ;
            >
            </div>
            <div class="mask"></div>
            <div class="label">{@encoder_value}</div>
          </div>
        </article>
      </div>
      <div class="container">
        <article class={@border_map[:five]}>
          <div id="rgb">
            <div style={"margin: auto; width: 100px; height: 100px; background-color: #{@rgb_css}; border-radius: 50%"}>
            </div>
          </div>
        </article>
        <article id="gyro" class={@border_map[:six]}>
          <div phx-update="stream" id="gyro_data">
            <%= for {id, sent} <- @streams.gyro_stream do %>
              <div class="text-xs" id={id}>{sent[:data]}</div>
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

  def handle_info({:update, %{topic: "ir", data: data}}, socket) do
    # Get current border
    key = get_current_border(socket.assigns.border_map)
    # Determine next border based on IR input
    next = get_next_value(key, String.to_existing_atom(data))
    # test - not grid will not need p-4
    border_style = "border-2 border-solid p-4"

    new_map =
      if next do
        socket.assigns.border_map
        |> Map.put(key, nil)
        |> Map.put(next, border_style)
      else
        socket.assigns.border_map
      end

    dbg(new_map)

    {:noreply,
     socket
     |> assign(:border_map, new_map)}
  end

  @impl true
  def handle_info({:clear_stream, topic}, socket) do
    IO.puts("Clearing Stream")

    # Before we clear it, save all records to DB. Batch update.
    unless topic == "gyro" do
      GenServer.cast(module_name(topic), :persist_stream)
    end

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
  def handle_info({:update, %{topic: "photoresistor", data: data}}, socket) do
    brightness =
      case data do
        0 -> 0
        _ -> Kernel.trunc(data / 10)
      end

    color = "hsl(90 100% #{brightness}%)"

    {:noreply,
     socket
     |> assign(:photoresistor, data)
     |> assign(:hsl, color)}
  end

  @impl true
  def handle_info({:update, %{topic: "rotary_encoder", data: data}}, socket) do
    IO.puts("LV Handle Info Rotary - Counter => #{data[:ctr]}")
    speed = data[:ctr]
    angle = 90 + speed * 0.9

    {:noreply,
     socket
     |> assign(:encoder_rotate, angle)
     |> assign(:encoder_value, speed)}
  end

  @impl true
  def handle_info({:update, %{topic: "gyro", data: data}}, socket) do
    IO.puts("LV Handle Info Gyro - #{data[:id]} && #{data[:data]}")

    if Kernel.rem(data[:id], 20) == 0 do
      send(self(), {:clear_stream, "gyro"})
    end

    {:noreply,
     socket
     |> stream(:gyro_stream, [data])}
  end

  @impl true
  def handle_info({:update, %{topic: "rgb", data: data}}, socket) do
    IO.puts("LV Handle Info RGB")
    dbg(data)
    rgb_css = "rgb(#{data[:r]}, #{data[:g]}, #{data[:b]})"

    {:noreply,
     socket
     |> assign(:rgb_css, rgb_css)}
  end

  @impl true
  def handle_info({:update, %{topic: topic, time: time, data: data}}, socket) do
    IO.puts("LV Handle Info Topic = #{topic}")
    id = socket.assigns[String.to_existing_atom("#{topic}_x_value")]
    # dbg(id)

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

  defp get_current_border(border_map) do
    # Find the not nil
    res = Enum.find(border_map, fn {_k, v} -> v end)

    IO.puts("Get Current Border Res")
    dbg(res)

    if res do
      {key, value} = res
      key
    else
      nil
    end
  end

  defp get_next_value(key, ir_signal) do
    # All nil on start, so just start at top left
    IO.puts("Get Next Value Vars")
    dbg(key)
    dbg(ir_signal)

    if !key do
      :one
    else
      signal_map = %{
        one: %{left: nil, up: nil, right: :two, down: :three, menu: nil, play: nil, center: nil},
        two: %{left: :one, up: nil, right: nil, down: :four, menu: nil, play: nil, center: nil},
        three: %{
          left: nil,
          up: :one,
          right: :four,
          down: :five,
          menu: nil,
          play: nil,
          center: nil
        },
        four: %{left: :three, up: :two, right: nil, down: :six, menu: nil, play: nil, center: nil},
        five: %{left: nil, up: :three, right: :six, down: nil, menu: nil, play: nil, center: nil},
        six: %{left: :five, up: :four, right: nil, down: nil, menu: nil, play: nil, center: nil}
      }

      moves = signal_map[key]
      dbg(moves)
      moves[ir_signal]
    end
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
