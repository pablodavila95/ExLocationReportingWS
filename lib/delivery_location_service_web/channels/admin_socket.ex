defmodule DeliveryLocationServiceWeb.AdminSocket do
  use Phoenix.Socket

  channel "admin:locations", DeliveryLocationServiceWeb.AdminChannel

  def connect(%{"token" => token}, socket) do
    admin_id = 1
    {:ok, assign(socket, :admin_id, admin_id)}
  end

  def connect(_params, _socket) do
    :error
  end

  def id(_socket), do: nil
end
