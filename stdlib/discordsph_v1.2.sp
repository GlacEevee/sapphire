# stdlib/discordsph.sp — Discord library for Sapphire
# Part of the sph package ecosystem
# Version: 1.2.0
#
# Changelog (1.2.0):
#   - make_thread(token, raw)       — Thread object with send/archive/members
#   - msg.create_thread(name, duration) — Create thread from a message
#   - channel.get_threads()         — Fetch active threads in a channel
#   - channel.create_thread(name, type, duration) — Create standalone thread
#   - client.on_thread_create(fn)   — THREAD_CREATE event
#   - client.on_thread_update(fn)   — THREAD_UPDATE event
#   - client.on_thread_delete(fn)   — THREAD_DELETE event
#   - guild.get_active_threads()    — All active threads in a guild
#   - embed.set_url(url)            — Add a hyperlink URL to embed title
#   - discord_header(text)          — # Heading markdown helper
#   - discord_subheader(text)       — ## Subheading markdown helper
#   - discord_list(items)           — Build a markdown bullet list
#
# Usage:
#   import discordsph

# ─── Internal HTTP helper ─────────────────────────────────────────────────────

fn _discord_api_url(path) {
  return "https://discord.com/api/v10" + path
}

fn _discord_get(token, path) {
  let url = _discord_api_url(path)
  let headers = {
    "Authorization": "Bot " + token,
    "Content-Type": "application/json",
    "User-Agent": "DiscordSPH (Sapphire, 1.2.0)"
  }
  return HTTP.get(url, headers)
}

fn _discord_post(token, path, body) {
  let url = _discord_api_url(path)
  let headers = {
    "Authorization": "Bot " + token,
    "Content-Type": "application/json",
    "User-Agent": "DiscordSPH (Sapphire, 1.2.0)"
  }
  return HTTP.post(url, body, headers)
}

fn _discord_patch(token, path, body) {
  let url = _discord_api_url(path)
  let headers = {
    "Authorization": "Bot " + token,
    "Content-Type": "application/json",
    "User-Agent": "DiscordSPH (Sapphire, 1.2.0)"
  }
  return HTTP.patch(url, body, headers)
}

fn _discord_delete(token, path) {
  let url = _discord_api_url(path)
  let headers = {
    "Authorization": "Bot " + token,
    "Content-Type": "application/json",
    "User-Agent": "DiscordSPH (Sapphire, 1.2.0)"
  }
  return HTTP.delete(url, headers)
}

fn _discord_put(token, path, body) {
  let url = _discord_api_url(path)
  let headers = {
    "Authorization": "Bot " + token,
    "Content-Type": "application/json",
    "User-Agent": "DiscordSPH (Sapphire, 1.2.0)"
  }
  return HTTP.put(url, body, headers)
}

# ─── Gateway intents ──────────────────────────────────────────────────────────

let DISCORD_INTENTS = {
  "guilds":                   1,
  "guild_members":            2,
  "guild_moderation":         4,
  "guild_emojis":             8,
  "guild_integrations":       16,
  "guild_webhooks":           32,
  "guild_invites":            64,
  "guild_voice_states":       128,
  "guild_presences":          256,
  "guild_messages":           512,
  "guild_message_reactions":  1024,
  "guild_message_typing":     2048,
  "direct_messages":          4096,
  "dm_reactions":             8192,
  "dm_typing":                16384,
  "message_content":          32768,
  "guild_scheduled_events":   65536
}

# ─── Thread object (NEW 1.2) ──────────────────────────────────────────────────

