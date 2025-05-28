defmodule MqttSensorsWeb.SensorsLive do
  use MqttSensorsWeb, :live_view
  # import Ecto.Query
  # alias MqttSensors.Repo
  alias Phoenix.PubSub
  require Logger

  @topics ~w(dh_data hc_sr04_data keypad_press)

  @impl true
  def mount(_params, _session, socket) do
    Logger.info("This Process ->> #{inspect(self())}. Chat Live Socket = #{inspect(socket)}",
      ansi_color: :magenta
    )

    # PubSub.subscribe(MqttSensors.PubSub, @topic)
    for topic <- @topics, do: PubSub.subscribe(MqttSensors.PubSub, topic)

    {:ok,
     socket
     # |> sync_stream(:dh_data, DhData)
     |> assign(:chart_svg, nil)
     |> assign(:dh_data, nil)
     |> assign(:hc_sr04_data, nil)
     |> assign(:latest_data, [])
     |> assign(:keypad_press, nil)
     |> stream(:keypad_press_stream, [])
     |> stream(:dh_data_stream, [])
     |> stream(:hc_sr04_data_stream, [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full">
      <div>
        <p>HCSR04 Data: {@hc_sr04_data}</p>
        <p>Dh Data: {@dh_data}</p>
        <p>Latest Key Pressed: {@keypad_press}</p>
      </div>
      <div>
        {@chart_svg}
      </div>
      <div class="flex flex-row h-screen bg-gray-100">
        <div class="flex-1 bg-gradient-to-r from-indigo-500 to-purple-500 p-4">
          <!-- List 1 Content -->
          <h2 class="text-xl font-bold mb-4">DH11</h2>
          <ul id="dh_ul" phx-update="stream" class="text-gray-700">
            <li
              :for={{id, sent} <- @streams.dh_data_stream}
              id={id}
              class="text-sm hover:text-indigo-600"
              data-role="dh"
            >
              {sent[:id]}: {sent[:data][:payload]}
            </li>
          </ul>
        </div>
        <div class="flex-1 bg-gradient-to-r from-indigo-500 to-purple-500 p-4">
          <!-- List 2 Content -->
          <h2 class="text-xl font-bold mb-4">HCSR-04</h2>
          <ul id="hc_ul" phx-update="stream" class="text-gray-700">
            <%= for {id, sent} <- @streams.hc_sr04_data_stream do %>
              <li id={id} class="text-sm hover:text-indigo-600" data-role="dh">
                {sent[:id]}: {sent[:data][:payload]}
              </li>
            <% end %>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  def handle_info({:clear, %{topic: topic, time: time, data: data}}, socket) do
    IO.puts("Clearing DH")
    dbg(socket.assigns.streams[:dh_data_stream])

    {:noreply,
     socket
     |> stream(:hc_sr04_data_stream, [], reset: true)
     |> stream(:dh_data_stream, [], reset: true)}
  end

  # This handles messages from other Elixir Processes
  def handle_info({:update, %{topic: topic, time: time, data: data}}, socket) do
    map = %{id: time, data: data}

    data = [["Apples", 10], ["Bananas", 12], ["Pears", 2]]
    dataset = Contex.Dataset.new(data)
    chart = Contex.Plot.new(dataset, Contex.BarChart, 600, 400)

    latest_key =
      if topic == "keypad_press" do
        IO.puts("Received Key Press")
        key = data[:payload]

        # if key == "8" do
        #   IO.puts("Resetting DH")
        #
        #   # Hide Sensor Output from DH? Stop it via GenServer? (this might be more tricky - starting and stopping)
        #   stream(socket, :dh_data_stream, [], reset: true)
        # end

        data
      else
        nil
      end

    {:noreply,
     socket
     |> assign(String.to_existing_atom(topic), data[:payload])
     |> assign(:chart_svg, Contex.Plot.to_svg(chart))
     # TODO: Make stream?
     # |> stream_insert(String.to_existing_atom("#{topic}_stream"), map, limit: -10)
     |> stream_insert(String.to_existing_atom("#{topic}_stream"), map)}
  end

  @impl true
  def handle_info({:DOWN, _reference, _process, _pid, _status}, socket) do
    IO.puts("Down Received. Task Destroyed.")
    {:noreply, socket}
  end

  # Private
  # defp parse_topic(%{topic: topic}) do
  #   String.split(topic, "/", trim: true)
  # end
end
