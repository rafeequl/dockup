defmodule Dockup.ContainerTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  test "create_cache_container creates a cache container if it does not exist" do
    defmodule CacheCreationCommand do
      def run(cmd, args) do
        send self(), {cmd, args}
        {:ok, 0}
      end
    end

    Dockup.Container.create_cache_container(CacheCreationCommand)

    [cmd | args] = String.split("docker run --name cache -v /cache tianon/true")
    receive do
      {command, arguments} ->
        assert command == cmd
        assert arguments == args
    end
  end

  test "create_cache_container does nothing and logs warning if cache container already exists" do
    defmodule CacheExistsCommand do
      def run(_cmd, _args) do
        {:ok, 1}
      end
    end

    assert capture_log(fn ->
      Dockup.Container.create_cache_container(CacheExistsCommand)
    end) =~ "Cannot create docker container cache. It may already exist"
  end

  test "check_docker_version raises exception if docker version is incompatible" do
    defmodule OldDockerVersionCommand do
      def run(cmd, args) do
        case {cmd, args} do
          {"docker", ["-v"]} -> {"Docker version 1.7", 0}
          {"docker-compose",  ["-v"]} -> {"docker-compose version 1.4", 0}
        end
      end
    end

    try do
      Dockup.Container.check_docker_version(OldDockerVersionCommand)
    rescue
      exception -> assert exception.message == "Docker version should be >= 1.8"
    end
  end

  test "check_docker_version raises exception if docker-compose version is incompatible" do
    defmodule OldDockerComposeVersionCommand do
      def run(cmd, args) do
        case {cmd, args} do
          {"docker", ["-v"]} -> {"Docker version 1.8", 0}
          {"docker-compose",  ["-v"]} -> {"docker-compose version 1.3", 0}
        end
      end
    end

    try do
      Dockup.Container.check_docker_version(OldDockerComposeVersionCommand)
    rescue
      exception -> assert exception.message == "docker-compose version should be >= 1.4"
    end
  end

  test "check_docker_version does not raise any exception if versions are compatible" do
    defmodule MatchingDockerVersion do
      def run(cmd, args) do
        case {cmd, args} do
          {"docker", ["-v"]} -> {"Docker version 1.8", 0}
          {"docker-compose",  ["-v"]} -> {"docker-compose version 1.4", 0}
        end
      end
    end

    Dockup.Container.check_docker_version(MatchingDockerVersion)
  end

  test "run_nginx_container stops nginx container, writes default configs and starts nginx container" do
    defmodule NginxCommand do
      def run(cmd, args) do
        case {cmd, args} do
          {"docker", ["rm", "-v", "-f", "nginx"]} -> {"", 0}
          {"docker", _} -> {"okay", 0}
        end
      end
    end

    defmodule FakeContainer do
      def nginx_config_dir_on_host, do: "fake_dir_on_host"
      def config_dir_on_host, do: "config_dir_on_host"
      def dockup_container_id, do: "dockup_container_id"
      def container_ip("dockup_container_id"), do: "dockup_container_ip"
      def container_ip("logio"), do: "logio_container_ip"
    end

    logs = capture_log(fn -> Dockup.Container.run_nginx_container(NginxCommand, FakeContainer) end)
    assert File.read!(Dockup.Configs.config_file("dockup.conf"))
      == Dockup.NginxConfig.dockup_config("127.0.0.1.xip.io", "dockup_container_ip", "logio_container_ip")
    assert File.read!(Dockup.Configs.config_file("nginx.conf"))
      == Dockup.NginxConfig.nginx_conf
    assert logs =~ "Removing nginx container"
    assert logs =~ "Nginx container started"

    File.rm! Dockup.Configs.config_file("dockup.conf")
    File.rm! Dockup.Configs.config_file("nginx.conf")
  end

  test "reload_nginx sends a kill signal to nginx docker container" do
    defmodule NginxReloadCommand do
      def run("docker", ["kill", "-s", "HUP", "nginx"]), do: {:ok, 0}
    end

    Dockup.Container.reload_nginx(NginxReloadCommand)
  end

  test "start_containers runs docker-compose up" do
    defmodule StartContainersCommand do
      def run("docker-compose", ["-p", "foo", "up", "-d"], dir) do
        # Ensure command is run inside project directory
        ^dir = Dockup.Project.project_dir("foo")
      end
    end
    Dockup.Container.start_containers("foo", StartContainersCommand)
  end

  test "stop_containers runs docker-compose down" do
    defmodule StopContainersCommand do
      def run("docker-compose", ["-p", "foo", "down", "-v"], dir) do
        # Ensure command is run inside project directory
        ^dir = Dockup.Project.project_dir("foo")
      end
    end
    Dockup.Container.stop_containers("foo", StopContainersCommand)
  end

  test "container_ids fetches docker container ids of docker-compose project" do
    defmodule ContainerIdCommand do
      def run("docker-compose", ["-p", "foo", "ps", "-q"], dir) do
        # Ensure command is run inside project directory
        ^dir = Dockup.Project.project_dir("foo")
        out = "  container1  \n container2  \n  container3"
        {out, 0}
      end
    end

    assert Dockup.Container.container_ids("foo", ContainerIdCommand)
      == ["container1", "container2", "container3"]
  end

  test "port_mappings_for_container returns a list of port mappings inside the container" do
    defmodule ContainerPortCommand do
      def run("docker", ["inspect", "--format='{{range $p, $conf := .NetworkSettings.Ports}}{{if $conf}}{{$p}}:{{(index $conf 0).HostPort}}\n{{end}}{{end}}'", "container1"]) do
        out = "   80/tcp:3227\n4000/tcp:3228\n   "
        {out, 0}
      end
    end

    assert Dockup.Container.port_mappings_for_container("container1", ContainerPortCommand)
      == [{"80", "3227"}, {"4000", "3228"}]
  end

  test "container_ip returns the IP of the docker container" do
    defmodule ContainerIpCommand do
      def run("docker", ["inspect", "--format='{{.NetworkSettings.IPAddress}}'", "container1"]) do
        out = "fake_ip"
        {out, 0}
      end
    end

    assert Dockup.Container.container_ip("container1", ContainerIpCommand)
      == "fake_ip"
  end

  test "port_mappings_for_container returns an empy list if no ports are exposed" do
    defmodule ContainerNoPortCommand do
      def run("docker", ["inspect", "--format='{{range $p, $conf := .NetworkSettings.Ports}}{{if $conf}}{{$p}}:{{(index $conf 0).HostPort}}\n{{end}}{{end}}'", "container1"]) do
        out = "  "
        {out, 0}
      end
    end

    assert Dockup.Container.port_mappings_for_container("container1", ContainerNoPortCommand)
      == []
  end

  test "port_mappings retrns services and port details of the containers of the project" do
    defmodule FakeIpPortsContainer do
      def container_ids("foo") do
        ["container1", "container2"]
      end

      def port_mappings_for_container("container1"), do: [{"80", "3227"}, {"4000", "3228"}]
      def port_mappings_for_container("container2"), do: []

      def container_service_name("container1"), do: "web"
      def container_service_name("container2"), do: "worker"

      def container_ip("container1"), do: "fake_ip1"
      def container_ip("container2"), do: "fake_ip2"
    end

    assert Dockup.Container.port_mappings("foo", FakeIpPortsContainer)
      ==  %{"web" => {"fake_ip1", [{"80", "3227"}, {"4000", "3228"}]}, "worker" => {"fake_ip2", []}}
  end
end
