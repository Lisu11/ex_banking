defmodule ExBanking.Vault.MnesiaVault do
  @moduledoc """
  This module is responsible for storing all the balances info.
  """
  @behaviour ExBanking.Vault
  alias ExBanking.Action

  alias :mnesia, as: Mnesia

  require Logger

  @table __MODULE__
  @attributes [
    :user_currency,
    :amount
  ]

  @impl true
  def init(initial_balance \\ []) do
    with _ <- Mnesia.create_schema([]),
         :ok <- Mnesia.start(),
         {:atomic, :ok} <- Mnesia.create_table(@table, attributes: @attributes),
         :ok <- Mnesia.wait_for_tables([@table], 5000) do
      init_balances(initial_balance)
    else
      {:aborted, {:already_exists, @table}} ->
        Logger.error(
          "Mnesia Table #{@table} already exists. Upserting initial balances if needed."
        )

        init_balances(initial_balance)

      reason ->
        Logger.error("Unable to create mnesia table #{@table}. reason: #{inspect(reason)}")
    end
  end

  @impl true
  def terminate() do
    Mnesia.delete_table(@table)
    :ok
  end

  @impl true
  def actions_as_tx(actions) do
    fn ->
      Enum.map(actions, &translate/1)
    end
  end

  @impl true
  def run_transaction(transaction) do
    transaction
    |> Mnesia.sync_transaction()
    |> parse_result()
  end

  # --------------------------------------------------------------
  #
  #                         Private functions
  #
  # --------------------------------------------------------------

  defp init_balances([]), do: :ok

  defp init_balances(balances) do
    Mnesia.sync_transaction(fn ->
      Enum.each(balances, fn {user, currency, amount} ->
        Mnesia.write({@table, {user, currency}, amount})
      end)
    end)
  end

  defp translate(%Action{type: :get} = action) do
    with [] <- Mnesia.read({@table, {action.user, action.currency}}) do
      [{@table, {action.user, action.currency}, 0}]
    end
  end

  defp translate(%Action{type: :update, user: user, currency: currency} = action) do
    balance =
      case Mnesia.read({@table, {user, currency}}) do
        [] -> 0
        [{@table, {^user, ^currency}, balance}] -> balance
      end

    if balance + action.amount < 0 do
      Mnesia.abort(:not_enough_money)
    else
      Mnesia.write({@table, {user, currency}, balance + action.amount})
    end
  end

  defp parse_result({:atomic, result}) do
    result
    |> Enum.map(fn
      [{_, {user, currency}, amount}] ->
        {user, currency, amount}

      :ok ->
        :ok
    end)
    |> then(&{:ok, &1})
  end

  defp parse_result({:aborted, result}), do: {:error, result}
end
