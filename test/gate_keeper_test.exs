defmodule GateKeeperTest do
  use ExUnit.Case, async: true

  alias ExBanking.GateKeeper

  setup do
    Application.get_env(:ex_banking, :vault_backend).terminate()
    start_supervised!(GateKeeper)
    :ok
  end

  describe "create_account/1" do
    test "successfully creates a new account" do
      assert :ok == GateKeeper.create_account("john_doe")
    end

    test "returns error when account already exists" do
      GateKeeper.create_account("john_doe")
      assert {:error, :user_already_exists} == GateKeeper.create_account("john_doe")
    end

    test "returns error for invalid arguments" do
      assert_raise FunctionClauseError, fn ->
        GateKeeper.create_account(123)
      end
    end
  end

  describe "run_transaction/1" do
    setup do
      GateKeeper.create_account("john_doe")
      :ok
    end

    test "successfully runs a transaction" do
      actions = [
        %ExBanking.Action{user: "john_doe", type: :update, amount: 100, currency: "USD"}
      ]

      assert :ok == GateKeeper.run_transaction(actions)
    end

    test "returns error for too many requests to user" do
      tx = [ExBanking.Action.deposit("john_doe", 100, "USD")]

      # Simulate too many requests
      [resp | _] =
        for _ <- 1..20 do
          GateKeeper.run_transaction(tx)
        end
        |> Enum.reject(&(&1 == :ok))

      assert resp == {:error, :too_many_requests_to_user, "john_doe"}
    end

    test "returns error for non-existent user" do
      actions = [
        %ExBanking.Action{user: "unknown_user", type: :update, amount: 100, currency: "USD"}
      ]

      assert {:error, :user_does_not_exist, "unknown_user"} == GateKeeper.run_transaction(actions)
    end
  end
end
