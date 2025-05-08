defmodule ExBanking.GateKeeper do
  @moduledoc """
  This module is responsible for checking if the user is allowed to perform a certain transaction.
  """
  use GenServer
  require Logger
  alias ExBanking.TransactionTask, as: TxTask

  @max_operations 10

  @impl true
  def init(_) do
    {:ok, %{users_operations: %{}, tx_to_users: %{}}, {:continue, :init}}
  end

  @impl true
  def handle_continue(:init, state) do
    vault().init()

    {:noreply, state}
  end

  def handle_continue({:fire_tx, tx_task}, state) do
    Logger.debug("Starting transaction task #{inspect(tx_task.mfa)} #{inspect(tx_task.pid)}")
    TxTask.commit(tx_task)
    Process.monitor(tx_task.pid)

    {:noreply, state}
  end

  def handle_continue({:abort_tx, tx_task}, state) do
    TxTask.rollback(tx_task)

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    users = Map.get(state.tx_to_users, pid)
    users_operations = update_users_operations(state, users, &(&1 - 1))
    tx_to_users = Map.delete(state.tx_to_users, pid)

    if reason in [:normal, :noproc] do
      Logger.debug("Task #{inspect(pid)} for users #{inspect(users)} finished successfully.")
    else
      Logger.error(
        "Task #{inspect(pid)},  for users #{inspect(users)} failed with reason: #{inspect(reason)}"
      )
    end

    {:noreply, %{state | users_operations: users_operations, tx_to_users: tx_to_users}}
  end

  @impl true
  def handle_call({:add_user, user}, _from, state) do
    if user_exists?(user, state) do
      {:reply, {:error, :user_already_exists}, state}
    else
      new_state = %{state | users_operations: Map.put(state.users_operations, user, 0)}
      {:reply, :ok, new_state}
    end
  end

  def handle_call({:run_action, users, tx_task}, _, state) do
    users_existance = Enum.map(users, &{&1, user_exists?(&1, state)})
    users_limit = Enum.map(users, &{&1, user_calls_under_limit?(&1, state)})

    with {:exist, true} <- {:exist, Enum.all?(users_existance, &elem(&1, 1))},
         {:limit, true} <- {:limit, Enum.all?(users_limit, &elem(&1, 1))} do
      state = update_state_after_transaction(state, users, tx_task.pid)
      {:reply, {:ok, tx_task}, state, {:continue, {:fire_tx, tx_task}}}
    else
      {:exist, false} ->
        {user, false} = Enum.find(users_existance, &(not elem(&1, 1)))
        {:reply, {:error, :user_does_not_exist, user}, state}

      {:limit, false} ->
        {user, false} = Enum.find(users_limit, &(not elem(&1, 1)))
        {:reply, {:error, :too_many_requests_to_user, user}, state}
    end
  end

  # --------------------------------------------------------------
  #
  #                         Public API
  #
  # --------------------------------------------------------------

  def run_transaction(actions, opts \\ []) when is_list(actions) do
    users = Enum.map(actions, & &1.user) |> MapSet.new()
    name = Keyword.get(opts, :name, __MODULE__)
    tx_task = create_new_task(actions)

    GenServer.call(name, {:run_action, users, tx_task})
  end

  def create_account(user, opts \\ []) when is_binary(user) do
    name = Keyword.get(opts, :name, __MODULE__)

    GenServer.call(name, {:add_user, user})
  end

  def start_link(params) do
    name = Keyword.get(params, :name, __MODULE__)

    GenServer.start_link(__MODULE__, [], name: name)
  end

  # --------------------------------------------------------------
  #
  #                         Private functions
  #
  # --------------------------------------------------------------

  defp create_new_task(actions) do
    tx_to_run = vault().actions_as_tx(actions)

    TxTask.async(fn -> vault().run_transaction(tx_to_run) end)
  end

  defp update_state_after_transaction(state, users, pid) do
    %{
      state
      | users_operations: update_users_operations(state, users, &(&1 + 1)),
        tx_to_users: Map.put_new(state.tx_to_users, pid, users)
    }
  end

  defp update_users_operations(state, users, up) do
    Enum.reduce(users, state.users_operations, fn user, acc ->
      if Map.has_key?(acc, user) do
        Map.update!(acc, user, up)
      else
        acc
      end
    end)
  end

  defp user_calls_under_limit?(user, state) do
    Map.get(state.users_operations, user, 0) <= @max_operations
  end

  defp user_exists?(user, state) do
    Map.has_key?(state.users_operations, user)
  end

  defp vault do
    Application.get_env(:ex_banking, :vault_backend)
  end
end
