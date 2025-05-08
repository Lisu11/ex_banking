defmodule TransactionTaskTest do
  use ExUnit.Case, async: true
  alias ExBanking.TransactionTask

  describe "async/1" do
    test "creates a new task" do
      task = TransactionTask.async(fn -> :ok end)
      assert %Task{} = task
    end
  end

  describe "run/1" do
    test "starts a task and executes the transaction" do
      %{pid: pid, ref: ref} = task = TransactionTask.async(fn -> :ok end)
      TransactionTask.commit(task)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1000
    end
  end

  describe "rollback/1" do
    test "aborts a task before it starts" do
      task = TransactionTask.async(fn -> :ok end)
      TransactionTask.rollback(task)

      :timer.sleep(5)
      refute Process.alive?(task.pid)
    end
  end
end
