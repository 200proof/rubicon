module Rubicon
    class Plugin
        def self.logger()
            return Rubicon.logger(self.name)
        end
    end
end