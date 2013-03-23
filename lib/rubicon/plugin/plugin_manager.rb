module Rubicon
    class PluginManager
        @@plugins = []
        def self.plugins
            @@plugins
        end

        def initialize(plugins_directory)
            Dir.glob(File.expand_path(plugins_directory + "/*/*.rb", Dir.getwd)) { |f| require f }
        end
    end
end