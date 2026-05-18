# stdlib/discordsph.sp — Discord library for Sapphire
# Part of the sph package ecosystem
#
# Usage:
#   import discordsph
#
#   let client = discord_client("YOUR_BOT_TOKEN")
#   client.on_message({ |msg|
#     if msg.content == "!ping" {
#       msg.reply("Pong!")
#     }
#   })
#   client.login()

# ─── Internal HTTP helper ─────────────────────────────────────────────────────

fn _discord_api_url(path) {
  return "https://discord.com/api/v10" + path
}

fn _discord_get(token, path) {
  let url = _discord_api_url(path)
  let headers = {
    "Authorization": "Bot " + token,
    "Content-Type": "application/json",
    "User-Agent": "DiscordSPH (Sapphire, 1.0.0)"
  }
  return HTTP.get(url, headers)
}

fn _discord_post(token, path, body) {
  let url = _discord_api_url(path)
  let headers = {
    "Authorization": "Bot " + token,
    "Content-Type": "application/json",
    "User-Agent": "DiscordSPH (Sapphire, 1.0.0)"
  }
  return HTTP.post(url, body, headers)
}

fn _discord_patch(token, path, body) {
  let url = _discord_api_url(path)
  let headers = {
    "Authorization": "Bot " + token,
    "Content-Type": "application/json",
    "User-Agent": "DiscordSPH (Sapphire, 1.0.0)"
  }
  return HTTP.patch(url, body, headers)
}

fn _discord_delete(token, path) {
  let url = _discord_api_url(path)
  let headers = {
    "Authorization": "Bot " + token,
    "Content-Type": "application/json",
    "User-Agent": "DiscordSPH (Sapphire, 1.0.0)"
  }
  return HTTP.delete(url, headers)
}

# ─── Message object ───────────────────────────────────────────────────────────

fn make_message(token, raw) {
  let msg = {
    "id":         raw["id"],
    "content":    raw["content"],
    "channel_id": raw["channel_id"],
    "guild_id":   raw["guild_id"],
    "author":     raw["author"],
    "timestamp":  raw["timestamp"],
    "tts":        raw["tts"],
    "pinned":     raw["pinned"],
    "embeds":     raw["embeds"],
    "attachments":raw["attachments"],
    "mentions":   raw["mentions"],

    "reply": fn(content) {
      let body = { "content": content }
      return _discord_post(token, "/channels/" + raw["channel_id"] + "/messages", body)
    },

    "reply_embed": fn(embed) {
      let body = { "embeds": [embed] }
      return _discord_post(token, "/channels/" + raw["channel_id"] + "/messages", body)
    },

    "react": fn(emoji) {
      let encoded = HTTP.url_encode(emoji)
      return _discord_put(token, "/channels/" + raw["channel_id"] + "/messages/" + raw["id"] + "/reactions/" + encoded + "/@me", {})
    },

    "delete": fn() {
      return _discord_delete(token, "/channels/" + raw["channel_id"] + "/messages/" + raw["id"])
    },

    "pin": fn() {
      return _discord_put(token, "/channels/" + raw["channel_id"] + "/pins/" + raw["id"], {})
    },

    "author_id": fn() {
      return raw["author"]["id"]
    },

    "author_name": fn() {
      return raw["author"]["username"]
    },

    "is_bot": fn() {
      let author = raw["author"]
      if author == nil { return false }
      return author["bot"] == true
    }
  }
  return msg
}

# ─── Channel helpers ──────────────────────────────────────────────────────────

fn make_channel(token, raw) {
  return {
    "id":   raw["id"],
    "name": raw["name"],
    "type": raw["type"],
    "guild_id": raw["guild_id"],
    "topic": raw["topic"],
    "nsfw":  raw["nsfw"],
    "position": raw["position"],

    "send": fn(content) {
      let body = { "content": content }
      return _discord_post(token, "/channels/" + raw["id"] + "/messages", body)
    },

    "send_embed": fn(embed) {
      let body = { "embeds": [embed] }
      return _discord_post(token, "/channels/" + raw["id"] + "/messages", body)
    },

    "typing": fn() {
      return _discord_post(token, "/channels/" + raw["id"] + "/typing", {})
    },

    "history": fn(limit) {
      if limit == nil { limit = 50 }
      return _discord_get(token, "/channels/" + raw["id"] + "/messages?limit=" + str(limit))
    },

    "pin_message": fn(message_id) {
      return _discord_put(token, "/channels/" + raw["id"] + "/pins/" + message_id, {})
    },

    "set_topic": fn(topic) {
      let body = { "topic": topic }
      return _discord_patch(token, "/channels/" + raw["id"], body)
    }
  }
}

# ─── Guild (server) helpers ───────────────────────────────────────────────────

