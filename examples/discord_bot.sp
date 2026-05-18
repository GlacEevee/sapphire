# examples/discord_bot.sp — Example Discord bot using discordsph
#
# Run:
#   sapphire run examples/discord_bot.sp
#
# Make sure your token is set:
#   export DISCORD_TOKEN=your_bot_token_here

import discordsph

# ── Setup ──────────────────────────────────────────────────────────────────────

let token = Sys.env("DISCORD_TOKEN")

if token == nil {
  println("Error: DISCORD_TOKEN environment variable not set.")
  println("Set it with:  export DISCORD_TOKEN=your_token")
  exit(1)
}

let client = discord_client(token)
let commands = client.use_commands("!")

# ── Commands ───────────────────────────────────────────────────────────────────

commands.register("ping", fn(msg, args) {
  msg.reply("🏓 Pong! Latency: < 1ms")
})

commands.register("hello", fn(msg, args) {
  let name = msg.author_name()
  msg.reply("Hey there, " + discord_bold(name) + "! 👋")
})

commands.register("info", fn(msg, args) {
  let e = embed("Bot Info", "Running on **discordsph** — the Sapphire Discord library.", DISCORD_COLORS["blurple"])
  e.add_field("Language", "Sapphire 1.0", true)
  e.add_field("Package", "discordsph v1.0.0", true)
  e.add_field("Commands", commands.list().join(", "), false)
  e.set_footer("Made with ❤️ in Sapphire")
  e.set_timestamp(nil)
  msg.reply_embed(e)
})

commands.register("echo", fn(msg, args) {
  if args.length == 0 {
    msg.reply("Usage: !echo <text>")
    return
  }
  let text = args.join(" ")
  msg.reply(discord_italic(text))
})

commands.register("code", fn(msg, args) {
  if args.length == 0 {
    msg.reply("Usage: !code <snippet>")
    return
  }
  let snippet = args.join(" ")
  msg.reply(discord_code_block("sp", snippet))
})

commands.register("spoiler", fn(msg, args) {
  if args.length == 0 {
    msg.reply("Usage: !spoiler <text>")
    return
  }
  msg.reply(discord_spoiler(args.join(" ")))
})

commands.register("timestamp", fn(msg, args) {
  let now = int(Sys.time())
  msg.reply("Current time: " + discord_timestamp(now, "F") + " (" + discord_timestamp(now, "R") + ")")
})

commands.register("math", fn(msg, args) {
  if args.length < 3 {
    msg.reply("Usage: !math <a> <op> <b>  (ops: + - * /)")
    return
  }
  let a = float(args[0])
  let op = args[1]
  let b = float(args[2])
  let result = 0

  if op == "+"      { result = a + b }
  else if op == "-" { result = a - b }
  else if op == "*" { result = a * b }
  else if op == "/" {
    if b == 0 { msg.reply("❌ Cannot divide by zero!"); return }
    result = a / b
  } else {
    msg.reply("Unknown operator: " + op)
    return
  }

  msg.reply(discord_code(str(a) + " " + op + " " + str(b) + " = " + str(result)))
})

commands.register("help", fn(msg, args) {
  let e = embed("📖 Help", "All available commands for this bot.", DISCORD_COLORS["green"])
  e.add_field("!ping",             "Check if the bot is alive",           false)
  e.add_field("!hello",            "Get a greeting",                      false)
  e.add_field("!info",             "Show bot information",                false)
  e.add_field("!echo <text>",      "Echo your message back in italics",   false)
  e.add_field("!code <snippet>",   "Wrap text in a code block",           false)
  e.add_field("!spoiler <text>",   "Hide text as a spoiler",              false)
  e.add_field("!timestamp",        "Show current Discord timestamp",      false)
  e.add_field("!math <a> <op> <b>","Simple math (+, -, *, /)",           false)
  e.add_field("!roll <sides>",     "Roll a dice",                         false)
  e.add_field("!help",             "Show this message",                   false)
  msg.reply_embed(e)
})

commands.register("roll", fn(msg, args) {
  let sides = 6
  if args.length > 0 {
    sides = int(args[0])
    if sides < 2 { sides = 2 }
    if sides > 1000 { sides = 1000 }
  }
  let roll = Math.rand_int(sides) + 1
  msg.reply("🎲 You rolled a **" + str(roll) + "** (d" + str(sides) + ")")
})

# ── Lifecycle events ───────────────────────────────────────────────────────────

client.on_ready(fn(data) {
  let user = data["user"]
  println("✅ Bot is online as: " + user["username"])
  println("📡 Listening for commands with prefix: !")
})

client.on_error(fn(err) {
  println("❌ Error: " + str(err))
})

# ── Connect ────────────────────────────────────────────────────────────────────

client.login()
