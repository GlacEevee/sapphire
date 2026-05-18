# stdlib/datetime.sp — Date/time helpers for Sapphire

fn now() {
  return Sys.time()
}

fn timestamp() {
  return int(Sys.time())
}

fn elapsed_since(start_time) {
  return Sys.time() - start_time
}

fn format_duration(seconds) {
  let s = int(seconds)
  if s < 60 { return `#{s}s` }
  if s < 3600 {
    let m = int(s / 60)
    let rem = s % 60
    return `#{m}m #{rem}s`
  }
  let h = int(s / 3600)
  let m = int((s % 3600) / 60)
  return `#{h}h #{m}m`
}

fn sleep_ms(ms) {
  sleep(ms / 1000.0)
}

fn benchmark(label, fn_to_run) {
  let start = Sys.time()
  fn_to_run()
  let elapsed = Sys.time() - start
  println(`[benchmark] #{label}: #{elapsed}s`)
  return elapsed
}
