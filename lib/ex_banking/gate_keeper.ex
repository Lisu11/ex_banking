defmodule ExBanking.GateKeeper do
  @moduledoc """
  This module is responsible for checking if the user is allowed to perform a certain transaction.
  """
  use GenServer

  @max_operations 10
  @vault_backend ExBanking.Vault.MnesiaVault

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, %{ users_operations: %{}, refs_to_users: %{} }, {:continue, :init}}
  end

  @impl true
  def handle_continue(:init, state) do
    @vault_backend.init()
    Task.Supervisor.start_link(name: ExBanking.TaskSupervisor)

    {:noreply, state}
  end

  @impl true
  def handle_call({:add_user, user}, _from, state) do
    if user_exists?(user, state) do
        {:reply, {:error, :user_already_exists}, state}
    else
        new_state = %{state |
          users_operations: Map.put(state.users_operations, user, 0),
        }
        {:reply, :ok, new_state}
    end
  end

  def handle_call({:run_action, users, fun}, from, state) do
    users_existance = Enum.map(users, & {&1, user_exists?(&1, state)})
    users_limit = Enum.map(users, & {&1, user_calls_under_limit?(&1, state)})

    with {:exist, true} <- {:exist, Enum.all?(users_existance, &elem(&1, 1))},
         {:limit, true} <- {:limit, Enum.all?(users_limit, &elem(&1, 1))} do
      task = Task.Supervisor.async_nolink(ExBanking.TaskSupervisor, fn ->
        send(from, fun.())
      end)
      ref = Process.monitor(task.pid)

      users_operations = Enum.reduce(users, state.users_operations, fn user, acc ->
        if Map.has_key?(acc, user) do
          Map.update!(acc, user, &(&1 + 1))
        else
          acc
        end
      end)

      refs_to_users = Map.put_new(state.refs_to_users, ref, users)


      {:reply, {:ok, task}, %{state | users_operations: users_operations, refs_to_users: refs_to_users}}
    else
      {:exist, false} ->
        user = Enum.find(users_existance, & not elem(&1, 1))
        {:reply, {:error, :user_does_not_exist, user}, state}
      {:limit, false} ->
        user = Enum.find(users_limit, & not elem(&1, 1))
        {:reply, {:error, :too_many_requests_to_user, user}, state}
    end
  end

  def run_transaction(actions) when is_list(actions) do
    tx_to_run = @vault_backend.actions_as_tx(actions)
    users = Enum.map(actions, & &1.user) |> MapSet.new()

    GenServer.call(__MODULE__, {:run_action, users, tx_to_run})
  end

  def create_account(user) when is_binary(user) do
    GenServer.call(__MODULE__, {:add_user, user})
  end


  defp user_calls_under_limit?(user, state) do
    Map.get(state.users_operations, user, 0) <= @max_operations
  end

  defp user_exists?(user, state) do
    Map.has_key?(state.users_operations, user)
  end

end