fn make_thread(token, raw) {
  return {
    "id":        raw["id"],
    "name":      raw["name"],
    "parent_id": raw["parent_id"],
    "guild_id":  raw["guild_id"],
    "owner_id":  raw["owner_id"],
    "message_count": raw["message_count"],
    "member_count":  raw["member_count"],

    "send": fn(content) {
      let body = { "content": content }
      return _discord_post(token, "/channels/" + raw["id"] + "/messages", body)
    },

    "send_embed": fn(emb) {
      let body = { "embeds": [emb] }
      return _discord_post(token, "/channels/" + raw["id"] + "/messages", body)
    },

    "archive": fn() {
      let body = { "archived": true }
      return _discord_patch(token, "/channels/" + raw["id"], body)
    },

    "unarchive": fn() {
      let body = { "archived": false }
      return _discord_patch(token, "/channels/" + raw["id"], body)
    },

    "set_name": fn(name) {
      let body = { "name": name }
      return _discord_patch(token, "/channels/" + raw["id"], body)
    },

    "get_members": fn() {
      return _discord_get(token, "/channels/" + raw["id"] + "/thread-members")
    },

    "add_member": fn(user_id) {
      return _discord_put(token, "/channels/" + raw["id"] + "/thread-members/" + user_id, {})
    },

    "remove_member": fn(user_id) {
      return _discord_delete(token, "/channels/" + raw["id"] + "/thread-members/" + user_id)
    },

    "delete": fn() {
      return _discord_delete(token, "/channels/" + raw["id"])
    }
  }
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

    "reply_embed": fn(emb) {
      let body = { "embeds": [emb] }
      return _discord_post(token, "/channels/" + raw["channel_id"] + "/messages", body)
    },

    "edit": fn(new_content) {
      let body = { "content": new_content }
      return _discord_patch(token, "/channels/" + raw["channel_id"] + "/messages/" + raw["id"], body)
    },

    "crosspost": fn() {
      return _discord_post(token, "/channels/" + raw["channel_id"] + "/messages/" + raw["id"] + "/crosspost", {})
    },

    # NEW 1.2: create a thread from this message
    "create_thread": fn(name, auto_archive_duration) {
      if auto_archive_duration == nil { auto_archive_duration = 1440 }
      let body = {
        "name": name,
        "auto_archive_duration": auto_archive_duration
      }
      let res = _discord_post(token, "/channels/" + raw["channel_id"] + "/messages/" + raw["id"] + "/threads", body)
      if res == nil { return nil }
      return make_thread(token, res)
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

    "send_embed": fn(emb) {
      let body = { "embeds": [emb] }
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
    },

    # NEW 1.2
    "get_threads": fn() {
      let res = _discord_get(token, "/channels/" + raw["id"] + "/threads/active")
      if res == nil { return [] }
      let threads = res["threads"]
      if threads == nil { return [] }
      return threads.map({ |t| make_thread(token, t) })
    },

    "create_thread": fn(name, thread_type, auto_archive_duration) {
      # thread_type: 11 = public, 12 = private
      if thread_type == nil { thread_type = 11 }
      if auto_archive_duration == nil { auto_archive_duration = 1440 }
      let body = {
        "name": name,
        "type": thread_type,
        "auto_archive_duration": auto_archive_duration
      }
      let res = _discord_post(token, "/channels/" + raw["id"] + "/threads", body)
      if res == nil { return nil }
      return make_thread(token, res)
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
    },

    # NEW 1.2
    "get_active_threads": fn() {
      let res = _discord_get(token, "/guilds/" + raw["id"] + "/threads/active")
      if res == nil { return [] }
      let threads = res["threads"]
      if threads == nil { return [] }
      return threads.map({ |t| make_thread(token, t) })
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

    # NEW 1.2: hyperlink the embed title
    "set_url": fn(url) {
      e["url"] = url
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

# ─── Slash command helpers ────────────────────────────────────────────────────

fn slash_command_payload(content, ephemeral) {
  let flags = 0
  if ephemeral == true { flags = 64 }
  return {
    "type": 4,
    "data": {
      "content": content,
      "flags": flags
    }
  }
}

fn slash_command_deferred_payload() {
  return { "type": 5, "data": { "flags": 0 } }
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
      if handler == nil { return false }

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

# ─── Client ───────────────────────────────────────────────────────────────────

fn discord_client(token) {
  let _events = make_event_emitter()
  let _token = token
  let _prefix = "!"
  let _router = nil
  let _running = false
  let _app_id = nil

  let client = {
    "token": token,

    "set_app_id": fn(id) { _app_id = id },

    "on": fn(event, handler) {
      _events.emit("register", { "event": event, "handler": handler })
      _events.on(event, handler)
    },

    "on_message":        fn(handler) { _events.on("message", handler) },
    "on_ready":          fn(handler) { _events.on("ready", handler) },
    "on_error":          fn(handler) { _events.on("error", handler) },
    "on_typing":         fn(handler) { _events.on("typing", handler) },
    "on_member_update":  fn(handler) { _events.on("member_update", handler) },
    "on_presence_update":fn(handler) { _events.on("presence_update", handler) },

    # NEW 1.2
    "on_thread_create":  fn(handler) { _events.on("thread_create", handler) },
    "on_thread_update":  fn(handler) { _events.on("thread_update", handler) },
    "on_thread_delete":  fn(handler) { _events.on("thread_delete", handler) },

    "use_commands": fn(prefix) {
      if prefix == nil { prefix = "!" }
      _prefix = prefix
      _router = make_command_router(prefix)
      _events.on("message", { |msg| _router.handle(msg) })
      return _router
    },

    "get_channel":   fn(id) {
      let res = _discord_get(_token, "/channels/" + id)
      if res == nil { return nil }
      return make_channel(_token, res)
    },

    "get_guild":     fn(id) {
      let res = _discord_get(_token, "/guilds/" + id)
      if res == nil { return nil }
      return make_guild(_token, res)
    },

    "get_user":      fn(id)    { return _discord_get(_token, "/users/" + id) },
    "get_me":        fn()      { return _discord_get(_token, "/users/@me") },

    "send_message":  fn(channel_id, content) {
      let body = { "content": content }
      return _discord_post(_token, "/channels/" + channel_id + "/messages", body)
    },

    "send_embed":    fn(channel_id, emb) {
      let body = { "embeds": [emb] }
      return _discord_post(_token, "/channels/" + channel_id + "/messages", body)
    },

    "set_status": fn(status, activity_type, activity_name) {
      if activity_type == nil { activity_type = 0 }
      let body = {
        "op": 3,
        "d": {
          "since": nil,
          "activities": [{ "name": activity_name, "type": activity_type }],
          "status": status,
          "afk": false
        }
      }
      return GATEWAY.send_payload(_token, body)
    },

    "defer_interaction": fn(interaction_id, interaction_token) {
      let path = "/interactions/" + interaction_id + "/" + interaction_token + "/callback"
      return _discord_post(_token, path, slash_command_deferred_payload())
    },

    "respond_interaction": fn(interaction_id, interaction_token, content, ephemeral) {
      let path = "/interactions/" + interaction_id + "/" + interaction_token + "/callback"
      return _discord_post(_token, path, slash_command_payload(content, ephemeral))
    },

    "follow_up_interaction": fn(application_id, interaction_token, content) {
      let body = { "content": content }
      return _discord_post(_token, "/webhooks/" + application_id + "/" + interaction_token, body)
    },

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

      GATEWAY.connect(_token, { |event_name, raw_data|
        if event_name == "MESSAGE_CREATE" {
          let msg = make_message(_token, raw_data)
          if !msg.is_bot() { _events.emit("message", msg) }
        } else { if event_name == "GUILD_CREATE" {
          _events.emit("guild_join", make_guild(_token, raw_data))
        } else { if event_name == "GUILD_DELETE" {
          _events.emit("guild_leave", raw_data)
        } else { if event_name == "GUILD_MEMBER_ADD" {
          _events.emit("member_join", raw_data)
        } else { if event_name == "GUILD_MEMBER_REMOVE" {
          _events.emit("member_leave", raw_data)
        } else { if event_name == "GUILD_MEMBER_UPDATE" {
          _events.emit("member_update", raw_data)
        } else { if event_name == "MESSAGE_REACTION_ADD" {
          _events.emit("reaction_add", raw_data)
        } else { if event_name == "MESSAGE_REACTION_REMOVE" {
          _events.emit("reaction_remove", raw_data)
        } else { if event_name == "TYPING_START" {
          _events.emit("typing", raw_data)
        } else { if event_name == "PRESENCE_UPDATE" {
          _events.emit("presence_update", raw_data)
        } else { if event_name == "THREAD_CREATE" {
          _events.emit("thread_create", make_thread(_token, raw_data))
        } else { if event_name == "THREAD_UPDATE" {
          _events.emit("thread_update", make_thread(_token, raw_data))
        } else { if event_name == "THREAD_DELETE" {
          _events.emit("thread_delete", raw_data)
        } else {
          _events.emit("raw", { "type": event_name, "data": raw_data })
        } } } } } } } } } } } } }
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

fn discord_mention(user_id)         { return "<@" + user_id + ">" }
fn discord_channel_mention(ch_id)   { return "<#" + ch_id + ">" }
fn discord_role_mention(role_id)    { return "<@&" + role_id + ">" }
fn discord_bold(text)               { return "**" + text + "**" }
fn discord_italic(text)             { return "*" + text + "*" }
fn discord_code(text)               { return "`" + text + "`" }
fn discord_spoiler(text)            { return "||" + text + "||" }
fn discord_strikethrough(text)      { return "~~" + text + "~~" }
fn discord_underline(text)          { return "__" + text + "__" }

fn discord_code_block(lang, text) {
  if lang == nil { lang = "" }
  return "```" + lang + "\n" + text + "\n```"
}

fn discord_timestamp(unix_seconds, style) {
  if style == nil { style = "R" }
  return "<t:" + str(unix_seconds) + ":" + style + ">"
}

# NEW 1.2: markdown heading helpers
fn discord_header(text)    { return "# " + text }
fn discord_subheader(text) { return "## " + text }
fn discord_h3(text)        { return "### " + text }

fn discord_list(items) {
  let out = ""
  items.each({ |item| out = out + "- " + item + "\n" })
  return out
}
