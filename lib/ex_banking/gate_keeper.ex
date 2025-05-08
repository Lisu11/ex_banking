defmodule ExBanking.GateKeeper do
  @moduledoc """
  This module is responsible for checking if the user is allowed to perform a certain transaction.
  """
  use GenServer
  require Logger

  @max_operations 10

  @impl true
  def init(_) do
    {:ok, %{users_operations: %{}, refs_to_users: %{}}, {:continue, :init}}
  end

  @impl true
  def handle_continue(:init, state) do
    vault().init()

    {:noreply, state}
  end

  def handle_continue({:fire_tx, run, from, users}, state) do
    ref = fire_new_task(run, from)

    {:noreply, update_state_after_transaction(state, users, ref)}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    users = Map.get(state.refs_to_users, ref)
    users_operations = update_users_operations(state, users, &(&1 - 1))
    refs_to_users = Map.delete(state.refs_to_users, ref)

    if reason in [:normal, :noproc] do
      Logger.debug("Task #{inspect(ref)} for users #{inspect(users)} finished successfully.")
    else
      Logger.error(
        "Task #{inspect(ref)}, with pid #{pid} for users #{users} failed with reason: #{inspect(reason)}"
      )
    end

    {:noreply, %{state | users_operations: users_operations, refs_to_users: refs_to_users}}
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

  def handle_call({:run_action, users, run}, {from, _}, state) do
    users_existance = Enum.map(users, &{&1, user_exists?(&1, state)})
    users_limit = Enum.map(users, &{&1, user_calls_under_limit?(&1, state)})

    with {:exist, true} <- {:exist, Enum.all?(users_existance, &elem(&1, 1))},
         {:limit, true} <- {:limit, Enum.all?(users_limit, &elem(&1, 1))} do
      {:reply, :ok, state, {:continue, {:fire_tx, run, from, users}}}
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
    tx_to_run = vault().actions_as_tx(actions)
    users = Enum.map(actions, & &1.user) |> MapSet.new()
    name = Keyword.get(opts, :name, __MODULE__)

    GenServer.call(name, {:run_action, users, tx_to_run})
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

  defp fire_new_task(fun, from) do
    {:ok, pid} =
      Task.start(fn ->
        try do
          result = vault().run_transaction(fun)
          send(from, {:vault, result})
        rescue
          e ->
            Logger.error(Exception.format(:error, e, __STACKTRACE__))
            send(from, {:vault, :internal_error})
            reraise e, __STACKTRACE__
        end
      end)

    Process.monitor(pid)
  end

  defp update_state_after_transaction(state, users, ref) do
    %{
      state
      | users_operations: update_users_operations(state, users, &(&1 + 1)),
        refs_to_users: Map.put_new(state.refs_to_users, ref, users)
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
