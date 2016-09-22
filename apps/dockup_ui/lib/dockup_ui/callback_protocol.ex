defprotocol DockupUi.CallbackProtocol do
  # All deployments are created with this initial status. Payload is nil
  def queued(callback_data, deployment, payload)

  # Called before cloning git repo. Payload is nil
  def cloning_repo(callback_data, deployment, payload)

  # Called when docker containers are being started. Payload is a string
  # containing the log URL. Format: "/deployment_logs/#?projectName=<project id>"
  def starting(callback_data, deployment, payload)

  # Called when docker containers are started and service URLs are assigned
  # and tested for HTTP response status of 200
  def checking_urls(callback_data, deployment, payload)

  # Called when docker containers are started and service URLs
  # are assigned. Payload is a map of the format:
  # %{"service_name" => [{"container_port", "url"}, ...], ...}
  def started(callback_data, deployment, payload)

  # Called when deployment fails. Payload is a string containing
  # the reason for failure
  def deployment_failed(callback_data, deployment, payload)

  # CallbackProtocol implementors may implement a function named
  # common_callback(data, deployment, payload) if multiple events are to
  # be handled in the same way
end

defmodule DockupUi.CallbackProtocol.Defaults do
  defmacro __using__(_) do
    quote do
      def queued(data, deployment, payload), do: common_callback(data, deployment, payload)
      def cloning_repo(data, deployment, payload), do: common_callback(data, deployment, payload)
      def starting(data, deployment, payload), do: common_callback(data, deployment, payload)
      def checking_urls(data, deployment, payload), do: common_callback(data, deployment, payload)
      def started(data, deployment, payload), do: common_callback(data, deployment, payload)
      def deployment_failed(data, deployment, payload), do: common_callback(data, deployment, payload)
      def common_callback(_data, _deployment, _payload), do: :ok

      defoverridable [
        queued: 3, cloning_repo: 3, starting: 3, checking_urls: 3,
        started: 3, deployment_failed: 3, common_callback: 3
      ]
    end
  end
end
