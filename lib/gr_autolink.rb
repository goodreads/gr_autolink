module GrAutolink
  VERSION = '1.0.8'

  class Railtie < ::Rails::Railtie
    initializer 'gr_autolink' do |app|
      ActiveSupport.on_load(:action_view) do
        require 'gr_autolink/helpers'
      end
    end
  end
end
