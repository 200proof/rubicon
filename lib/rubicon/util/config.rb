module Rubicon::Util
    # Provides a layer of abstraction over the root nodes in a YAML
    # file used to store configuration information. This allows
    # plugins and other components of Rubicon to commit their 
    # configuration to disk without writing any information
    # that other plugins may not potentially want saved.
    class ConfigManager
        def initialize(filename)
            @filename = filename

            @wrappers = {}
            @config = YAML::load_file(filename) rescue {}

            @config.each do |k, v|
                @wrappers[k] = ConfigWrapper.new(self, k, v)
            end
        end

        def [](key)
            @wrappers[key] ||= ConfigWrapper.new(self, key, @config[k])
        end

        def []=(key, value)
            @wrappers[key] = (value.is_a?(ConfigWrapper) ? value : ConfigWrapper.new(self, key, value))
        end

        def commit(key, value)
            @config[key] = value
        end

        def save!
            f = File.open(filename, "w+") { YAML::dump(@config, f) }
        rescue
            puts "Error saving config #{e.message} (#{e.class})"
            puts (e.backtrace || [])[0..10].join("\n")
        end
    end

    # Wraps a root node. Used by ConfigManager.
    class ConfigWrapper
        def initialize(manager, key, value)
            @manager = manager
            @key = key
            @value = value
        end

        def save!
            @manager.commit(@key, @value)
            @manager.save!
        end

        def inspect
            @value.inspect
        end

        def to_s
            @value.to_s
        end

        def method_missing(*args, &block)
            @value.send(*args, &block)
        end
    end
end
