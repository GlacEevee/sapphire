# discordsph — Discord for Sapphire

`discordsph` is the official Discord bot library for the Sapphire language,
distributed through the `sph` package manager.

---

## Installation

```sh
sph install discordsph
```

Or add it to your `sapphire.json`:

```json
{
  "dependencies": {
    "discordsph": "^1.0.0"
  }
}
```

Then run `sph install`.

---

## Quick Start

```sp
import discordsph

let client = discord_client(Sys.env("DISCORD_TOKEN"))
let commands = client.use_commands("!")

commands.register("ping", fn(msg, args) {
  msg.reply("Pong!")
})

client.on_ready(fn(data) {
  println("Logged in as: " + data["user"]["username"])
})

client.login()
```

---

## API Reference

### `discord_client(token)`

Creates a new bot client.

| Method | Description |
|---|---|
| `client.login()` | Connect and start the event loop |
| `client.logout()` | Disconnect |
| `client.on_ready(fn)` | Fired when bot connects |
| `client.on_message(fn)` | Fired on every message |
| `client.on_error(fn)` | Fired on errors |
| `client.use_commands(prefix)` | Enable command router, returns router |
| `client.get_channel(id)` | Fetch a channel object |
| `client.get_guild(id)` | Fetch a guild (server) object |
| `client.get_user(id)` | Fetch a user object |
| `client.get_me()` | Fetch the bot's own user |
| `client.send_message(channel_id, content)` | Send a plain message |
| `client.send_embed(channel_id, embed)` | Send an embed |
| `client.set_status(status, type, name)` | Set bot presence |

---

### Command Router

```sp
let commands = client.use_commands("!")

commands.register("greet", fn(msg, args) {
  msg.reply("Hello, " + args[0] + "!")
})
```

`args` is an array of strings after the command name.

---

### Message Object

| Field/Method | Description |
|---|---|
| `msg.content` | Raw message text |
| `msg.id` | Message snowflake ID |
| `msg.channel_id` | Channel the message was sent in |
| `msg.guild_id` | Guild (server) ID |
| `msg.author` | Author hash (`username`, `id`, `bot`) |
| `msg.author_name()` | Shortcut: author's username |
| `msg.author_id()` | Shortcut: author's user ID |
| `msg.is_bot()` | Whether the author is a bot |
| `msg.reply(content)` | Reply with plain text |
| `msg.reply_embed(embed)` | Reply with an embed |
| `msg.react(emoji)` | React with an emoji |
| `msg.delete()` | Delete the message |
| `msg.pin()` | Pin the message |

---

### Embed Builder

```sp
let e = embed("Title", "Description", DISCORD_COLORS["blurple"])
e.add_field("Field", "Value", true)   # true = inline
e.set_footer("Footer text")
e.set_thumbnail("https://example.com/thumb.png")
e.set_image("https://example.com/img.png")
e.set_author("Author Name", nil, nil)
e.set_timestamp(nil)   # nil = current time

msg.reply_embed(e)
```

#### Available colors (`DISCORD_COLORS`)

`blurple`, `green`, `yellow`, `red`, `white`, `black`,
`gold`, `orange`, `purple`, `dark_gray`, `blue`

---

### Channel Object

```sp
let ch = client.get_channel("123456789")
ch.send("Hello from Sapphire!")
ch.send_embed(e)
ch.typing()                # Send typing indicator
ch.history(50)             # Fetch last N messages
ch.set_topic("New topic")
```

---

### Guild Object

```sp
let guild = client.get_guild("987654321")
guild.get_channels()       # Array of channel objects
guild.get_member(user_id)
guild.kick(user_id, "reason")
guild.ban(user_id, 7, "reason")
guild.unban(user_id)
guild.create_role("Moderator", DISCORD_COLORS["red"], true, true)
```

---

### Formatting Helpers

```sp
discord_bold("text")             # **text**
discord_italic("text")           # *text*
discord_code("text")             # `text`
discord_code_block("sp", "text") # ```sp\ntext\n```
discord_spoiler("text")          # ||text||
discord_strikethrough("text")    # ~~text~~
discord_underline("text")        # __text__
discord_mention(user_id)         # <@user_id>
discord_channel_mention(ch_id)   # <#ch_id>
discord_role_mention(role_id)    # <@&role_id>
discord_timestamp(unix, "R")     # <t:unix:R>
```

---

### Events

| Event | Payload |
|---|---|
| `ready` | `{ user: { username, id, ... } }` |
| `message` | Message object |
| `guild_join` | Guild object |
| `guild_leave` | Raw guild data |
| `member_join` | Raw member data |
| `member_leave` | Raw member data |
| `reaction_add` | Raw reaction data |
| `reaction_remove` | Raw reaction data |
| `raw` | `{ type: event_name, data: raw }` |

---

## Gateway Note

`discordsph` ships with an HTTP REST bridge for all API calls. The Gateway
event loop currently runs in HTTP polling mode. For full real-time WebSocket
support, install the `websocket-driver` Ruby gem and upgrade the `GATEWAY`
native in `interpreter.rb` to a true WS connection.

---

## License

MIT — part of the Sapphire standard library ecosystem.
