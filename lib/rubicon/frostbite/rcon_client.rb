module Rubicon::Frostbite
    class RconClient < EventMachine::Connection
        def self.game_handlers
            @@game_handlers ||= {}
        end

        attr_accessor :message_channel

        def initialize(password)
            super

            Rubicon.connected

            @logger = Rubicon.logger("RconClient")

            @password = password
            @active_promises = {}
            @buffer = []
            @last_sent_sequence = 0
            @message_channel = Thread::Channel.new
        end

        def connection_completed
            @handler_thread = Thread.new do
                begin
                    response = send_request("version")
                    if (response.read_word != "OK")
                        @logger.fatal("Server appears to be abnormal. Disconnectiong")
                        close_connection
                    end

                    server_game = response.read_word
                    if(@@game_handlers[server_game])
                        @game_handler = @@game_handlers[server_game].new(self, @password)
                        @game_handler.connected
                        @game_handler.start_event_pump
                    else
                        @logger.fatal("No game handler for \"#{server_game}\"! Shutting down.")
                        close_connection
                    end
                rescue Exception => e
                    Rubicon.logger("HandlerThread").error "Exception during event: #{e.message} (#{e.class})"
                    Rubicon.logger("HandlerThread").error (e.backtrace || [])[0..10].join("\n")
                end
            end
        end

        def unbind
            if @handler_thread
                @handler_thread.join
            else
                # If this gets called before a handler thread is created, it
                # means that EventMachine failed to connect.
                @logger.fatal { "Failed to connect! Make sure you entered the correct IP address and port in the config!" }
            end

            Rubicon.disconnected
            @logger.debug { "Connection unbound" }
        end

        def receive_data(data)
            @buffer += data.bytes.to_a

            parse_packets
        end

        # Used to send a command the server.
        # This should be used when a reply from the server is irrelevant to
        # the continuation of the flow of execution 
        def send_command(*words)
            _, packet = build_packet(words)
            dispatch_packet(packet)
        end

        # Used to send a request to the server, whose reply is required
        # to continue the flow of execution
        def send_request(*words)
            sequence, packet = build_packet(words)

            ret_promise = promise
            @active_promises[sequence] = ret_promise
            dispatch_packet(packet)

            ~ret_promise
        end

    private
        def build_packet(words)
            @last_sent_sequence += 1
            [@last_sent_sequence, RconPacket.new(@last_sent_sequence, :client, :request, *words)]
        end

        def dispatch_packet(packet)
            @logger.debug { "<-SEND-  #{packet.inspect}" }
            send_data packet.encode
        end

        def awaiting_response?
            @requests_sent != @responses_received
        end

        def parse_packets
            loop do
                # no point trying to read if we can't even extract a header
                break if @buffer.length < RconPacket::PACKET_HEADER_SIZE
                buffer_idx = 0

                # 4th byte contains the origin flag and request/response flag
                # reset it directly in the buffer so we can splat out the actual sequence number later
                origin = ((@buffer[3] & (1 << 7)) == 0) ? :client : :server
                type = ((@buffer[3] & (1 << 6)) == 0) ? :request : :response

                # clear origin and isResponse bits
                @buffer[3] &= 0b00111111

                # get all the header info in one fell splat
                # (packing 12 unsigned char8s into 3 unsigned little-endian int32s)
                sequence, total_size, word_count = @buffer[0, 12].pack('C'*12).unpack('V'*3)

                buffer_idx += 12

                # no point reading on if we cant finish the packet
                break if @buffer.length < total_size

                words = []

                word_count.times do
                    word_length = @buffer[buffer_idx, 4].pack('C'*4).unpack('V').first
                    word = @buffer[buffer_idx+4, word_length].pack('c'*word_length)

                    # adding 5 because 4 bytes for the word length and 1 byte for trailing NULL char
                    buffer_idx += (word_length + 5)

                    words << word
                end

                received_packet = RconPacket.new(sequence, origin, type, *words)

                @logger.debug { " -RECV-> #{received_packet.inspect}" }

                # All requests need to be acknowledged with a response
                dispatch_packet RconPacket.new(sequence, origin, :response, "OK") if type == :request

                if (@active_promises[sequence])
                    @active_promises[sequence] << received_packet
                end

                if (type == :request) && (origin == :server)
                    @message_channel.send received_packet
                end

                # pop the total bytes read out of the buffer
                @buffer.shift total_size
            end
        end
    end
end