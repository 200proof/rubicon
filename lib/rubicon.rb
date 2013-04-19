require "eventmachine"
require "logger"

require "thread/channel"
require "thread/promise"
require "thread/pool"

require "sinatra"
require "thin"

# pretty colors
if RbConfig::CONFIG["host_os"] =~ /mswin|mingw|cygwin/
    require "win32console"
end

require "rubicon/version"

require "rubicon/util/config"
require "rubicon/util/logger"
require "rubicon/util/permissions"
require "rubicon/util/timer"
require "rubicon/application"

# Call this to load anything else that depends on the configuration
# This includes anything that uses a logger.
module Rubicon
    def self.bootstrap!        
        require "rubicon/plugin/plugin_manager"
        require "rubicon/plugin/plugin"

        require "rubicon/frostbite/rcon_packet"
        require "rubicon/frostbite/rcon_client"

        require "rubicon/frostbite/bf3/server.rb"
        require "rubicon/frostbite/bf3/player.rb"
        require "rubicon/frostbite/bf3/team.rb"
        require "rubicon/frostbite/bf3/squad.rb"
        require "rubicon/frostbite/bf3/weapon.rb"
        require "rubicon/frostbite/bf3/maps_and_game_modes.rb"

        require "rubicon/web_ui/thin_logging_patch"
        require "rubicon/web_ui/web_ui"
    end
end