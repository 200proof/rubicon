module Rubicon
    class PluginManager
        @@loaded_plugins = []
        @@logger = Rubicon.logger("PluginManager")
        def self.loaded_plugins
            @@loaded_plugins
        end

        def self.load_plugins(plugins_directory)
            Dir.glob(File.expand_path(plugins_directory + "/*/*.rb", Dir.getwd)) { |f| require f }

            @@loaded_plugins.each_with_index do |klass, idx|
                if (klass.instance_method(:initialize).owner != Rubicon::Plugin)
                    @@logger.warn { "Misbehaving plugin #{klass.name} unloaded!" }
                    @@loaded_plugins.delete_at idx
                end
            end
        end

        def initialize(server)
            @active_plugins = {}

            @@loaded_plugins.each do |klass|
                plugin = klass.new(server)
                plugin.enabled

                @active_plugins[klass.name] = plugin
            end
        end

        def dispatch_event(event_name, args)
            @active_plugins.values.each do |plugin_instance|
                event_handler_name = plugin_instance.class.event_handlers[event_name]
                if(event_handler_name)
                    plugin_instance.current_args = args
                    plugin_instance.send event_handler_name
                end
            end
        rescue Exception => e
            @@logger.error "Exception in plugin: #{e.message} (#{e.class})"
            @@logger.error (e.backtrace || [])[0..10].join("\n")
        end

        def dispatch_command(command_name, args)
            @active_plugins.values.each do |plugin_instance|
                command_handler_name = plugin_instance.class.command_handlers[command_name.to_sym]
                if(command_handler_name)
                    plugin_instance.current_args = args
                    plugin_instance.send command_handler_name
                end
            end
        rescue Exception => e
            @@logger.error "Exception in plugin: #{e.message} (#{e.class})"
            @@logger.error (e.backtrace || [])[0..10].join("\n")
        end

        def enable_plugin(plugin)
            # TODO: enable/disable plugins
        end

        def disable_plugin(plugin)
            # TODO: enable/disable plugins
        end
    end
end