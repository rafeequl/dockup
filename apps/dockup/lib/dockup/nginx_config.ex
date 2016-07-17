defmodule Dockup.NginxConfig do
  require Logger

  def default_config do
    """
    server {
      listen 80 default_server;
      listen [::]:80 default_server ipv6only=on;
      listen 443 default_server ssl;
      listen [::]:443 default_server ssl ipv6only=on;

      return 404;

      server_name _ ;
    }
    """
  end

  # accepts a urls_proxies tuple.
  # e.g.
  # [{"3000", "http://fake_host:3000", "shy-surf-3571.127.0.0.1.xip.io"}
  # {"3001", "http://fake_host:3001", "long-flower-2811.127.0.0.1.xip.io"}
  # {"8080", "http://fake_host2:8080", "crimson-meadow-2.127.0.0.1.xip.io"}]
  def config_proxy_passing_port(urls_proxies) do
    Enum.map(urls_proxies, &proxy_passing_port&1) |> Enum.join("\n")
  end

  def config_file(project_id) do
    Path.join(Dockup.Configs.nginx_config_dir, "#{project_id}.conf")
  end

  # Given a project_id and docker ports, writes the nginx config to
  # proxy pass haikunated URLs to the docker ports
  def write_config(project_id, ips_ports, haikunator \\ Dockup.Haikunator) do
    Logger.info "Writing nginx config to serve #{project_id}"
    ports_urls = Enum.reduce(ips_ports, [], fn({ip, ports}, acc) ->
      acc ++ Enum.map(ports, fn(port) ->
        {port, "http://#{ip}:#{port}", haikunator.haikunated_url}
      end)
    end)
    config = config_proxy_passing_port(ports_urls)
    File.write(config_file(project_id), config)
    ports_urls
  end

  def proxy_passing_port({port, proxy, url}) do
    """
    server {
      listen #{port};
      server_name #{url};

      location / {
        proxy_pass #{proxy};
        proxy_set_header Host $host;
      }
    }
    """
  end
end