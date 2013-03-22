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

            if (type == :response)
                @response = words[0]
            end
        end

        # Whether or not this the original request that resulted in this packet
        # originated on the server
        def from_server?
            @origin == :server
        end

        # Whether or not this the original request that resulted in this packet
        # originated on the client
        def from_client?
            @origin == :client
        end

        # Whether or not this packet is a request
        def request?
            @type == :request
        end

        # Whether or not this packet is a response
        def response?
            @type == :response
        end

        # If this packet is a response, return the response
        # status, otherwise nil
        def response
            @response
        end

        # Reads the next word in this packet
        # NOTE: this modifies the packet
        def read_word
            @words.shift
        end

        # Reads a player info block
        # NOTE: this modifies the packet
        def read_player_info_block
            keys, ret = [], []

            key_count = read_word.to_i
            key_count.times { keys << read_word}

            value_count = read_word.to_i

            value_count.times do
                current_player = {}
                key_count.times do |idx|
                    current_player[keys[idx]] = read_word
                end

                ret << current_player
            end

            ret
        end

        # Reads a "Team Scores" block
        # NOTE: this modifies the packet
        # Returns [[team scores], target]
        def read_team_scores
            ret = []
            num_entries = read_word.to_i
            num_entries.times do
                ret << read_word.to_i
            end
            [ret, read_word.to_i]
        end

        # Reads a boolean value
        # NOTE: this modifies the packet
        def read_bool
            read_word == "true"
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
