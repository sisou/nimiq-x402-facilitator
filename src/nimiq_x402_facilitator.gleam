import app/config
import app/router
import gleam/erlang/process
import mist
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()
  wisp.set_logger_level(wisp.DebugLevel)
  let secret_key_base = wisp.random_string(64)

  let config = config.load()
  let handler = router.handle_request(_, config)

  let assert Ok(_) =
    wisp_mist.handler(handler, secret_key_base)
    |> mist.new
    |> mist.bind(config.host)
    |> mist.port(config.port)
    |> mist.start

  process.sleep_forever()
}
