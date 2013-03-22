module Rubicon::Frostbite
    class RconClient < EventMachine::Connection
        @@logger = Rubicon.logger("RconClient")

        def initialize(password)
            super

            @buffer = []
            @packet_queue = []
            @password = password
            @requests_sent, @responses_received = 0, 0
        end

        def connection_completed
            send_first_packet RconPacket.new(1, :client, :request, "version")
        end

        def receive_data(data)
            @buffer += data.bytes.to_a

            parse_packets
        end

        def send_packet(packet)
            @packet_queue << packet

            # if there's nothing in the queue, send the packet right away instead 
            # of waiting for a receive which may potentially never actually happen
            send_next_packet unless awaiting_response?
        end

    private
        def send_first_packet(p)
            @@logger.debug { "<-SEND-  #{p.inspect}" }

            @requests_sent += 1 if p.type == :request

            send_data p.encode
        end

        def send_next_packet
            p = @packet_queue.shift

            return if p.nil?

            @requests_sent += 1 if p.type == :request

            @@logger.debug { "<-SEND-  #{p.inspect}" }
            send_data p.encode
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

                @@logger.debug { " -RECV-> #{RconPacket.new(sequence, origin, type, *words).inspect}" }

                @responses_received += 1 if type == :response

                # All requests need to be acknowledged with a response
                send_packet RconPacket.new(sequence, origin, :response, "OK") if type == :request

                # pop the total bytes read out of the buffer
                @buffer.shift total_size

                # send the next packet in queue (this dummy might disconnect if packets are sent out of sequence)
                send_next_packet
            end
        end
    end
end