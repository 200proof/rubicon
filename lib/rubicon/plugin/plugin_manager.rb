module Rubicon
    class PluginManager
        @@loaded_plugins = {}
        @@logger = Rubicon.logger("PluginManager")
        def self.loaded_plugins
            @@loaded_plugins
        end

        # Loads plugins from the directory specified in the config, rejecting any that
        # misbehave by overriding methods they shouldn't.
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

            non_overridable_methods = [:initialize, :current_args=, :server, :logger]
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

        # Creates a new PluginManager tied to a specific
        # server instance
        def initialize(server)
            @active_plugins = {}

            # plugin.name => message channel (for shutdown)
            @plugin_message_channels = {}

            # plugin.name => worker thread
            @plugin_worker_threads = {}

            # eventName => array of message channels
            # of plugins that listen to the event
            @event_message_channels = {}
            @event_message_channels.default_proc = proc do |hash, key|
                hash[key] = []
            end

            # commandName => array of message channels
            # of plugins that listen to the command
            @command_message_channels = {}
            @command_message_channels.default_proc = proc do |hash, key|
                hash[key] = []
            end

            @@loaded_plugins.each do |name, klass|
                plugin = klass.new(server)
                @active_plugins[klass.name] = plugin
                enable_plugin(klass.name)
            end
        end

        # Dispatches an event to any plugins that listen to it.
        def dispatch_event(event_name, args)
            @event_message_channels[event_name].each do |message_channel|
                message_channel.send [:event, event_name, args]
            end
        end

        # Dispatches a command to any plugins that listen to it.
        def dispatch_command(command_name, args)
            @command_message_channels[command_name].each do |message_channel|
                message_channel.send [:command, command_name, args]
            end
        end

        # Enables a plugin, registering all of its listener
        # and calls its `enabled` initializer
        def enable_plugin(plugin_name)
            if @plugin_message_channels[plugin_name]; server.logger.warn("#{plugin_name} is already enabled!"); return; end
            unless @active_plugins[plugin_name]; server.logger.error("#{plugin_name} is not a loaded plugin!"); return; end

            channel = @plugin_message_channels[plugin_name] = Thread::Channel.new
            plugin  = @active_plugins[plugin_name]

            # Enabled callback
            plugin.enabled

            plugin.class.event_handlers.each_key do |event_name|
                @event_message_channels[event_name] << channel
            end

            plugin.class.command_handlers.each_key do |command_name|
                @command_message_channels[command_name] << channel
            end

            @plugin_worker_threads[plugin_name] = Thread.new do
                while message = channel.receive
                    break if message == :stop

                    begin
                        type, *params = message

                        if type == :command
                            command_name = plugin.class.command_handlers[params.shift]
                            plugin.current_args = params.shift
                            plugin.send command_name
                        elsif type == :event
                            event_name = plugin.class.event_handlers[params.shift]
                            plugin.current_args = params.shift
                            plugin.send event_name
                        else
                            @logger.error { "#{type} is not a valid plugin message!" }
                        end
                    rescue Exception => e
                        @@logger.error "Exception in plugin: #{e.message} (#{e.class})"
                        @@logger.error (e.backtrace || [])[0..10].join("\n")
                    end
                end
            end
        end

        # Disables a plugin, removing any active listeners
        # and calling it to clean itself up.
        def disable_plugin(plugin_name)
            plugin  = @active_plugins[plugin_name]
            channel = @plugin_message_channels[plugin_name]

            plugin.class.event_handlers.each_key do |event_name|
                @event_message_channels[event_name].delete channel
            end

            plugin.class.command_handlers.each_key do |command_name|
                @command_message_channels[command_name].delete channel
            end

            @plugin_message_channels[plugin_name].send :stop

            # disable the plugin
            plugin.disabled
        end
    end
end