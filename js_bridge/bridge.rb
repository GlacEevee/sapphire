# js_bridge/bridge.rb — Ruby side of the Sapphire JS bridge
# Spawns a Node.js process and communicates over stdin/stdout JSON

require 'json'
require 'open3'

module Sapphire
  module JSBridge
    class NotAvailableError < StandardError; end

    @process  = nil
    @stdin    = nil
    @stdout   = nil
    @available = nil

    def self.available?
      return @available unless @available.nil?
      @available = system("which node > /dev/null 2>&1") ||
                   system("where node > nul 2>&1")
    end

    def self.ensure_started!
      raise NotAvailableError, node_missing_message unless available?
      return if @process && @process.alive? rescue nil

      runtime = File.join(File.dirname(__FILE__), 'runtime.js')
      unless File.exist?(runtime)
        raise NotAvailableError, "JS bridge runtime not found: #{runtime}"
      end

      @stdin, @stdout, @stderr, @process = Open3.popen3("node #{runtime.shellescape}")
    end

    def self.call(package, fn, args = [])
      ensure_started!
      payload = JSON.generate({ package: package, fn: fn, args: args })
      @stdin.puts(payload)
      @stdin.flush
      response = @stdout.gets
      result   = JSON.parse(response.to_s.strip)
      raise result['error'] if result['error']
      result['result']
    rescue NotAvailableError => e
      puts e.message
      nil
    rescue => e
      puts "[JS Bridge] Error: #{e.message}"
      nil
    end

    def self.node_missing_message
      <<~MSG
        [Sapphire] This package requires Node.js, which is not installed.
        Node.js is optional for most Sapphire features, but needed for:
          web, ui, canvas

        Install Node.js:
          Linux/Pi:  sudo apt-get install nodejs npm
          macOS:     brew install node
          Windows:   https://nodejs.org

        Everything else in Sapphire works without Node.js.
      MSG
    end

    def self.stop
      @stdin&.close rescue nil
      @stdout&.close rescue nil
      @process&.kill rescue nil
      @process  = nil
      @stdin    = nil
      @stdout   = nil
    end
  end
end
