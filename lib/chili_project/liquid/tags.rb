module ChiliProject
  module Liquid
    module Tags

      # TODO: migration from macros to Liquid
      
      class HelloWorld < ::Liquid::Tag
        def initialize(tag_name, markup, tokens)
          super
        end
        
        def render(context)
          "Hello world!"
        end
      end

      # TODO: macro_list
      # TODO: child_pages
      # TODO: include

    end
  end
end

Liquid::Template.register_tag('hello_world', ChiliProject::Liquid::Tags::HelloWorld)
