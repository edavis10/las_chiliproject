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

      class VariableList < ::Liquid::Tag
        include ActionView::Helpers::TagHelper

        def initialize(tag_name, markup, tokens)
          super
        end

        def render(context)
          out = ''
          context.environments.first.keys.sort.each do |liquid_variable|
            next if liquid_variable == 'text' # internal variable
            out << content_tag('li', content_tag('code', h(liquid_variable)))
          end if context.environments.present?

          content_tag('p', "Variables:") +
            content_tag('ul', out)
        end
        
      end

      class TagList < ::Liquid::Tag
        include ActionView::Helpers::TagHelper
        
        def render(context)
          content_tag('p', "Tags:") +
          content_tag('ul',
                      ::Liquid::Template.tags.keys.sort.collect {|tag_name|
                        content_tag('li', content_tag('code', h(tag_name)))
                      }.join(''))
        end
      end
      
      # TODO: child_pages
      # TODO: include

    end
  end
end

Liquid::Template.register_tag('hello_world', ChiliProject::Liquid::Tags::HelloWorld)
Liquid::Template.register_tag('variable_list', ChiliProject::Liquid::Tags::VariableList)
Liquid::Template.register_tag('tag_list', ChiliProject::Liquid::Tags::TagList)
