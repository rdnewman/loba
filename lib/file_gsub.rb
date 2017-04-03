require 'line_enumerator'

module Loba
  module TaskSupport

    class << self
      # automated commenting uses the form "#LOBA_COMMENTED " instead of merely "#"
      _comment_string = "#LOBA_COMMENTED"
      TAG = {
        prefix: /(^|(\s)+)/,
        loba: /(Loba(?:\.|::)[_a-zA-Z]\w*)/,   # allows any future Loba method name
        comment: {
          str: _comment_string,
          rxp: Regexp.new(_comment_string),
          begin_block: /^\=begin/,
          end_block: /^\=end/,
        },
      }

      def grep(options = {})
        line_numbers = Hash.new { |h, k| h[k] = [] }

        search_tag = /#{TAG[:prefix]}#{TAG[:loba]}/

        lines = LinesFromRbFiles.new
        lines.each do |line, linenbr, path|
          found = false
          if options[:any]
            found = !!(line =~ search_tag)
          else
            parsed_line = parse_line(line)
            relevant_content = parsed_line.map do |portion|
              portion[:content] if portion[:type] == :unquoted
            end.compact
            relevant_content.each do |portion|
              found ||= !!(portion =~ search_tag)
            end
          end
          line_numbers[path] << linenbr if found
        end

        present_found_results(line_numbers, lines.file_count)
      end

      def comment_all
        line_numbers = Hash.new { |h, k| h[k] = [] }

        search_tag = /#{TAG[:prefix]}#{TAG[:loba]}/

        lines = LinesFromRbFiles.new
        lines.amend_each do |line, linenbr, path|
          parsed_line = parse_line(line)
          parsed_line.each do |portion|
            if portion[:type] == :unquoted
              portion[:content] = portion[:content].gsub(search_tag) do |lexeme|
                line_numbers[path] << linenbr
                "#{TAG[:comment][:str]} #{lexeme}"
              end
            end
          end
          parsed_line.map{|portion| portion[:content]}.join
        end

        present_change_results(line_numbers, lines.file_count)
      end

      def uncomment_all
        line_numbers = Hash.new { |h, k| h[k] = [] }

        search_tag = /#{TAG[:comment][:rxp]}\ \s*#{TAG[:loba]}/
        to_remove = /#{TAG[:comment][:rxp]} /

        lines = LinesFromRbFiles.new
        lines.amend_each do |line, linenbr, path|
          line.gsub(search_tag) do |lexeme|
            line_numbers[path] << linenbr
            lexeme.gsub(to_remove, '')
          end
        end

        present_change_results(line_numbers, lines.file_count)
      end

      def clean
        # remove where Loba commands (leaves line otherwise untouched)
        # TODO: what if user has prefixed Loba command before a non-Loba statement with ";" ?
        line_numbers = Hash.new { |h, k| h[k] = [] }

        search_tag = /#{TAG[:prefix]}(#{TAG[:comment][:rxp]}\ +)?#{TAG[:loba]}.*/

        lines = LinesFromRbFiles.new
        lines.amend_each do |line, linenbr, path|
          parsed_line = parse_line(line)
          parsed_line.each do |portion|
            if portion[:type] == :unquoted
              portion[:content] = portion[:content].gsub(search_tag) do |lexeme|
                line_numbers[path] << linenbr
                ''
              end
            end
          end
          parsed_line.map{|portion| portion[:content]}.join
        end

        present_change_results(line_numbers, lines.file_count)
      end

    private
      def element
        @element ||= {
          line: 0,
          linenumber: 1,
          path: 2
        }
      end

      def parse_line(line, options = {})
        return [{content: line, type: :unquoted}] if line.empty?
        return [{content: line, type: :comment}] if options[:in_comment_block]

        match_on_tail_comment = /(?:[\#].*$)/
        match_on_quoted_text = /\"[^"\\\r\n]*(?:\\?.[^"\\\r\n]*)\"|\'[^'\\\r\n]*(?:\\?.[^'\\\r\n]*)\'/

        # separate any tailing comment (after a '#')
        partitioned_for_comments = line.partition(match_on_tail_comment)
        subject = partitioned_for_comments[0]
        tail = partitioned_for_comments[1] + partitioned_for_comments[2]

        # split up non-comment part into quoted and unquoted text
        parsed = []
        loop do
          parts = subject.partition(match_on_quoted_text)
          parsed << {content: parts[0], type: :unquoted}
          parsed << {content: parts[1], type: :quoted} unless parts[1].empty?
          subject = parts[2]
          break if subject.empty?
        end

        parsed << {content: tail, type: :comment}

        parsed
      end

      def present_found_results(line_numbers, all_file_count)
        present_results(line_numbers, all_file_count, :found)
      end
      def present_change_results(line_numbers, all_file_count)
        present_results(line_numbers, all_file_count, :change)
      end
      def present_results(line_numbers, all_file_count, type = :found)
        detail = "present_#{type.to_s}_detail".to_sym
        summary = "present_#{type.to_s}_summary".to_sym

        line_numbers.keys.each do |path|
          __send__(detail, line_numbers[path], path)
        end
        puts ''
        found_count = line_numbers.reduce(0) { |n, pair| n += pair[1].count }
        __send__(summary, found_count, line_numbers.keys.count, all_file_count)
      end

      def present_found_detail(line_numbers, filename)
        if line_numbers && (line_numbers.count > 0)
          print "#{pluralify(line_numbers.count, 'line')} "
          print "found in #{filename} "
          puts "(@ #{line_numbers.uniq.sort.map{|n| n+1}.join(', ')})"
        end
      end

      def present_found_summary(found_count, found_files_count, total_file_count)
        if found_count && (found_count > 0)
          print "#{pluralify(found_count, 'line')} found in #{pluralify(found_files_count, 'file')}"
        else
          print "No lines found in any files"
        end
        puts " from among #{pluralify(total_file_count, 'file')}."
      end

      def present_change_detail(line_numbers, filename)
        if line_numbers && (line_numbers.count > 0)
          print "#{pluralify(line_numbers.count, 'change')} "
          print "in #{filename} "
          puts "(@ #{line_numbers.uniq.sort.map{|n| n+1}.join(', ')})"
        end
      end

      def present_change_summary(change_count, changed_file_count, total_file_count)
        if change_count && (change_count > 0)
          print "#{pluralify(change_count, 'change')} made in #{pluralify(changed_file_count, 'file')}"
        else
          print "No changes made across"
        end
        puts " from among #{pluralify(total_file_count, 'file')}."
      end

      def pluralify(nbr, singular, plural = nil)
        if nbr == 1
          "1 #{singular}"
        elsif plural
          "#{nbr} #{plural}"
        else
          "#{nbr} #{singular}s"
        end
      end

    end

  end
end
