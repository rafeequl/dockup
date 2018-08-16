defmodule Dockup.Backends.Fake do
  alias Dockup.Spec

  use GenServer

  @behaviour Spec

  @impl Spec
  def start(%{name: name, deployment_id: deployment_id}) do
    start_server()
    handle = "#{name}-#{deployment_id}"
    GenServer.cast(__MODULE__, {:start, handle})

    {:ok, handle}
  end

  @impl Spec
  def hibernate(handle) do
    start_server()
    GenServer.cast(__MODULE__, {:hibernate, handle})
    :ok
  end

  @impl Spec
  def wake_up(handle) do
    start_server()
    GenServer.cast(__MODULE__, {:wake_up, handle})
    :ok
  end

  @impl Spec
  def delete(handle) do
    start_server()
    GenServer.cast(__MODULE__, {:delete, handle})
    :ok
  end

  @impl Spec
  def status(handle) do
    start_server()
    GenServer.call(__MODULE__, {:get_status, handle})
  end

  @impl Spec
  def logs(_) do
    "Log string"
  end

  @impl Spec
  def hostname(_, _) do
    "example.com"
  end

  ##########GenServer###########
  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:start, handle}, state) do
    send self(), {:set_state, handle, "pending"}
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:hibernate, handle}, state) do
    state_change_after(handle, 2000, "unknown")
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:wake_up, handle}, state) do
    send self(), {:set_state, handle, "pending"}
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:delete, handle}, state) do
    state_change_after(handle, 2000, "unknown")
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:get_status, handle}, _from, state) do
    status = Map.get(state, handle, "running")
    {:reply, {status, nil}, state}
  end

  @impl GenServer
  def handle_info({:set_state, handle, "pending"}, state) do
    state_change_after(handle, 2000, "running")
    state = change_state(handle, "pending", state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:set_state, handle, status}, state) when status in ["running", "unknown"] do
    state = change_state(handle, status, state)
    {:noreply, state}
  end

  defp start_server do
    unless GenServer.whereis(__MODULE__) do
      GenServer.start(__MODULE__, [], name: __MODULE__)
    end
  end

  defp state_change_after(handle, msec, state) do
    Process.send_after(self(), {:set_state, handle, state}, msec)
  end

  defp change_state(handle, status, state) do
    Map.put(state, handle, status)
  end
end
