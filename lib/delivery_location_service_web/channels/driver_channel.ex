defmodule DeliveryLocationServiceWeb.DriverChannel do
  @moduledoc """
  Provides the Channel for a driver to continuosly report its location.
  It also notifies the admin and any subscribed restaurant (it also forces subscription when accepting orders or the opposite)
  """
  use DeliveryLocationServiceWeb, :channel
  alias DeliveryLocationService.LocationServer
  alias DeliveryLocationService.LocationsHelper
  alias DeliveryLocationServiceWeb.Endpoint
  alias DeliveryLocationServiceWeb.Presence
  require Logger

  # TODO don't allow input of empty locations
  # TODO warn admins of large variations between locations

  def join("driver:" <> driver_id, %{"lat" => lat, "long" => long}, socket) do
    if socket.assigns.driver_id == driver_id do
      case LocationServer.location_data_pid(driver_id) do
        pid when is_pid(pid) ->
          Logger.info("GS already existed for driver #{driver_id}")

          # %{coordinates: %{"lat" => existing_lat, "long" => existing_long}} = get_state(driver_id)
          existing_lat = Map.get(Map.get(get_state(driver_id), :coordinates), :lat)
          existing_long = Map.get(Map.get(get_state(driver_id), :coordinates), :long)

          Logger.info("Reusing existing coordinates.")
          send(self(), {:after_join, driver_id, %{lat: existing_lat, long: existing_long}})
          {:ok, socket}

        nil ->
          Logger.info("Created a new GS for #{driver_id}")
          LocationServer.create(driver_id)
          # Logger.info("Using default coordinates from frontend: {lat: #{lat}, long: #{long}")
          send(self(), {:after_join, driver_id, %{"lat" => lat, "long" => long}})
          {:ok, socket}
      end
    end
    Logger.info("refusing connection because id doesnt match server reply")
    {:error, %{reason: "error while authenticating. ID doesn't match with server reply"}}
  end

  def handle_info({:after_join, driver_id, coordinates}, socket) do
    # Update coordinates after join. Assign to a value.
    LocationServer.update_coordinates(driver_id, coordinates)

    # updated_coordinates =
    #   LocationServer.location_data_pid(driver_id) |> :sys.get_state() |> Map.get(:coordinates)

    # Push logs to admins and current client
    push(socket, "logs", %{
      message: "Connected to Channel successfully"
    })

    Endpoint.broadcast!("admins", "logs", %{message: "Driver #{driver_id} just connected"})

    push_data_to_admins(driver_id)

    # Presence stuff
    {:ok, _} =
      Presence.track(socket, "driver:#{driver_id}", %{
        online_at: inspect(Time.utc_now()),
        is_delivering: inspect(LocationsHelper.is_delivering?(driver_id))
      })

    Endpoint.broadcast!("admins", "presence_state", Presence.list(socket))

    Logger.info("A driver connected")
    {:noreply, socket}
  end

  def handle_in("presence_diff", diff, socket) do
    Endpoint.broadcast!("admins", "presence_diff", diff)
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
    end

    push_data_to_admins(driver_id)

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

    push_data_to_admins(driver_id)

    {:noreply, socket}
  end

  def handle_in(
        "finished_order",
        %{"restaurant_id" => restaurant_id_client, "order_id" => order_id_client},
        socket
      ) do
    "driver:" <> driver_id = socket.topic
    LocationServer.update_restaurant(driver_id, nil)
    LocationServer.update_order(driver_id, nil)

    restaurant_id_server = LocationServer.view(driver_id).restaurant_id
    order_id_server = LocationServer.view(driver_id).current_order

    if restaurant_id_client == restaurant_id_server and order_id_client == order_id_server do
      Endpoint.broadcast!("restaurant:#{restaurant_id_server}", "finished_delivering", %{
        driver_id: driver_id,
        order_id: order_id_server
      })
    end

    push_data_to_admins(driver_id)

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

  defp push_data_to_admins(driver_id) do
    data = get_state(driver_id)
    Logger.info("Sending data to admins.")

    Endpoint.broadcast!("admins", "driver_update", data)
  end

  # Only for reference
  # If we wanted to extract data from the socket
  # defp data_we_want(socket) do
  #  socket.assigns.data_we_want
  # end
end