fn make_guild(token, raw) {
  return {
    "id":   raw["id"],
    "name": raw["name"],
    "icon": raw["icon"],
    "owner_id": raw["owner_id"],
    "member_count": raw["member_count"],
    "description": raw["description"],

    "get_channel": fn(channel_id) {
      let res = _discord_get(token, "/channels/" + channel_id)
      if res == nil { return nil }
      return make_channel(token, res)
    },

    "get_channels": fn() {
      let res = _discord_get(token, "/guilds/" + raw["id"] + "/channels")
      if res == nil { return [] }
      return res.map({ |c| make_channel(token, c) })
    },

    "get_member": fn(user_id) {
      return _discord_get(token, "/guilds/" + raw["id"] + "/members/" + user_id)
    },

    "kick": fn(user_id, reason) {
      let headers_extra = make_hash()
      if reason != nil {
        headers_extra["X-Audit-Log-Reason"] = reason
      }
      return _discord_delete(token, "/guilds/" + raw["id"] + "/members/" + user_id)
    },

    "ban": fn(user_id, delete_days, reason) {
      if delete_days == nil { delete_days = 0 }
      let body = { "delete_message_days": delete_days }
      if reason != nil { body["reason"] = reason }
      return _discord_put(token, "/guilds/" + raw["id"] + "/bans/" + user_id, body)
    },

    "unban": fn(user_id) {
      return _discord_delete(token, "/guilds/" + raw["id"] + "/bans/" + user_id)
    },

    "create_role": fn(name, color, hoist, mentionable) {
      let body = {
        "name": name,
        "color": color,
        "hoist": hoist == true,
        "mentionable": mentionable == true
      }
      return _discord_post(token, "/guilds/" + raw["id"] + "/roles", body)
    }
  }
}

# ─── Embed builder ────────────────────────────────────────────────────────────

fn embed(title, description, color) {
  if color == nil { color = 0x5865F2 }
  let e = {
    "title": title,
    "description": description,
    "color": color,
    "fields": [],

    "add_field": fn(name, value, inline) {
      let f = { "name": name, "value": value, "inline": inline == true }
      e["fields"].push(f)
      return e
    },

    "set_footer": fn(text, icon_url) {
      e["footer"] = { "text": text }
      if icon_url != nil { e["footer"]["icon_url"] = icon_url }
      return e
    },

    "set_author": fn(name, url, icon_url) {
      e["author"] = { "name": name }
      if url != nil { e["author"]["url"] = url }
      if icon_url != nil { e["author"]["icon_url"] = icon_url }
      return e
    },

    "set_thumbnail": fn(url) {
      e["thumbnail"] = { "url": url }
      return e
    },

    "set_image": fn(url) {
      e["image"] = { "url": url }
      return e
    },

    "set_timestamp": fn(iso_string) {
      if iso_string == nil {
        e["timestamp"] = Sys.time()
      } else {
        e["timestamp"] = iso_string
      }
      return e
    }
  }
  return e
}

# Predefined embed colors
let DISCORD_COLORS = {
  "blurple":    5793266,
  "green":      5763719,
  "yellow":     16776960,
  "red":        15548997,
  "white":      16777215,
  "black":      2303786,
  "gold":       15844367,
  "orange":     15105570,
  "purple":     10181046,
  "dark_gray":  2895667,
  "blue":       3447003
}

# ─── Command router ───────────────────────────────────────────────────────────

fn make_command_router(prefix) {
  let _commands = make_hash()
  let _prefix = prefix

  let router = {
    "commands": _commands,
    "prefix": _prefix,

    "register": fn(name, handler) {
      _commands[name] = handler
    },

    "handle": fn(msg) {
      let content = msg["content"]
      if content == nil { return false }
      if !content.starts_with?(_prefix) { return false }

      let without_prefix = content.slice(len(_prefix), len(content) - len(_prefix))
      let parts = without_prefix.split(" ")
      if parts.length == 0 { return false }

      let cmd_name = parts[0]
      let args = parts.slice(1, parts.length - 1)

      let handler = _commands[cmd_name]
      if handler == nil {
        return false
      }

      handler(msg, args)
      return true
    },

    "list": fn() {
      return _commands.keys()
    }
  }

  return router
}

# ─── Event emitter ────────────────────────────────────────────────────────────

fn make_event_emitter() {
  let _handlers = make_hash()

  return {
    "on": fn(event, handler) {
      if _handlers[event] == nil {
        _handlers[event] = []
      }
      _handlers[event].push(handler)
    },

    "emit": fn(event, data) {
      let handlers = _handlers[event]
      if handlers == nil { return }
      handlers.each({ |h| h(data) })
    },

    "off": fn(event) {
      _handlers[event] = []
    }
  }
}

# ─── Client (main entry point) ────────────────────────────────────────────────

