require 'find'
require 'tempfile'

module Loba
  module TaskSupport

    class LinesFromRbFiles
      include Enumerable

      def initialize
        @files = rb_files
      end

      def file_count
        @files.count
      end

      # main enumerable method; merely reads lines, in order,
      # from the set of files
      #
      # block provided should expect three arguments:
      #  line:     the line read from a file in the set of files
      #  linenbr:  the line number within the file of the line read

      #  filename: the relative path of the file the read was read from
      def each(&line_block)
        rb_files.each do |filename|
          File.open(filename).each_with_index do |line, linenbr|
            line_block.call(line, linenbr, filename)
          end
        end
      end

      # alternative :each method that will replace the lines read from
      # files in the set
      #
      # block provided should expect three arguments:
      #  line:     the line read from a file in the set of files
      #  linenbr:  the line number within the file of the line read
      #  filename: the relative path of the file the read was read from
      #
      # the return value of the block provided will be used to replace
      # the line into the file.  If to be unchanged by the block,
      # the block should return the original line (that is, the
      # argument received by `line`)
      def amend_each(&line_block)
        rb_files.each do |filename|
          amend_file(filename, &line_block)
        end
      end

    private
      def rb_files
        Find.find('.').select{|e| File.extname(e) == '.rb' }
      end

      def amend_file(filename, &line_block)
        if RUBY_PLATFORM =~ /mswin|mingw|windows/
          raise NotImplementedError.new 'Windows-based platforms are not yet supported'
        end

        tempdir = File.dirname(filename)
        tempprefix = File.basename(filename)
        tempprefix.prepend('.')
        tempfile = begin
                    Tempfile.new(tempprefix, tempdir)
                   rescue
                    Tempfile.new(tempprefix)
                   end

        File.open(filename).each_with_index do |line, linenbr|
          tempfile.puts line_block.call(line, linenbr, filename)
        end

        tempfile.fdatasync
        tempfile.close

        stat = File.stat(filename)
        FileUtils.chown stat.uid, stat.gid, tempfile.path
        FileUtils.chmod stat.mode, tempfile.path
        FileUtils.mv tempfile.path, filename
      end
    end

  end
end
