defmodule ExBankingTest do
  use ExUnit.Case, async: false
  alias ExBanking

  setup do
    Application.get_env(:ex_banking, :vault_backend).terminate()
    start_supervised!(ExBanking.GateKeeper)
    :ok
  end

  describe "create_user/1" do
    test "creates a new user successfully" do
      assert :ok == ExBanking.create_user("john_doe")
    end

    test "returns error for invalid arguments" do
      assert {:error, :wrong_arguments} == ExBanking.create_user(123)
    end
  end

  describe "deposit/3" do
    setup do
      ExBanking.create_user("john_doe")
    end

    test "successfully deposits money" do
      assert {:ok, 100} == ExBanking.deposit("john_doe", "USD", 100)
    end

    test "returns error for invalid arguments" do
      assert {:error, :wrong_arguments} == ExBanking.deposit("john_doe", "USD", -100)
    end

    test "returns error for non-existent user" do
      assert {:error, :user_does_not_exist} == ExBanking.deposit("unknown_user", "USD", 100)
    end
  end

  describe "withdraw/3" do
    setup do
      ExBanking.create_user("john_doe")
      ExBanking.deposit("john_doe", "USD", 100)
      :ok
    end

    test "successfully withdraws money" do
      assert {:ok, 50} == ExBanking.withdraw("john_doe", "USD", 50)
    end

    test "returns error for insufficient funds" do
      assert {:error, :not_enough_money} == ExBanking.withdraw("john_doe", "USD", 200)
    end

    test "returns error for invalid arguments" do
      assert {:error, :wrong_arguments} == ExBanking.withdraw("john_doe", "USD", -50)
    end

    test "returns error for non-existent user" do
      assert {:error, :user_does_not_exist} == ExBanking.withdraw("unknown_user", "USD", 50)
    end
  end

  describe "get_balance/2" do
    setup do
      ExBanking.create_user("john_doe")
      ExBanking.deposit("john_doe", "USD", 100)
      :ok
    end

    test "successfully retrieves balance" do
      assert {:ok, 100} == ExBanking.get_balance("john_doe", "USD")
    end

    test "returns error for invalid arguments" do
      assert {:error, :wrong_arguments} == ExBanking.get_balance("john_doe", 123)
    end

    test "returns error for non-existent user" do
      assert {:error, :user_does_not_exist} == ExBanking.get_balance("unknown_user", "USD")
    end
  end

  describe "send/4" do
    setup do
      ExBanking.create_user("john_doe")
      ExBanking.create_user("jane_doe")
      ExBanking.deposit("john_doe", "USD", 100)
      :ok
    end

    test "successfully transfers money" do
      assert {:ok, 50, 50} == ExBanking.send("john_doe", "jane_doe", 50, "USD")
    end

    test "returns error for insufficient funds" do
      assert {:error, :not_enough_money} == ExBanking.send("john_doe", "jane_doe", 200, "USD")
    end

    test "returns error for invalid arguments" do
      assert {:error, :wrong_arguments} == ExBanking.send("john_doe", "jane_doe", -50, "USD")
    end

    test "returns error for non-existent sender" do
      assert {:error, :sender_does_not_exist} ==
               ExBanking.send("unknown_user", "jane_doe", 50, "USD")
    end

    test "returns error for non-existent receiver" do
      assert {:error, :receiver_does_not_exist} ==
               ExBanking.send("john_doe", "unknown_user", 50, "USD")
    end
  end
end
