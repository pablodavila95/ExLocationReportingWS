defmodule DeliveryLocationService.Location do
  @moduledoc """
  Defines the Location struct and its methods to update it. It's being used by the LocationServer.
  """
  #TODO add a new key for the current state of the driver
  #TODO give the coordinates its own struct
  #TODO add validations
  defstruct driver_id: nil, restaurant_id: nil, coordinates: %{}, timestamp: nil
  alias DeliveryLocationService.Location

  def new(driver_id, restaurant_id, coordinates, timestamp) do
    %Location{driver_id: driver_id, restaurant_id: restaurant_id, coordinates: coordinates, timestamp: timestamp}
  end

  def update_coordinates(%Location{} = location, %{} = new_coordinates, new_timestamp) do
    %Location{driver_id: location.driver_id, restaurant_id: location.restaurant_id, coordinates: new_coordinates, timestamp: new_timestamp}
  end

  def update_restaurant(%Location{} = location, new_restaurant_id, new_timestamp) do
    %Location{driver_id: location.driver_id, restaurant_id: new_restaurant_id, coordinates: location.coordinates, timestamp: new_timestamp}
  end

  def is_owned_by_restaurant?(%Location{} = location, restaurant_id) when is_nil(restaurant_id) == false do
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
