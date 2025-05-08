defmodule MnesiaVaultTest do
  use ExUnit.Case, async: false
  alias ExBanking.Vault.MnesiaVault
  alias ExBanking.Action

  setup do
    MnesiaVault.terminate()
    MnesiaVault.init()

    [] = :ets.tab2list(MnesiaVault)

    on_exit(fn ->
      MnesiaVault.terminate()
    end)
  end

  describe "init/1" do
    test "initializes the Mnesia table with balances" do
      :mnesia.delete_table(MnesiaVault)
      initial_balances = [{"john_doe", "USD", 100}, {"jane_doe", "EUR", 200}]

      MnesiaVault.init(initial_balances)

      {:atomic, result} =
        :mnesia.transaction(fn ->
          :mnesia.match_object({MnesiaVault, :_, :_})
        end)

      assert Enum.count(result) == 2
      assert {MnesiaVault, {"john_doe", "USD"}, 100} in result
      assert {MnesiaVault, {"jane_doe", "EUR"}, 200} in result
    end

    test "initializes the Mnesia table without balances" do
      :mnesia.delete_table(MnesiaVault)

      MnesiaVault.init()

      assert :ets.tab2list(MnesiaVault) == []
    end
  end

  describe "actions_as_tx/1" do
    test "returns a transaction function for given actions" do
      actions = [
        Action.deposit("john_doe", 100, "USD"),
        Action.withdraw("john_doe", 50, "USD")
      ]

      tx_fun = MnesiaVault.actions_as_tx(actions)
      assert is_function(tx_fun)

      :mnesia.transaction(tx_fun)

      {:atomic, result} =
        :mnesia.transaction(fn ->
          :mnesia.match_object({MnesiaVault, :_, :_})
        end)

      assert result == [{MnesiaVault, {"john_doe", "USD"}, 50}]
    end
  end

  describe "run_transaction/1" do
    test "successfully runs a transaction" do
      actions = [
        Action.deposit("john_doe", 100, "USD"),
        Action.withdraw("john_doe", 50, "USD"),
        Action.balance("john_doe", "USD")
      ]

      tx_fun = MnesiaVault.actions_as_tx(actions)
      assert {:ok, [:ok, :ok, {"john_doe", "USD", 50}]} = MnesiaVault.run_transaction(tx_fun)
    end

    test "aborts a transaction when there are insufficient funds" do
      actions = [
        Action.withdraw("john_doe", 50, "USD")
      ]

      tx_fun = MnesiaVault.actions_as_tx(actions)
      assert {:error, :not_enough_money} = MnesiaVault.run_transaction(tx_fun)
    end
  end

  describe "terminate/0" do
    test "stops the Mnesia system" do
      assert :ok == MnesiaVault.terminate()

      assert_raise ArgumentError, fn ->
        :ets.tab2list(MnesiaVault)
      end
    end
  end
end
