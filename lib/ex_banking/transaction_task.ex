defmodule ExBanking.TransactionTask do
  @moduledoc """
  This module is responsible for executing transactions in a separate process.
  """
  use Task

  require Logger

  def async(run_tx) do
    from = self()
    Task.async(__MODULE__, :run, [run_tx, from])
  end

  def commit(%Task{} = task) do
    send(task.pid, :start)
  end

  def rollback(%Task{} = task) do
    send(task.pid, :exit)
  end

  def run(run_tx, _from) do
    :ok = wait_to_start()

    try do
      {:vault, run_tx.()}
    rescue
      e ->
        Logger.error(Exception.format(:error, e, __STACKTRACE__))
        reraise e, __STACKTRACE__
    end
  end

  defp wait_to_start() do
    receive do
      :start ->
        Logger.debug("Task started")
        :ok

      :exit ->
        Logger.debug("Task not started")
        Process.exit(self(), :normal)
    end
  end
end
