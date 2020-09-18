defmodule DeliveryLocationServiceWeb.DriverChannel do
  use DeliveryLocationServiceWeb, :channel
  alias DeliveryLocationService.Location
  alias DeliveryLocationService.LocationSupervisor

  def join("driver:" <> driver_id, _params, socket) do
    case LocationServer.location_data_pid(driver_id) do
      pid when is_pid(pid) ->
        send(self(), {:after_join, driver_id})
        {:ok, socket}
      nil ->
        %Location{driver_id: driver_id, restaurant_id: nil, coordinates: %{lat: nil, long: nil}, timestamp: Time.utc_now}
        |> LocationSupervisor.start_location

        send(self(), {:after_join, driver_id})
        {:ok, socket}
      _ ->
        {:error, %{reason: "Something happened"}}
    end
  end

  def handle_info({:after_join, driver_id}, socket) do
    #After the join we push a message to request the client to send his coordinates, in case it didn't get sent
    #for any reason
    #Also some stuff with presence
    push(socket, "request_location_update", %{msg: "Location requested by channel"})


    #push(socket, "presence_state", Presence.list(socket))
    #{:ok, _} =
    #  Presence.track(socket, current_driver(socket).name, %{
    #    online_at: inspect(System.system_time(:seconds)),
    #    color: current_driver(socket).color
    #  })
    {:noreply, socket}
  end

  def handle_in("update_location", %{"coordinates" => new_coordinates}, socket) do
    "driver:" <> driver_id = socket.topic

    case LocationServer.location_data_pid(driver_id) do
      pid when is_pid(pid) ->
        LocationServer.update_coordinates(driver_id, new_coordinates)
        #broadcast!(socket, "location_update", new_location_data)
        {:noreply, socket}
      nil ->
        {:reply, {:error, %{reason: "Driver's data does not exist"}}, socket}
    end
  end


  #Only for reference
  #If we wanted to extract data from the socket
  #defp data_we_want(socket) do
  #  socket.assigns.data_we_want
  #end
end
