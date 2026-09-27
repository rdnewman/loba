# Fails if a public object has no written YARD docs, or if a rubocop
# directive has leaked into a docstring.
require "yard"

YARD::Registry.clear
YARD.parse(Dir["lib/**/*.rb"])

objects = YARD::Registry.all.select { |object| object.visibility == :public }
undocumented = objects.select { |object| object.docstring.blank? && object.tags.empty? }
leaked = YARD::Registry.all.select { |object| object.docstring.include?("rubocop") }

undocumented.each { |object| puts "undocumented: #{object.path}" }
leaked.each { |object| puts "rubocop directive in docstring: #{object.path}" }
exit(undocumented.empty? && leaked.empty? ? 0 : 1)
