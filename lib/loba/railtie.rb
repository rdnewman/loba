module Loba
  class Railtie < Rails::Railtie
    rake_tasks do
      load 'tasks/loba.rake'
    end
  end
end
