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
          # inside of a project
          @project = context['project'].object if context['project'].present?

          if @page_name.present? &&
              (@project.present? || @page_name.include?(':')) # Allow cross project use with project:page_name
            return render_child_pages_from_single_page(context)
          elsif @project.present?
            return render_all_pages(context)
          else
            return TagError.new('child_pages', 'With no argument, this tag can be called from projects only.').to_s
          end
          
        end

        private

        def render_child_pages_from_single_page(context)
          cross_project_page = @page_name.include?(':')
          page = Wiki.find_page(@page_name.to_s, :project => (cross_project_page ? nil : @project))

          return TagError.new('child_pages', 'Page not found').to_s if page.nil? || !User.current.allowed_to?(:view_wiki_pages, page.wiki.project)

          pages = ([page] + page.descendants).group_by(&:parent_id)
          return context.registers[:view].render_page_hierarchy(pages, @options[:parent] ? page.parent_id : page.id)
        end
        
        def render_all_pages(context)
          return '' unless @project.wiki.present? && @project.wiki.pages.present?
          return TagError.new('child_pages', 'Page not found').to_s if !User.current.allowed_to?(:view_wiki_pages, @project)

          return context.registers[:view].render_page_hierarchy(@project.wiki.pages.group_by(&:parent_id))
        end
      end

      class IncludePage < ::Liquid::Tag

        def initialize(tag_name, markup, tokens)
          super
          if markup.present?
            @page_name = markup.gsub(/["']/,'').strip
          end
        end

        def render(context)
          @project = context['project'].object if context['project'].present?

          if @page_name.present?
            cross_project_page = @page_name.include?(':')

            page = Wiki.find_page(@page_name.to_s, :project => (cross_project_page ? nil : @project))
            return TagError.new('include_page', 'Page not found').to_s if page.nil? || !User.current.allowed_to?(:view_wiki_pages, page.wiki.project)
            return TagError.new('include_page', 'Circular inclusion detected').to_s if circular_inclusion?(context, page)

            add_page_to_included_page(context, page)
            
            # Call textilizable on the view so all of the helpers are loaded
            # based on the view and not this tag
            out = context.registers[:view].textilizable(page.content, :text, :attachments => page.attachments, :headings => false)
            @included_wiki_pages.pop
            return out

          else
            return TagError.new('include_page', 'Page not found').to_s
          end
        end
        
        private

        def circular_inclusion?(context, page)
          @included_wiki_pages = context['included_wiki_pages']
          @included_wiki_pages ||= []
          @included_wiki_pages.include?(page.title)
        end

        # Handle circular inclusion by storing a list of the already
        # included pages into an ivar in the view. Then it will come
        # into Liquid as part of context, which we can check.
        #
        def add_page_to_included_page(context, page)
          @included_wiki_pages << page.title
          context.registers[:view].instance_variable_set('@included_wiki_pages', @included_wiki_pages)
        end
      end

    end
  end
end

Liquid::Template.register_tag('hello_world', ChiliProject::Liquid::Tags::HelloWorld)
Liquid::Template.register_tag('variable_list', ChiliProject::Liquid::Tags::VariableList)
Liquid::Template.register_tag('tag_list', ChiliProject::Liquid::Tags::TagList)
Liquid::Template.register_tag('child_pages', ChiliProject::Liquid::Tags::ChildPages)
Liquid::Template.register_tag('include_page', ChiliProject::Liquid::Tags::IncludePage)
