module GenieAutoReload

using Revise
__revise_mode__ = :eval

using Genie, Genie.Router, Genie.WebChannels
using Distributed, Logging

export autoreload

Genie.config.websockets_server = true

const WEBCHANNEL_NAME = "autoreload"
const WATCH_KEY = "autoreload"
const assets_config = Genie.Assets.AssetsConfig(package = "GenieAutoReload.jl")

function watch(files::Vector{String}, extensions::Vector{String} = Genie.config.watch_extensions) :: Nothing
  @info "Watching $files"

  Genie.config.watch_handlers[WATCH_KEY] = [
    () -> @info("Autoreloading"),
    () -> Genie.WebChannels.broadcast(WEBCHANNEL_NAME, "autoreload:full")
  ]

  Genie.Watch.watchpath(files)

  nothing
end

function watch(files::String)
  watch(String[files])
end

function assets_js() :: String
  """
  function autoreload_subscribe() {
    Genie.WebChannels.sendMessageTo('autoreload', 'subscribe');
    console.info('Autoreloading ready');
  }

  setTimeout(autoreload_subscribe, 2000);

  Genie.WebChannels.messageHandlers.push(function(event) {
    if ( event.data == 'autoreload:full' ) {
      location.reload(true);
    }
  });
  """
end

function assets_script() :: String
  """
  <script>
  $(assets_js())
  </script>
  """
end

function assets(; devonly = true) :: String
  if (devonly && Genie.Configuration.isdev()) || !devonly
    Genie.Renderer.Html.script(src = Genie.Assets.asset_path(assets_config, :js, file="autoreload"))
  else
    ""
  end
end

function routing() :: Nothing
  if ! Genie.Assets.external_assets(assets_config)
    Genie.Router.route(Genie.Assets.asset_route(GenieAutoReload.assets_config, :js, file="autoreload")) do
      assets_js() |> Genie.Renderer.Js.js
    end
  end

  channel("/$(WEBCHANNEL_NAME)/subscribe") do
    WebChannels.subscribe(params(:WS_CLIENT), WEBCHANNEL_NAME)
  end

  nothing
end

function deps() :: Vector{String}
  routing()
  [assets()]
end

function autoreload(files::Vector{String}, extensions::Vector{String} = Genie.config.watch_extensions;
                    devonly::Bool = true)
  if devonly && !Genie.Configuration.isdev()
    @warn "AutoReload configured for dev environment only. Skipping."
    return nothing
  end

  routing()

  GenieAutoReload.watch(files, extensions)
end

function autoreload(files...; extensions::Vector{String} = Genie.config.watch_extensions, devonly = true)
  autoreload([files...], [extensions...]; devonly = devonly)
end

end # module