module Rubicon::Frostbite
    class RconPacket
        # 4 bytes sequence + origin bit + response bit
        # 4 bytes totalSize
        # 4 bytes numWords
        PACKET_HEADER_SIZE = 12

        attr_reader :sequence, :origin, :type, :words

        def initialize(sequence, origin, type, *words)
            raise "origin must be :server or :client" unless [:server, :client].include? origin
            raise "type must be :request or :response" unless [:request, :response].include? type
            raise "sequence number is too big!" if sequence > 0b00111111_11111111_11111111_11111111

            @sequence   = sequence
            @origin     = origin
            @type       = type
            @words      = words
        end

        def from_server?
            @origin == :server
        end

        def from_client?
            @origin == :client
        end

        def request?
            @type == :request
        end

        def response?
            @type == :response
        end

        # Encodes a packet to be sent to the RCON server
        def encode
            encoded_sequence    = encode_sequence
            encoded_words       = encode_words
            word_count          = @words.length
            
            # 12 bytes for header
            total_size = PACKET_HEADER_SIZE + encoded_words.length

            # DICE's RCON docs say packets cannot be larger than 16384 bytes
            raise "packet is too big!" if total_size > 16384

            ret  = encoded_sequence
            ret += [total_size, word_count].pack('VV')
            ret += encoded_words

            ret
        end

        # super pretty print power!
        def inspect
            "#{@origin} #{@type.to_s.ljust(8, ' ')} ##{@sequence.to_s.rjust(10, "0")} #{words}"
        end

    private
        def encode_sequence
            ret = @sequence

            ret |= (1 << 31) if @origin == :server
            ret |= (1 << 30) if @type == :response

            Array(ret).pack('V')
        end

        def encode_words
            ret = ""

            @words.each do |word|
                ret += Array(word.length).pack('V')
                ret += word
                ret += "\x00"
            end

            ret
        end
    end
end
