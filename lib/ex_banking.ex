defmodule ExBanking do
  @moduledoc """
  Documentation for `ExBanking`.
  """
  alias ExBanking.Action

  @type balance :: number
  @type access_error_msg :: :user_does_not_exist | :too_many_requests_to_user

  defguard is_amount(amount) when is_integer(amount) and amount > 0

  @doc """
  Function creates new user in the system
  New user has zero balance of any currency

  ## Examples

      iex> ExBanking.create_user("john_doe")
      :ok

      iex> ExBanking.create_user(5)
      {:error, :wrong_arguments}

  """
  @spec create_user(user :: String.t()) :: :ok | {:error, :wrong_arguments | :user_already_exists}
  def create_user(user) when is_binary(user) do
    ExBanking.GateKeeper.create_account(user)
  end

  def create_user(_user), do: {:error, :wrong_arguments}

  @doc """
  Increases user’s balance in given currency by amount value
  Returns new_balance of the user in given format
  Please keep in mind that amount should be given as positive integer that
  represents cents (e.g. 1000 = $10.00) and similar for other currencies

  ## Examples

      iex> ExBanking.deposit("john_doe", "USD", 100)
      {:ok, 100}

      iex> ExBanking.deposit("john_doe", "USD", -100)
      {:error, :wrong_arguments}

      iex> ExBanking.deposit("john_doe2", "USD", 100)
      {:error, :user_not_found}

  """
  @spec deposit(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, balance} | {:error, :wrong_arguments | access_error_msg}
  def deposit(user, currency, amount)
      when is_binary(user) and is_binary(currency) and is_amount(amount) do
    [
      Action.deposit(user, amount, currency),
      Action.balance(user, currency)
    ]
    |> run_transaction()
    |> parse_last_action_result()
  end

  def deposit(_user, _currency, _amount), do: {:error, :wrong_arguments}

  @doc """
  Decreases user’s balance in given currency by amount value
  Returns new_balance of the user in given format
  Please keep in mind that amount should be given as positive integer that
  represents cents (e.g. 1000 = $10.00) and similar for other currencies

  ## Examples

      iex> ExBanking.withdraw("john_doe", "USD", 50)
      {:ok, 50}

      iex> ExBanking.withdraw("john_doe", "USD", -50)
      {:error, :wrong_arguments}

      iex> ExBanking.withdraw("john_doe2", "USD", 50)
      {:error, :user_not_found}

  """
  @spec withdraw(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, balance} | {:error, :wrong_arguments | :not_enough_money | access_error_msg}
  def withdraw(user, currency, amount)
      when is_binary(user) and is_binary(currency) and is_amount(amount) do
    [
      Action.withdraw(user, amount, currency),
      Action.balance(user, currency)
    ]
    |> run_transaction()
    |> parse_last_action_result()
  end

  def withdraw(_user, _currency, _amount), do: {:error, :wrong_arguments}

  @doc """
  Returns balance of the user in given format
  Please keep in mind that returned amount is
  represented by cents (e.g. 1000 = $10.00) and similar for other currencies

  ## Examples

      iex> ExBanking.get_balance("john_doe", "USD")
      {:ok, 50}

      iex> ExBanking.get_balance("john_doe", "USD", -50)
      {:error, :wrong_arguments}

      iex> ExBanking.get_balance("john_doe2", "USD")
      {:error, :user_not_found}

  """
  @spec get_balance(user :: String.t(), currency :: String.t()) ::
          {:ok, balance :: number} | {:error, :wrong_arguments | access_error_msg}
  def get_balance(user, currency)
      when is_binary(user) and is_binary(currency) do
    [
      Action.balance(user, currency)
    ]
    |> run_transaction()
    |> parse_last_action_result()
  end

  def get_balance(_user, _currency), do: {:error, :wrong_arguments}

  @type send_error ::
          :wrong_arguments
          | :not_enough_money
          | :sender_does_not_exist
          | :receiver_does_not_exist
          | :too_many_requests_to_sender
          | :too_many_requests_to_receiver
  @doc """
  Decreases from_user’s balance in given currency by amount value
  Increases to_user’s balance in given currency by amount value
  Returns balance of from_user and to_user in given format
  Please keep in mind that amount should be given as positive integer that
  represents cents (e.g. 1000 = $10.00) and similar for other currencies

  ## Examples

      iex> ExBanking.send("john_doe", "jane_doe", 50, "USD")
      {:ok, 0, 50}

      iex> ExBanking.send("john_doe", "jane_doe", -50, "USD")
      {:error, :wrong_arguments}

      iex> ExBanking.send("john_doe2", "jane_doe", 50, "USD")
      {:error, :user_not_found}
  """
  @spec send(
          from_user :: String.t(),
          to_user :: String.t(),
          amount :: number,
          currency :: String.t()
        ) :: {:ok, from_user :: balance, to_user :: balance} | {:error, send_error}
  def send(from_user, to_user, amount, currency)
      when is_binary(from_user) and is_binary(to_user) and is_binary(currency) and
             is_amount(amount) and from_user != to_user do
    [
      Action.withdraw(from_user, amount, currency),
      Action.deposit(to_user, amount, currency),
      Action.balance(from_user, currency),
      Action.balance(to_user, currency)
    ]
    |> run_transaction()
    |> parse_money_transfer_result(from_user)
  end

  def send(_from_user, _to_user, _amount, _currency), do: {:error, :wrong_arguments}

  # --------------------------------------------------------------
  #
  #                         Private functions
  #
  # --------------------------------------------------------------

  defp run_transaction(actions) when is_list(actions) do
    with {:ok, task} <- ExBanking.GateKeeper.run_transaction(actions) do
      case Task.await(task) do
        {:vault, {:ok, result}} -> {:ok, result}
        {:vault, {:error, reason}} -> {:error, reason}
      end
    end
  end

  defp parse_last_action_result({:ok, result}) do
    [{_, _, balance}] = Enum.take(result, -1)

    {:ok, balance}
  end

  defp parse_last_action_result({:error, :user_does_not_exist, _user}),
    do: {:error, :user_does_not_exist}

  defp parse_last_action_result({:error, :too_many_requests_to_user, _user}),
    do: {:error, :too_many_requests_to_user}

  defp parse_last_action_result({:error, :not_enough_money}),
    do: {:error, :not_enough_money}

  defp parse_money_transfer_result({:ok, result}, _from_user) do
    [{_, _, from_balance}, {_, _, to_balance}] =
      result
      |> Enum.take(-2)

    {:ok, from_balance, to_balance}
  end

  defp parse_money_transfer_result({:error, :user_does_not_exist, user}, from_user)
       when user == from_user,
       do: {:error, :sender_does_not_exist}

  defp parse_money_transfer_result({:error, :user_does_not_exist, _user}, _from_user),
    do: {:error, :receiver_does_not_exist}

  defp parse_money_transfer_result({:error, :too_many_requests_to_user, user}, from_user)
       when user == from_user,
       do: {:error, :too_many_requests_to_sender}

  defp parse_money_transfer_result({:error, :too_many_requests_to_user, _user}, _from_user),
    do: {:error, :too_many_requests_to_receiver}

  defp parse_money_transfer_result({:error, :not_enough_money}, _from_user),
    do: {:error, :not_enough_money}
end
