defmodule DeliveryLocationServiceWeb.Presence do
  @moduledoc """
  Implements Phoenix's Presence
  """
  use Phoenix.Presence,
  otp_app: :delivery_location_service,
  pubsub_server: DeliveryLocationService.PubSub
end
