require 'file_gsub'

namespace :loba do
  desc 'recursive search for Loba lines (ignores comments or quoted occurances unless [:any] argument supplied)'
  task :grep, :options do |t, args|
    args.with_defaults(options: nil)

    options = args[:options]
    if options && options.downcase == ':any'
      Loba::TaskSupport.grep({any: true})
    else
      Loba::TaskSupport.grep
    end
  end

  desc '[EXPERIMENTAL] comments out any active Loba lines (recursive file search)'
  task :comment do
    STDOUT.puts 'This task will put "#LOBA_COMMENTED" in front of Loba lines that are not commented out already or that do not appear in quotes.'
    STDOUT.puts 'To do this, this task will modify your source code files!'
    STDOUT.puts 'This feature is currently experimental and it is strongly recommended that you consider committing your code first in case you do not like the changes.'
    STDOUT.print 'Continue? [y/N] '
    answer = STDIN.gets.chomp.strip.downcase
    if answer[0] == 'y'
      Loba::TaskSupport.comment_all
    else
      STDOUT.puts 'Aborted.'
    end
  end

  desc '[EXPERIMENTAL] restores Loba lines commented-out by :comment rake task (recursive file search)'
  task :uncomment do
    STDOUT.puts 'This task will remove "#LOBA_COMMENTED" before Loba lines that do not appear in quotes, thereby making them active again.'
    STDOUT.puts 'To do this, this task will modify your source code files!'
    STDOUT.puts 'This feature is currently experimental and it is strongly recommended that you consider committing your code first in case you do not like the changes.'
    STDOUT.print 'Continue? [y/N] '
    answer = STDIN.gets.chomp.strip.downcase
    if answer[0] == 'y'
      Loba::TaskSupport.uncomment_all
    else
      STDOUT.puts 'Aborted.'
    end
  end

  desc '[EXPERIMENTAL] deletes any active Loba lines (recursive file search)'
  task :clean do
    STDOUT.puts 'This task will delete any Loba lines that are not commented out already and that do not appear in quotes.'
    STDOUT.puts 'To do this, this task will modify your source code files!'
    STDOUT.puts 'This feature is currently experimental and it is strongly recommended that you consider committing your code first in case you do not like the changes.'
    STDOUT.print 'Continue? [y/N] '
    answer = STDIN.gets.chomp.strip.downcase
    if answer[0] == 'y'
      Loba::TaskSupport.clean
    else
      STDOUT.puts 'Aborted.'
    end
  end

end
