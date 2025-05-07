import Config

config :ex_banking,
  mix_env: Mix.env()


# Configures Elixir's Logger
config :logger, :console,
  format: "$date $time [$level] $metadata| $message\n"
  # metadata: [:user_id]
