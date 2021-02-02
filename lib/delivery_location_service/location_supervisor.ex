defmodule DeliveryLocationService.LocationSupervisor do
  @moduledoc """
  Supervises the LocationServer
  """
  use DynamicSupervisor

  alias DeliveryLocationService.Location
  alias DeliveryLocationService.LocationServer

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_location(%Location{} = location_data) do
    child_spec = %{
      id: LocationServer,
      start: {LocationServer, :start_link, [location_data]},
      restart: :transient
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  def stop_location(driver_id) do
    :ets.delete(:locations_table, driver_id)

    child_pid = LocationServer.location_data_pid(driver_id)
    DynamicSupervisor.terminate_child(__MODULE__, child_pid)
  end

end
