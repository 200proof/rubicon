module Rubicon
    class PluginManager
        @@plugins = []
        def self.plugins
            @@plugins
        end

        def initialize(plugins_directory)
            Dir.glob(plugins_directory + "/*/*.rb") { |f| require f }
        end
    end
end