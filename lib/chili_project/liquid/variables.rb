module ChiliProject
  module Liquid
    module Variables
      # Liquid "variables" that are used for backwards compatability with macros
      #
      # Variables are used in liquid like {{var}}
      def self.macro_backwards_compatibility
        {
          'hello_world' => ChiliProject::Liquid::Tags::HelloWorld.new('hello_world','{% hello_world %}','').render(nil),
          'macro_list' => "Use the '{% variable_list %}' tag to see all Liquid variables and '{% tag_list %}' to see all of the Liquid tags.",
          'child_pages' => "Use the '{% child_pages %}' tag",
          'include' => "Use the '%{ include_page %}' tag"
        }
      end

    end
  end
end
