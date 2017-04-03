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
end
