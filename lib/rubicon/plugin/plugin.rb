module Rubicon
    class Plugin
        @@event_method_names = {}
        @@command_method_names = {}
        def self.inherited(base)
            PluginManager.loaded_plugins[base.name] = base
            Rubicon.logger("Plugin").debug { "Loaded plugin #{base.name} "}
        end

        def self.event_method_name(event_name)
            @@event_method_names[event_name] ||= "event_#{event_name}".downcase.gsub(/\./, "_").to_sym
        end

        def self.command_method_name(command_name)
            @@command_method_names[command_name] ||= "command_#{command_name}".downcase.gsub(/\./, "_").to_sym
        end

        def self.event_handlers
            @@event_method_names
        end

        def self.command_handlers
            @@command_method_names
        end

        # Provides a DSL for responding to server events such as players joining, chat messages
        # kills, round start/end, etc.
        #
        # Arguments which are expected to be passed to the event are not passed into
        # the block, but rather can be accessed directly by their names. The relevant
        # arguments for events are defined in the documentation.
        # An example usage follows:
        #
        # event "player.onKill" do
        #     if weapon == :knife
        #       server.say "#{killer.name} just knifed #{victim.name}!"
        #       server.say "And it landed right in the face!" if headshot?
        #     end
        # end
        #
        # NOTE: Any chat messages which are interpreted as commands as defined by
        # the server configuration will NOT be sent, and you should use the `command`
        # directive to handle those.
        def self.event(event, &block)
            @events_registered ||= []
            @events_registered << event

            define_method event_method_name(event), block
        end

        # Provides a DSL for responding to commands entered into the console
        # or via the text chat.
        #
        # Like with `event`, arguments are not passed to the block.
        # The relevant arguments are `player` and `args.
        #
        # `player` is the player who issued the command, and if checking for permissions,
        # the console is represented as a special player with all permissions.
        #
        # `args` is an array of arguments seprated by space.
        def self.command(command, &block)
            @commands_registered ||= []
            @commands_registered << command

            define_method command_method_name(command), block
        end

        # Provides a DSL for initializing your plugin.
        #
        # This should be used instead of `initialize` as is common
        # for Ruby classes. A plugin will not be loaded if it has
        # its constructor defined via `initialize`.
        #
        # Calling this argument is optional
        def self.enabled(&block)
            unless block
                raise "`enabled` called without a block!"
            end

            define_method :enabled, block
        end

        # Stub method for the enabled directive.
        def enabled
        end

        # Provides a DSL for destroying your plugin.
        #
        # This is called when the plugin is shutdown either by
        # the server or by the user. You should free any resources
        # here.
        def self.disabled(&block)
            unless block
                raise "`disabled` called without a block!"
            end

            define_method :disabled, block
        end

        # Stub method for the disabled directive.
        def disabled
        end

        # Lets the DSL access the server which this plugin is running on
        # as well as the logger instance for this plugin
        # Plugin#logger should not be overridden, and any plugin that violates this
        # will not be loaded.
        attr_reader :server, :logger

        # To prevent potentially silly things from happening, please do
        # not implement a constructor using `initialize`. The plugin
        # manager will refuse to load any plugin that violates this.
        #
        # Instead use the `enabled`, and `disabled` directives
        # to manage your plugin's lifecycle.
        def initialize(server)
            @server = server
            @logger = server.logger(self.class.name)
            logger.info { "Initialized #{self.class.name}" }
        end

        # To make the DSL more elegant, the event and command blocks do not take arguments.
        # Instead, since each plugin's processing is single-threaded, they are drawn from 
        # a hash whose value is set by the plugin manager. Any parameters which are not
        # expected to be passed to the event or command will return nil.
        def method_missing(method_name, *args, &block)
            @current_args[method_name]
        end

        # This allows the plugin manager to set any accessible parameters just prior to calling
        # a plugin's command/event handler. Do not attempt to override this method, as the 
        # plugin manager will refuse to load your plugin.
        def current_args=(args)
            @current_args = args
        end
    end
end