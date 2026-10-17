module Lba
  module Internal
    class Run
      class WriteFailures
        # The records a sink missed since the last one written there: how many,
        # the range of their seqs, and the first error. Noted on the next record
        # the sink receives, so a reader can tell dropped records from code that
        # never ran.
        class Gap
          # Starts at the first record that couldn't be written.
          #
          # @param error [Exception] why it couldn't be
          # @param seq [Integer, nil] the record's +seq+
          def initialize(error:, seq:)
            @count = 1
            @first_seq = seq
            @last_seq = seq
            @error = "#{error.class}: #{error.message}"
          end

          # Counts a later record that couldn't be written. The first error
          # stands for the gap.
          #
          # @param seq [Integer, nil] the record's +seq+
          # @return [void]
          def add(seq:)
            @count += 1
            @last_seq = seq
          end

          # The record, with this gap noted on it as +:unwritten+.
          #
          # @param fields [Hash] the record
          # @return [Hash] a copy of +fields+ with +:unwritten+ added
          def noted_on(fields)
            # The gap qualifies the record's place in the run, so it goes right
            # after the record's seq and type.
            {
              **fields.slice(:seq, :type),
              unwritten: to_h,
              **fields.except(:seq, :type)
            }
          end

          # @return [Hash{Symbol => Integer, String}]
          #   * +:count+ [Integer] - how many records couldn't be written
          #   * +:first_seq+, +:last_seq+ [Integer] - the +seq+ range they fell in
          #   * +:error+ [String] - the first failure, as +"Class: message"+
          def to_h
            { count:, first_seq:, last_seq:, error: }
          end

          # The gap in a sentence, for a person reading $stderr.
          #
          # @param sink [#inspect] the sink that missed the records
          # @return [String] e.g. +1 record couldn't be written to "a.jsonl"
          #   (first error: Errno::ENOSPC: No space left on device)+
          def summary(sink:)
            "#{records} couldn't be written to #{sink.inspect} (first error: #{error})"
          end

        private

          attr_reader :count, :first_seq, :last_seq, :error

          def records
            if count == 1
              "1 record"
            else
              "#{count} records"
            end
          end
        end
      end
    end
  end
end
