module ChiliProject
  module Liquid
    module Tags

      # @param args [Array, String] An array of strings in "key=value" format
      # @param keys [Hash, Symbol] List of keyword args to extract
      def self.extract_options(args, *keys)
        options = {}
        args.each do |arg|
          if arg.to_s.gsub(/["']/,'').strip =~ %r{^(.+)\=(.+)$} && keys.include?($1.downcase.to_sym)
            options[$1.downcase.to_sym] = $2
          end
        end
        return options
      end
        
      class TagError
        def initialize(tag_name, message)
          @tag_name = tag_name
          @message = message
        end

        def to_s
          "<div class=\"flash error\">Error executing the <strong>#{@tag_name}</strong> tag (#{@message})</div>"
        end

      end

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
      
      class ChildPages < ::Liquid::Tag
        include ActionView::Helpers::TagHelper
        include ActionView::Helpers::UrlHelper
        include ActionView::Helpers::TextHelper
        include ActionController::UrlWriter
        include ApplicationHelper

        def self.default_url_options
          {:only_path => true }
        end

        def initialize(tag_name, markup, tokens)
          super
          if markup.present?
            tag_args = markup.split(',')
            @page_name = tag_args.shift.gsub(/["']/,'') # strip quotes
            @page_name.strip!

            @options = Tags.extract_options(tag_args, :parent)
            @options[:parent] ||= false
          end
        end

        def render(context)
          if context['project'].present? # inside of a project
            @project = context['project'].object
          end

          if @page_name.present? &&
              (@project.present? || @page_name.include?(':')) # Allow cross project use with project:page_name
            cross_project_page = @page_name.include?(':')

            page = Wiki.find_page(@page_name.to_s, :project => (cross_project_page ? nil : @project))

            return TagError.new('child_pages', 'Page not found').to_s if page.nil? || !User.current.allowed_to?(:view_wiki_pages, page.wiki.project)

            pages = ([page] + page.descendants).group_by(&:parent_id)
            return render_page_hierarchy(pages, @options[:parent] ? page.parent_id : page.id)
          elsif @project.present?
            @project = context['project'].object
            return '' unless @project.wiki.present? && @project.wiki.pages.present?
            return TagError.new('child_pages', 'Page not found').to_s if !User.current.allowed_to?(:view_wiki_pages, @project)

            return render_page_hierarchy(@project.wiki.pages.group_by(&:parent_id))
          else
            return TagError.new('child_pages', 'With no argument, this tag can be called from projects only.').to_s
          end
          
        end
      end

      # TODO: include

    end
  end
end

Liquid::Template.register_tag('hello_world', ChiliProject::Liquid::Tags::HelloWorld)
Liquid::Template.register_tag('variable_list', ChiliProject::Liquid::Tags::VariableList)
Liquid::Template.register_tag('tag_list', ChiliProject::Liquid::Tags::TagList)
Liquid::Template.register_tag('child_pages', ChiliProject::Liquid::Tags::ChildPages)
