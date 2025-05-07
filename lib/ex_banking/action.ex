defmodule ExBanking.Action do
  @moduledoc """
  This module is a model of an action in the banking system.
  """

  @type t :: %__MODULE__{
          user: String.t(),
          type: :update | :get,
          amount: integer(),
          currency: String.t()
        }

  @enforce_keys [:user, :type]
  defstruct [:user, :type, :amount, :currency]

  @doc """
  Creates a new widthrow action.
  """
  @spec withdraw(String.t(), number(), String.t()) :: t()
  def withdraw(user, amount, currency) when amount > 0 do
    %__MODULE__{
      user: user,
      type: :update,
      amount: -amount,
      currency: currency
    }
  end

  @doc """
  Creates a new deposit action.
  """
  @spec deposit(String.t(), number(), String.t()) :: t()
  def deposit(user, amount, currency) when amount > 0 do
    %__MODULE__{
      user: user,
      type: :update,
      amount: amount,
      currency: currency
    }
  end

  @doc """
  Creates a new 'get balance' action.
  """
  @spec balance(String.t(), String.t()) :: t()
  def balance(user, currency) do
    %__MODULE__{
      user: user,
      type: :get,
      currency: currency
    }
  end

end
