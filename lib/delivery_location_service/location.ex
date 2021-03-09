defmodule DeliveryLocationService.Location do
  @moduledoc """
  In reality, the Location module (and all its related OTP modules) are really a driver state which
  includes the current restaurant they are delivering to, the last location they reported and current order.

  This particular module relates to the data structure %Location{} and functions that modify it.
  """
  defstruct driver_id: nil,
            restaurant_id: nil,
            coordinates: %{},
            timestamp: nil,
            current_order: nil

  alias DeliveryLocationService.Location

  def new(driver_id, restaurant_id, coordinates, timestamp, current_order) do
    %Location{
      driver_id: driver_id,
      restaurant_id: restaurant_id,
      coordinates: coordinates,
      timestamp: timestamp,
      current_order: current_order
    }
  end

  def update_coordinates(%Location{} = location, %{} = new_coordinates, new_timestamp) do
    %Location{
      driver_id: location.driver_id,
      restaurant_id: location.restaurant_id,
      coordinates: new_coordinates,
      timestamp: new_timestamp,
      current_order: location.current_order
    }
  end

  def update_restaurant(%Location{} = location, new_restaurant_id, new_timestamp) do
    %Location{
      driver_id: location.driver_id,
      restaurant_id: new_restaurant_id,
      coordinates: location.coordinates,
      timestamp: new_timestamp,
      current_order: location.current_order
    }
  end

  def update_order(%Location{} = location, new_current_order, new_timestamp) do
    %Location{
      driver_id: location.driver_id,
      restaurant_id: location.restaurant_id,
      coordinates: location.coordinates,
      timestamp: new_timestamp,
      current_order: new_current_order
    }
  end

  def is_owned_by_restaurant?(%Location{} = location, restaurant_id)
      when is_nil(restaurant_id) == false do
    {:ok, location_data_rid} = Map.fetch(location, :restaurant_id)

    if location_data_rid == restaurant_id do
      true
    else
      if location_data_rid == nil do
        false
      end
    end
  end
end

defmodule DeliveryLocationService.Locations do
  @moduledoc """
  Provides a set of helper functions to work with the Location GenServer's state.
  This module is supposed to directly interact and call the running GenServers.
  """
  alias DeliveryLocationService.Location
  alias DeliveryLocationService.LocationServer
  alias DeliveryLocationService.LocationSupervisor

  def get_orders_for_all do
    Supervisor.which_children(LocationSupervisor)
    |> Enum.map(fn driver ->
      {_, pid, _, _} = driver
      :sys.get_state(pid)
    end)
  end

  def get_list_of_driver_ids do
    get_orders_for_all()
    |> Enum.map(fn location_data -> location_data.driver_id end)
  end

  def get_orders_for(restaurant_id) when is_nil(restaurant_id) == false do
    get_orders_for_all()
    |> Enum.filter(fn location_data ->
      Location.is_owned_by_restaurant?(location_data, restaurant_id) == true
    end)
  end

  def is_delivering?(driver_id) do
    LocationServer.view(driver_id)
    |> Map.get(:restaurant_id) != nil
  end

  def reset_restaurant(driver_id) do
    DeliveryLocationService.LocationServer.update_restaurant(driver_id, nil)
    :ok
  end

  def set_restaurant(driver_id, restaurant_id) do
    DeliveryLocationService.LocationServer.update_restaurant(driver_id, restaurant_id)
  end

  def reset_order(driver_id) do
    DeliveryLocationService.LocationServer.update_order(driver_id, nil)
  end

  def set_order(driver_id, order_id) do
    DeliveryLocationService.LocationServer.update_order(driver_id, order_id)
  end
end
