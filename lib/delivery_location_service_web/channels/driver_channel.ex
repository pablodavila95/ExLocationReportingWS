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

  def join("driver:" <> driver_id, %{"lat" => lat, "long" => long}, socket) do
    case LocationServer.location_data_pid(driver_id) do
      pid when is_pid(pid) ->
        send(self(), {:after_join, driver_id, %{lat: lat, long: long}})
        {:ok, socket}
      nil ->
        LocationServer.create(driver_id)
        send(self(), {:after_join, driver_id, %{lat: lat, long: long}})
        {:ok, socket}
    end
  end

  def handle_info({:after_join, driver_id, coordinates}, socket) do
    LocationServer.update_coordinates(driver_id, coordinates)
    updated_coordinates = LocationServer.location_data_pid(driver_id) |> :sys.get_state |> Map.get(:coordinates)
    push(socket, "logs", %{message: "Connected to Channel with reported location #{updated_coordinates.lat} #{updated_coordinates.long}"})
    Endpoint.broadcast!("admins", "logs", %{message: "Driver #{driver_id} just connected"})
    {:ok, _} = Presence.track(socket, "driver:#{driver_id}", %{
      online_at: inspect(Time.utc_now()),
      is_delivering: inspect(LocationsHelper.is_delivering?(driver_id))
    })
    Endpoint.broadcast!("admins", "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  def handle_in("presence_diff", diff, socket) do
    Endpoint.broadcast!("admins", "presence_diff", diff)
    {:noreply, socket}
  end

  def handle_in("update_location", new_coordinates, socket) do
    IO.puts(inspect new_coordinates)
    %{"lat" => lat, "long" => long} = new_coordinates
    IO.puts(inspect lat)
    IO.puts(inspect long)

    "driver:" <> driver_id = socket.topic
    LocationServer.update_coordinates(driver_id, %{lat: lat, long: long})

    current_state =
      LocationServer.location_data_pid(driver_id)
      |> :sys.get_state()

    current_restaurant_id =
      current_state
      |> Map.get(:restaurant_id)

    if current_restaurant_id != nil do
      Logger.info("Will send to restaurant #{current_restaurant_id}")
      Endpoint.broadcast!("restaurant:#{current_restaurant_id}", "driver_update", Map.from_struct(current_state))
    end
    push_data_to_admins(driver_id)

    {:noreply, socket}
  end

  def handle_in("accepted_order", %{"restaurant_id" => restaurant_id}, socket) do
    "driver:" <> driver_id = socket.topic
    LocationServer.update_restaurant(driver_id, restaurant_id)
    Endpoint.broadcast!("restaurant:#{restaurant_id}", "driver_delivering", %{driver_id: driver_id})
    push_data_to_admins(driver_id)

    {:noreply, socket}
  end

  def handle_in("finished_order", %{"restaurant_id" => restaurant_id_client}, socket) do
    "driver:" <> driver_id = socket.topic
    LocationServer.update_restaurant(driver_id, nil)
    restaurant_id_server = LocationServer.view(driver_id).restaurant_id
    if restaurant_id_client == restaurant_id_server do
      Endpoint.broadcast!("restaurant:#{restaurant_id_server}", "finished_delivering", %{driver_id: driver_id})
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
      Endpoint.broadcast!("restaurant:#{restaurant_id}", "driver_delivering", %{driver_id: driver_id})
    end
  end

  def handle_in("ping", _params, socket) do
    push(socket, "pong", %{msg: "pong!"})
    {:reply, :ok, socket}
  end

  defp push_data_to_admins(driver_id) do
    data =
      LocationServer.location_data_pid(driver_id)
      |> :sys.get_state()
      |> Map.from_struct
    IO.puts(inspect data)

    Endpoint.broadcast!("admins", "driver_update", data)
  end

  #Only for reference
  #If we wanted to extract data from the socket
  #defp data_we_want(socket) do
  #  socket.assigns.data_we_want
  #end
end
