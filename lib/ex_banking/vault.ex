defmodule ExBanking.Vault do
  @moduledoc """
  This module is a model of a vault in the banking system.
  """
   @callback init(initial_ledger :: [{String.t(), String.t(), integer()}]) :: :ok | {:error, reason :: String.t()}
   @callback actions_as_tx(actions :: [ExBanking.Action.t()]) ::
               {:ok, result :: term}
               | {:error, reason :: term}
  @callback run_transaction((-> {:ok, term} | {:error, reason :: term})) ::
              {:ok, result :: term}
              | {:error, reason :: term}

end
