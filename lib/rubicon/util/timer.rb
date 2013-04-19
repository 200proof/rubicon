module Rubicon::Util
    # A simple thread-based one-shot/periodic timer.
    class Timer
        attr_accessor :timeout

        def initialize(timeout, one_shot=false, &block)
            raise "timeout must be Float/Integer!" unless timeout.is_a?(Integer) || timeout.is_a?(Float)
            @timeout = timeout
            @block = block
            @running = false
            @shutting_down = false
        end

        def running?
            @running
        end

        # Restarts this timer, first waiting up to `timeout` then killing the thread and spawning a new one.
        # 
        def restart(timeout=nil)
            stop(timeout)
            start!
        end

        # Restarts this timer in a very violent fashion (basically calling stop! and start!)
        def restart!
            stop!
            start!
        end

        # Waits for the worker thread to join before stopping the timer, giving the worker thread timeout seconds 
        # to get its business in order. By default timeout is the thread's timeout plus one second.
        def stop(timeout=nil)
            timeout ||= @timeout +1
            @shutting_down = true
            @thread.join timeout
            @running = false
        end

        # Stops this timer right away, killing the worker thread.
        def stop!
            @thread.kill if @running
            @running = false
        end

        # Spawns a new worker thread
        def start!
            raise "This timer cannot be started as it is already running!" if @running
            @running = true
            @shutting_down = false
            @thread  = Thread.new do
                begin
                    if @one_shot
                        sleep @timeout
                        @block.call
                    else
                        loop do
                            break if @shutting_down
                            sleep @timeout
                            @block.call
                        end
                    end
                rescue

                end
            end
        end
    end
end