defmodule ExBanking do
  @moduledoc """
  Documentation for `ExBanking`.
  """
  alias ExBanking.Action

  @type balance :: number
  @type access_error_msg :: :user_does_not_exist | :too_many_requests_to_user

  @doc """
  Function creates new user in the system
  New user has zero balance of any currency

  ## Examples

      iex> ExBanking.create_user("john_doe")
      :ok

      iex> ExBanking.create_user(5)
      {:error, :wrong_arguments}

  """
  @spec create_user(user :: String.t) :: :ok | {:error, :wrong_arguments | :user_already_exists}
  def create_user(user) when is_binary(user) do
    ExBanking.GateKeeper.create_account(user)
  end

  def create_user(_user), do: {:error, :wrong_arguments}


  @type deposit_error :: :wrong_arguments | access_error_msg
  @doc """
  Increases user’s balance in given currency by amount value
  Returns new_balance of the user in given format

  ## Examples

      iex> ExBanking.deposit("john_doe", "USD", 100)
      {:ok, 100}

      iex> ExBanking.deposit("john_doe", "USD", -100)
      {:error, :wrong_arguments}

      iex> ExBanking.deposit("john_doe2", "USD", 100)
      {:error, :user_not_found}

  """
  @spec deposit(user :: String.t, amount :: number, currency :: String.t) :: {:ok, balance} | {:error, deposit_error}
  def deposit(user, currency, amount) when
    is_binary(user) and
    is_binary(currency) and
    is_integer(amount) and
    amount > 0 do
      run_transaction([
        Action.deposit(user, amount, currency)
      ])
  end

  def deposit(_user, _currency, _amount), do: {:error, :wrong_arguments}


  @type withdraw_error :: :wrong_arguments | :not_enough_money | access_error_msg
  @doc """
  Decreases user’s balance in given currency by amount value
  Returns new_balance of the user in given format

  ## Examples

      iex> ExBanking.withdraw("john_doe", "USD", 50)
      {:ok, 50}

      iex> ExBanking.withdraw("john_doe", "USD", -50)
      {:error, :wrong_arguments}

      iex> ExBanking.withdraw("john_doe2", "USD", 50)
      {:error, :user_not_found}

  """
  @spec withdraw(user :: String.t, amount :: number, currency :: String.t) :: {:ok, balance} | {:error, withdraw_error}
  def withdraw(user, currency, amount) when is_binary(user) and is_binary(currency) and is_integer(amount) and amount > 0 do
    run_transaction([
      Action.withdraw(user, amount, currency)
    ])
  end

  def withdraw(_user, _currency, _amount), do: {:error, :wrong_arguments}


  @type get_balance_error :: :wrong_arguments | access_error_msg
  @doc """
  Returns balance of the user in given format

  ## Examples

      iex> ExBanking.get_balance("john_doe", "USD")
      {:ok, 50}

      iex> ExBanking.get_balance("john_doe", "USD", -50)
      {:error, :wrong_arguments}

      iex> ExBanking.get_balance("john_doe2", "USD")
      {:error, :user_not_found}

  """
  @spec get_balance(user :: String.t, currency :: String.t) :: {:ok, balance :: number} | {:error, get_balance_error}
  def get_balance(user, currency) when is_binary(user) and is_binary(currency) do
    run_transaction([
      Action.balance(user, currency)
    ])
  end

  def get_balance(_user, _currency), do: {:error, :wrong_arguments}

  @type send_error :: :wrong_arguments | :not_enough_money | :sender_does_not_exist | :receiver_does_not_exist | :too_many_requests_to_sender | :too_many_requests_to_receiver
  @doc """
  Decreases from_user’s balance in given currency by amount value
  Increases to_user’s balance in given currency by amount value
  Returns balance of from_user and to_user in given format

  ## Examples

      iex> ExBanking.send("john_doe", "jane_doe", 50, "USD")
      {:ok, 0, 50}

      iex> ExBanking.send("john_doe", "jane_doe", -50, "USD")
      {:error, :wrong_arguments}

      iex> ExBanking.send("john_doe2", "jane_doe", 50, "USD")
      {:error, :user_not_found}
  """
  @spec send(from_user :: String.t, to_user :: String.t, amount :: number, currency :: String.t) :: {:ok, from_user :: balance, to_user :: balance} | {:error, send_error}
  def send(from_user, to_user, amount, currency) when is_binary(from_user) and is_binary(to_user) and is_binary(currency) and is_integer(amount) and amount > 0 do
    run_transaction([
      Action.withdraw(from_user, amount, currency),
      Action.deposit(to_user, amount, currency),
      Action.balance(from_user, currency),
      Action.balance(to_user, currency),
    ])
    |> case do
      {:ok, result} ->
        result
        |> Enum.take(-2)
        |> then(fn [from, to] ->
          {:ok, from, to}
        end)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def send(_from_user, _to_user, _amount, _currency), do: {:error, :wrong_arguments}

  defp run_transaction(actions) when is_list(actions) do
    with {:ok, _task} <- ExBanking.GateKeeper.run_transaction(actions) do
      receive do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> {:error, reason}
        otherwise -> IO.inspect(otherwise)
      end
    end
  end
end
