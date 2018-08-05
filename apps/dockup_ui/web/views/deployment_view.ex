defmodule DockupUi.DeploymentView do
  use DockupUi.Web, :view

  def deployment_as_json(deployment) do
    DockupUi.API.DeploymentView.render("deployment_details.json", %{deployment: deployment})
    |> Poison.encode!()
  end

  def container_specs_json(blueprint) do
    blueprint.container_specs
    |> Enum.map(fn spec -> %{id: spec.id, image: spec.image, tag: spec.default_tag, name: spec.name} end)
    |> Poison.encode!()
  end
end
