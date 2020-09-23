defmodule DeliveryLocationService.LocationServer do
  @moduledoc """
  A GenServer that holds state for a driver with its location, assigned restaurant and timestamps.
  It uses %Location{} and is supervised by LocationSupervisor
  It also makes use of :ets in case the process crashes it can be called back from the in-memory db.
  Since the state is ephemeral, :ets is not really needed and can be removed if needed to scale but it was a nice addition.
  """
  #TODO add the corresponding hours to set UTC to mx's timezone
  #TODO update :ets table whenever something updates

  use GenServer
  alias DeliveryLocationService.Location
  require Logger

  #@timeout :timer.minutes(15)


  def create(driver_id) do
    case location_data_pid(driver_id) do
      nil ->
        DeliveryLocationService.LocationSupervisor.start_location(%Location{driver_id: driver_id, restaurant_id: nil, coordinates: %{lat: nil, long: nil}, timestamp: Time.utc_now})
      _driver_location ->
        {:error, :user_already_registered}
    end
  end

  @spec start_link(DeliveryLocationService.Location.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(%Location{} = location_data) do
    GenServer.start_link(__MODULE__, {location_data.driver_id, location_data.restaurant_id, location_data.coordinates, location_data.timestamp}, name: via_tuple(location_data.driver_id))
  end

  def view(driver_id) do
    GenServer.call(via_tuple(driver_id), :view)
  end

  def update_coordinates(driver_id, new_coordinates) do
    GenServer.cast(via_tuple(driver_id), {:update_coordinates, new_coordinates})
  end

  def update_restaurant(driver_id, new_restaurant_id) do
    GenServer.cast(via_tuple(driver_id), {:update_restaurant, new_restaurant_id})
  end

  def via_tuple(driver_id) do
    {:via, Registry, {DeliveryLocationService.LocationRegistry, driver_id}}
  end

  def location_data_pid(driver_id) do
    driver_id
    |> via_tuple()
    |> GenServer.whereis()
  end

  ################################################################################
  def init({driver_id, restaurant_id, coordinates, timestamp}) do
    location_data =
      case :ets.lookup(:locations_table, driver_id) do
        [] ->
          location_data = Location.new(driver_id, restaurant_id, coordinates, timestamp)
          :ets.insert(:locations_table, {driver_id, location_data})
          location_data

        [{^driver_id, location_data}] ->
          location_data
      end
    Logger.info("Spawned a location_data for a driver with id '#{driver_id}'.")
    {:ok, location_data}
    #{:ok, location_data, @timeout}
  end

  def handle_call(:view, _from, location_data) do
    {:reply, view_data(location_data), location_data}
    #{:reply, view_data(location_data), location_data, @timeout}
  end

  def handle_cast({:update_coordinates, %{} = new_coordinates}, location_data) do
    new_location_data = Location.update_coordinates(location_data, new_coordinates, Time.utc_now)
    {:noreply, new_location_data}
    #{:noreply, new_location_data, @timeout}
  end

  def handle_cast({:update_restaurant, new_restaurant}, location_data) do
    new_location_data = Location.update_restaurant(location_data, new_restaurant, Time.utc_now)
    {:noreply, new_location_data}
    #{:noreply, new_location_data, @timeout}
  end

  def handle_info(:timeout, location_data) do
    {:stop, {:shutdown, :timeout}, location_data}
  end

  def terminate({:shutdown, :timeout}, _location_data) do
    :ets.delete(:locations_table, location_data_driver_id())
    :ok
  end

  def terminate(_reason, _location_data) do
    :ok
  end

  defp location_data_driver_id do
    Registry.keys(DeliveryLocationService.LocationRegistry, self()) |> List.first
  end

  defp view_data(%Location{} = location_data) do
    %{
      driver_id: location_data.driver_id,
      restaurant_id: location_data.restaurant_id,
      coordinates: location_data.coordinates,
      timestamp: location_data.timestamp
    }
  end
end
