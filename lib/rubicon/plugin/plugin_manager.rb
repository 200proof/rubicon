module Rubicon
    class PluginManager
        @@loaded_plugins = {}
        @@logger = Rubicon.logger("PluginManager")
        def self.loaded_plugins
            @@loaded_plugins
        end

        def self.load_plugins(plugins_directory)
            Dir.glob(File.expand_path(plugins_directory + "/*/*.rb", Dir.getwd)) do |f|
                begin
                    require f 
                rescue SyntaxError => error
                    @@logger.error { "Syntax error in plugin #{f}" }
                    @@logger.error { "#{error.message}" }
                    @@logger.error (error.backtrace || [])[0..10].join("\n")
                end
            end

            non_overridable_methods = [:initialize, :current_args=, :mutex]
            @@loaded_plugins.each do |name, klass|
                rejected = false

                non_overridable_methods.each do |method_name|
                    if (klass.instance_method(method_name).owner != Rubicon::Plugin)
                        @@logger.warn { "Misbehaving plugin #{klass.name} unloaded! It should not override #{method_name}!" }
                        rejected = true
                        break
                    end
                end

                @@loaded_plugins.delete(name) if rejected
            end
        end

        def initialize(server)
            @active_plugins = {}
            @enabled_plugins = {}
            @worker_poll = Thread::Pool.new(5)

            @@loaded_plugins.each do |name, klass|
                plugin = klass.new(server)
                @active_plugins[klass.name] = plugin
                enable_plugin(name)
            end
        end

        # Dispatches an event to any plugins that listen to it.
        def dispatch_event(event_name, args)
            @enabled_plugins.values.each do |plugin_instance|
                if(event_handler_name = plugin_instance.class.event_handlers[event_name])
                    plugin_instance.current_args = args
                    plugin_instance.send event_handler_name
                end
            end
        rescue Exception => e
            @@logger.error "Exception in plugin: #{e.message} (#{e.class})"
            @@logger.error (e.backtrace || [])[0..10].join("\n")
        end

        # Dispatches a command to any plugins that listen to it.
        def dispatch_command(command_name, args)
            @enabled_plugins.values.each do |plugin_instance|
                if(command_handler_name = plugin_instance.class.command_handlers[command_name.to_sym])
                    plugin_instance.current_args = args
                    plugin_instance.send command_handler_name
                end
            end
        rescue Exception => e
            @@logger.error "Exception in plugin: #{e.message} (#{e.class})"
            @@logger.error (e.backtrace || [])[0..10].join("\n")
        end

        def enable_plugin(plugin_name)
            if @enabled_plugins[plugin_name]; server.logger.warn("#{plugin_name} is already enabled!"); return; end
            plugin = @active_plugins[plugin_name]
            plugin.enabled

            @enabled_plugins[plugin_name] = plugin
        end

        def disable_plugin(plugin_name)
            if (plugin_instance = @enabled_plugins[plugin_name])
                plugin_instance.disable
                @enabled_plugins.delete plugin_name
            else
                server.logger.warn("#{plugin_name} is not active!")
            end
        end
    end
end