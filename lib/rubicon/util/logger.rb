module Rubicon::Util
    # Creates wrappers around ruby's Logger to automatically place a `progname`
    # in the log message.
    class Logger
        def initialize(log_filename, level)
            @wrappers = {}

            log_file = File.open(log_filename, "a+")
            @logger = ::Logger.new(MethodDelegator.delegate(:write, :close).to(STDOUT, log_file))
            @logger.level = level
            @logger.formatter = proc do |level, datetime, progname, msg|
                progname ||= ""
                "[#{datetime.strftime "%Y-%m-%d %H:%M:%S"}] [#{level.ljust 5}]#{" "+progname.ljust(10)+" " if !progname.empty?} #{msg}\n"
            end
        end

        def with_progname(name)
            @wrappers[name] ||= LoggerWrapper.new(@logger, name)
        end

        def close
            @logger.close
        end
    end

    class LoggerWrapper
        def initialize(logger, progname)
            @logger = logger
            @progname = progname
        end

        log_levels = {
            debug:   ::Logger::DEBUG,
            info:    ::Logger::INFO,
            warn:    ::Logger::WARN,
            error:   ::Logger::ERROR,
            fatal:   ::Logger::FATAL,
            unknown: ::Logger::UNKNOWN
        }
        log_levels.keys.each do |key|
            define_method key do |message=nil, &block|
                @logger.add(log_levels[key], message, @progname, &block)
            end
        end
    end
end