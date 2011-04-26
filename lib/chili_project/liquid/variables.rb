module ChiliProject
  module Liquid
    module Variables
      # Liquid "variables" that are used for backwards compatability with macros
      #
      # Variables are used in liquid like {{var}}
      def self.macro_backwards_compatibility
        {
          'hello_world' => ChiliProject::Liquid::Tags::HelloWorld.new('hello_world','{% hello_world %}','').render(nil)
        }
      end

    end
  end
end
