# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :delivery_location_service, DeliveryLocationServiceWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "nagLsMZZHM36b5NIxEVyw86qDA8+8KgY0y09vsiBWmnXAirgo/qDI5A83kZ1l06i",
  render_errors: [view: DeliveryLocationServiceWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: DeliveryLocationService.PubSub,
  live_view: [signing_salt: "bEpq3APd"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