fn discord_client(token) {
  let _events = make_event_emitter()
  let _token = token
  let _prefix = "!"
  let _router = nil
  let _running = false

  let client = {
    "token": token,

    # Event registration
    "on": fn(event, handler) {
      _events.emit("register", { "event": event, "handler": handler })
      _events.on(event, handler)
    },

    # Convenience shorthand for on("message", ...)
    "on_message": fn(handler) {
      _events.on("message", handler)
    },

    "on_ready": fn(handler) {
      _events.on("ready", handler)
    },

    "on_error": fn(handler) {
      _events.on("error", handler)
    },

    # Set command prefix and get router
    "use_commands": fn(prefix) {
      if prefix == nil { prefix = "!" }
      _prefix = prefix
      _router = make_command_router(prefix)

      # Wire command router into message event
      _events.on("message", { |msg|
        _router.handle(msg)
      })

      return _router
    },

    # REST helpers exposed on client
    "get_channel": fn(channel_id) {
      let res = _discord_get(_token, "/channels/" + channel_id)
      if res == nil { return nil }
      return make_channel(_token, res)
    },

    "get_guild": fn(guild_id) {
      let res = _discord_get(_token, "/guilds/" + guild_id)
      if res == nil { return nil }
      return make_guild(_token, res)
    },

    "get_user": fn(user_id) {
      return _discord_get(_token, "/users/" + user_id)
    },

    "get_me": fn() {
      return _discord_get(_token, "/users/@me")
    },

    "send_message": fn(channel_id, content) {
      let body = { "content": content }
      return _discord_post(_token, "/channels/" + channel_id + "/messages", body)
    },

    "send_embed": fn(channel_id, emb) {
      let body = { "embeds": [emb] }
      return _discord_post(_token, "/channels/" + channel_id + "/messages", body)
    },

    "set_status": fn(status, activity_type, activity_name) {
      # activity_type: 0=Playing, 1=Streaming, 2=Listening, 3=Watching, 5=Competing
      if activity_type == nil { activity_type = 0 }
      let body = {
        "op": 3,
        "d": {
          "since": nil,
          "activities": [{
            "name": activity_name,
            "type": activity_type
          }],
          "status": status,
          "afk": false
        }
      }
      return GATEWAY.send_payload(_token, body)
    },

    # Connect and begin polling (Gateway via WebSocket bridge)
    "login": fn() {
      println("[discordsph] Connecting to Discord Gateway...")
      let me = _discord_get(_token, "/users/@me")
      if me == nil {
        println("[discordsph] ERROR: Invalid token or network error.")
        return
      }
      println("[discordsph] Logged in as: " + me["username"] + "#" + me["discriminator"])
      _events.emit("ready", { "user": me })
      _running = true

      # Start Gateway polling loop
      GATEWAY.connect(_token, { |event_name, raw_data|
        if event_name == "MESSAGE_CREATE" {
          let msg = make_message(_token, raw_data)
          if !msg.is_bot() {
            _events.emit("message", msg)
          }
        } else {
          if event_name == "GUILD_CREATE" {
            _events.emit("guild_join", make_guild(_token, raw_data))
          } else {
            if event_name == "GUILD_DELETE" {
              _events.emit("guild_leave", raw_data)
            } else {
              if event_name == "GUILD_MEMBER_ADD" {
                _events.emit("member_join", raw_data)
              } else {
                if event_name == "GUILD_MEMBER_REMOVE" {
                  _events.emit("member_leave", raw_data)
                } else {
                  if event_name == "MESSAGE_REACTION_ADD" {
                    _events.emit("reaction_add", raw_data)
                  } else {
                    if event_name == "MESSAGE_REACTION_REMOVE" {
                      _events.emit("reaction_remove", raw_data)
                    } else {
                      _events.emit("raw", { "type": event_name, "data": raw_data })
                    }
                  }
                }
              }
            }
          }
        }
      })
    },

    "logout": fn() {
      _running = false
      GATEWAY.disconnect(_token)
      println("[discordsph] Disconnected.")
    }
  }

  return client
}

# ─── Utility functions ────────────────────────────────────────────────────────

fn discord_mention(user_id) {
  return "<@" + user_id + ">"
}

fn discord_channel_mention(channel_id) {
  return "<#" + channel_id + ">"
}

fn discord_role_mention(role_id) {
  return "<@&" + role_id + ">"
}

fn discord_bold(text) {
  return "**" + text + "**"
}

fn discord_italic(text) {
  return "*" + text + "*"
}

fn discord_code(text) {
  return "`" + text + "`"
}

fn discord_code_block(lang, text) {
  if lang == nil { lang = "" }
  return "```" + lang + "\n" + text + "\n```"
}

fn discord_spoiler(text) {
  return "||" + text + "||"
}

fn discord_strikethrough(text) {
  return "~~" + text + "~~"
}

fn discord_underline(text) {
  return "__" + text + "__"
}

fn discord_timestamp(unix_seconds, style) {
  # Styles: t=short time, T=long time, d=short date, D=long date,
  #         f=short date+time, F=long date+time, R=relative (default)
  if style == nil { style = "R" }
  return "<t:" + str(unix_seconds) + ":" + style + ">"
}
