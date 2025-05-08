defmodule ActionTest do
  use ExUnit.Case, async: true
  alias ExBanking.Action

  describe "withdraw/3" do
    test "creates a withdraw action with negative amount" do
      action = Action.withdraw("john_doe", 50, "USD")
      assert %Action{user: "john_doe", type: :update, amount: -50, currency: "USD"} = action
    end

    test "raises an error for invalid amount" do
      assert_raise FunctionClauseError, fn ->
        Action.withdraw("john_doe", -50, "USD")
      end
    end
  end

  describe "deposit/3" do
    test "creates a deposit action with positive amount" do
      action = Action.deposit("john_doe", 50, "USD")
      assert %Action{user: "john_doe", type: :update, amount: 50, currency: "USD"} = action
    end

    test "raises an error for invalid amount" do
      assert_raise FunctionClauseError, fn ->
        Action.deposit("john_doe", -50, "USD")
      end
    end
  end

  describe "balance/2" do
    test "creates a balance action" do
      action = Action.balance("john_doe", "USD")
      assert %Action{user: "john_doe", type: :get, currency: "USD"} = action
    end
  end
end
