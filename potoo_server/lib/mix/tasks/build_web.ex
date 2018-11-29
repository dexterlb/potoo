defmodule Mix.Tasks.BuildWeb do
  use Mix.Task
  use Mix.Releases.Plugin

  @shortdoc "builds web files in priv/static"
  def run(_) do
    # this is a major hack. fixme.
    f = __ENV__.file
    System.cmd("sh", [
      "-c", "
           cd \"$(dirname '#{f}')\"/../../.. \
        && mkdir -p priv/static \
        && pushd ../web_ui \
        && npm run make \
        && popd \
        && cp -rfvT ../web_ui/dist priv/static
      "
      ], into: IO.stream(:stdio, :line)
    )
  end

  def before_assembly(release, _opts) do
    info "building web files"
    run(nil)
    release
  end

  def after_assembly(release, _opts), do: release

  def before_package(release, _opts), do: release
  def after_package(release, _opts), do: release
end
