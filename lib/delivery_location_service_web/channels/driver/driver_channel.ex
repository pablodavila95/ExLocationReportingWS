defmodule DeliveryLocationServiceWeb.DriverChannel do
  @moduledoc """
  Provides the Channel for a driver to continuosly report its location.
  It also notifies the admin and any subscribed restaurant (it also forces subscription when accepting orders or the opposite)
  """
  use DeliveryLocationServiceWeb, :channel
  alias DeliveryLocationService.Location
  alias DeliveryLocationService.Locations
  alias DeliveryLocationService.LocationServer
  alias DeliveryLocationService.LocationSupervisor
  alias DeliveryLocationServiceWeb.Endpoint
  alias DeliveryLocationServiceWeb.Presence
  require Logger

  def join("driver:" <> driver_id, %{"lat" => lat, "long" => long}, socket) do
    Logger.info(inspect(Integer.to_string(socket.assigns.driver_id)))
    Logger.info(inspect(driver_id))

    if Integer.to_string(socket.assigns.driver_id) == driver_id do
      case LocationServer.location_data_pid(driver_id) do
        pid when is_pid(pid) ->
          Logger.info("GS already existed for driver #{driver_id}")

          existing_lat = Map.get(Map.get(get_state(driver_id), :coordinates), :lat)
          existing_long = Map.get(Map.get(get_state(driver_id), :coordinates), :long)
          LocationServer.update_order(driver_id, Map.get(get_state(driver_id), :current_order))

          Logger.info("Reusing existing coordinates.")
          send(self(), {:after_join, driver_id, %{lat: existing_lat, long: existing_long}})
          {:ok, socket}

        nil ->
          Logger.info("Created a new GS for #{driver_id}")

          LocationSupervisor.start_location(%Location{
            driver_id: driver_id,
            restaurant_id: nil,
            coordinates: %{lat: nil, long: nil},
            timestamp: Time.utc_now(),
            current_order: nil
          })

          # Logger.info("Using default coordinates from frontend: {lat: #{lat}, long: #{long}")
          send(self(), {:after_join, driver_id, %{"lat" => lat, "long" => long}})
          {:ok, socket}
      end
    else
      Logger.info("refusing connection because id doesnt match server reply")
      {:error, %{reason: "error while authenticating. ID doesn't match with server reply"}}
    end
  end

  def handle_info({:after_join, driver_id, coordinates}, socket) do
    # Update coordinates after join. Assign to a value.
    LocationServer.update_coordinates(driver_id, coordinates)
    Logger.info("Socket topic is #{socket.topic}")

    # Endpoint.subscribe("admins:#{socket.assigns.customer_company}")
    Endpoint.broadcast!("admins:#{socket.assigns.customer_company}", "driver_connected", %{
      "driver_id" => socket.assigns.driver_id
    })

    # updated_coordinates =
    #   LocationServer.location_data_pid(driver_id) |> :sys.get_state() |> Map.get(:coordinates)

    # Push logs to admins and current client
    push(socket, "logs", %{
      message: "Connected to Channel successfully"
    })

    Endpoint.broadcast!("admins:#{socket.assigns.customer_company}", "logs", %{
      message: "Driver #{driver_id} just connected"
    })

    push_data_to_admins(driver_id, socket)

    # Presence stuff
    {:ok, _} =
      Presence.track(socket, "driver:#{driver_id}", %{
        online_at: inspect(Time.utc_now()),
        is_delivering: inspect(Locations.is_delivering?(driver_id))
      })

    Endpoint.broadcast!(
      "admins:#{socket.assigns.customer_company}",
      "presence_state",
      Presence.list(socket)
    )

    Logger.info("A driver connected")
    {:noreply, socket}
  end

  def handle_in("presence_diff", diff, socket) do
    Endpoint.broadcast!("admins:#{socket.assigns.customer_company}", "presence_diff", diff)
    {:noreply, socket}
  end

  def handle_in("update_location", new_coordinates, socket) do
    %{"lat" => lat, "long" => long} = new_coordinates
    Logger.info("Updating location")

    "driver:" <> driver_id = socket.topic
    LocationServer.update_coordinates(driver_id, %{lat: lat, long: long})

    current_state =
      LocationServer.location_data_pid(driver_id)
      |> :sys.get_state()

    Logger.info("Driver state updated")

    current_restaurant_id =
      current_state
      |> Map.get(:restaurant_id)

    if current_restaurant_id != nil do
      Logger.info("Will send to restaurant #{current_restaurant_id}")

      Endpoint.broadcast!(
        "restaurant:#{current_restaurant_id}",
        "driver_update",
        Map.from_struct(current_state)
      )
    else
      Endpoint.broadcast!("restaurant:#{current_restaurant_id}", "finished_delivering", %{
        driver_id: driver_id
      })
    end

    push_data_to_admins(driver_id, socket)

    {:noreply, socket}
  end

  def handle_in(
        "accepted_order",
        %{"restaurant_id" => restaurant_id, "order_id" => order_id},
        socket
      ) do
    "driver:" <> driver_id = socket.topic
    LocationServer.update_restaurant(driver_id, restaurant_id)
    LocationServer.update_order(driver_id, order_id)

    Endpoint.broadcast!("restaurant:#{restaurant_id}", "driver_delivering", %{
      driver_id: driver_id
    })

    push_data_to_admins(driver_id, socket)

    {:noreply, socket}
  end

  def handle_in(
        "finished_order",
        %{"restaurant_id" => restaurant_id_client, "order_id" => order_id_client},
        socket
      ) do
    Logger.info("Order is finished. Removing...")
    "driver:" <> driver_id = socket.topic

    restaurant_id_server = LocationServer.view(driver_id).restaurant_id
    order_id_server = LocationServer.view(driver_id).current_order

    if restaurant_id_client == restaurant_id_server and order_id_client == order_id_server do
      Endpoint.broadcast!("restaurant:#{restaurant_id_server}", "finished_delivering", %{
        driver_id: driver_id
        # order_id: order_id_server
      })
    end

    LocationServer.update_restaurant(driver_id, nil)
    LocationServer.update_order(driver_id, nil)

    push_data_to_admins(driver_id, socket)

    {:noreply, socket}
  end

  def handle_in("subscription_request", %{"restaurant_id" => restaurant_id}, socket) do
    "driver:" <> driver_id = socket.topic

    registered_restaurant_id =
      LocationServer.location_data_pid(driver_id)
      |> :sys.get_state()
      |> Map.get(:restaurant_id)

    if registered_restaurant_id == restaurant_id do
      Endpoint.broadcast!("restaurant:#{restaurant_id}", "driver_delivering", %{
        driver_id: driver_id
      })
    end
  end

  def handle_in("ping", _params, socket) do
    push(socket, "pong", %{msg: "pong!"})
    {:reply, :ok, socket}
  end

  defp get_state(driver_id) do
    LocationServer.location_data_pid(driver_id)
    |> :sys.get_state()
    |> Map.from_struct()
  end

  defp push_data_to_admins(driver_id, socket) do
    data = get_state(driver_id)
    Logger.info("Sending data to admins.")
    Logger.info(inspect(data))

    Endpoint.broadcast!("admins:#{socket.assigns.customer_company}", "driver_update", data)
  end

  # Only for reference
  # If we wanted to extract data from the socket
  # defp data_we_want(socket) do
  #  socket.assigns.data_we_want
  # end
end
