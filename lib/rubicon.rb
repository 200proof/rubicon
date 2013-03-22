require "eventmachine"
require "logger"

require "rubicon/version"

require "rubicon/util/method_delegator"
require "rubicon/util/logger"
require "rubicon/application"

# Call this to load anything else that depends on the configuration
# This includes anything that uses a logger.
module Rubicon
    def self.bootstrap!
        require "rubicon/frostbite/rcon_packet"
        require "rubicon/frostbite/rcon_client"
    end
end