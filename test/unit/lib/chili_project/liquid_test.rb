require File.expand_path('../../../../test_helper', __FILE__)

class ChiliProject::LiquidTest < ActionView::TestCase
  include ApplicationHelper

  context "hello_world tag" do
    should "render 'Hellow world!'" do
      text = "{% hello_world %}"
      assert_match /Hello world!/, textilizable(text)
    end
  end

  context "variable_list tag" do
    should "render a list of the current variables" do
      text = "{% variable_list %}"
      formatted = textilizable(text)
      
      assert formatted.include?('<ul>'), "Not in a list format"
      assert formatted.include?('current_user')
    end
  end

  context "child_pages tag" do
    context "with no arg" do
      context "and @project set" do
        should "should list all wiki pages for the current project" do
          @project = Project.generate!.reload
          wiki = @project.wiki
          top = WikiPage.generate!(:wiki => wiki, :title => 'Top', :content => WikiContent.new(:text => 'top page'))
          child1 = WikiPage.generate!(:wiki => wiki, :title => 'Child1', :content => WikiContent.new(:text => 'child'), :parent => top)

          text = "{% child_pages %}"
          formatted = textilizable(text)

          assert formatted.include?('pages-hierarchy')
          assert formatted.include?('Child1')
          assert formatted.include?('Top')
        end
      end

      context "and no @project set" do
        should "render a warning" do
          text = "{% child_pages %}"
          formatted = textilizable(text)

          assert_match /flash error/, formatted
          assert formatted.include?('With no argument, this tag can be called from projects only')
        end
      end

    end
    
    context "with a valid WikiPage arg" do
      should "list all child pages for the wiki page" do
        @project = Project.generate!.reload
        wiki = @project.wiki
        top = WikiPage.generate!(:wiki => wiki, :title => 'Top', :content => WikiContent.new(:text => 'top page'))
        child1 = WikiPage.generate!(:wiki => wiki, :title => 'Child1', :content => WikiContent.new(:text => 'child'), :parent => top)

        text = "{% child_pages 'Top' %}"
        formatted = textilizable(text)

        assert formatted.include?('pages-hierarchy')
        assert formatted.include?('Child1')
        assert !formatted.include?('Top')
      end

      should "allow cross project listings even when outside of a project" do
        project = Project.generate!.reload # project not an ivar
        wiki = project.wiki
        top = WikiPage.generate!(:wiki => wiki, :title => 'Top', :content => WikiContent.new(:text => 'top page'))
        child1 = WikiPage.generate!(:wiki => wiki, :title => 'Child1', :content => WikiContent.new(:text => 'child'), :parent => top)

        text = "{% child_pages #{project.identifier}:'Top' %}"
        formatted = textilizable(text)

        assert formatted.include?('pages-hierarchy')
        assert formatted.include?('Child1')
        assert !formatted.include?('Top')
      end
  
      should "show the WikiPage when parent=1 is set" do
        @project = Project.generate!.reload
        wiki = @project.wiki
        top = WikiPage.generate!(:wiki => wiki, :title => 'Top', :content => WikiContent.new(:text => 'top page'))
        child1 = WikiPage.generate!(:wiki => wiki, :title => 'Child1', :content => WikiContent.new(:text => 'child'), :parent => top)

        text = "{% child_pages 'Top', 'parent=1' %}"
        formatted = textilizable(text)

        assert formatted.include?('pages-hierarchy')
        assert formatted.include?('Child1')
        assert formatted.include?('Top')

      end
    end

    context "with an invalid arg" do
      should "render a warning" do
        @project = Project.generate!.reload
        wiki = @project.wiki
        top = WikiPage.generate!(:wiki => wiki, :title => 'Top', :content => WikiContent.new(:text => 'top page'))
        child1 = WikiPage.generate!(:wiki => wiki, :title => 'Child1', :content => WikiContent.new(:text => 'child'), :parent => top)

        text = "{% child_pages 1 %}"
        formatted = textilizable(text)
        
        assert_match /flash error/, formatted
        assert formatted.include?('Page not found')

      end
    end
  end

  context "include_page tag" do
    setup do
      @project = Project.generate!.reload
      @wiki = @project.wiki
      @included_page = WikiPage.generate!(:wiki => @wiki, :title => 'Included_Page', :content => WikiContent.new(:text => 'included page [[Second_Page]]'))

      @project2 = Project.generate!.reload
      @cross_project_page = WikiPage.generate!(:wiki => @project2.wiki, :title => 'Second_Page', :content => WikiContent.new(:text => 'second page'))

    end
    
    context "with a direct page" do
      should "show the included page's content" do
        text = "{% include_page 'Included Page' %}"
        formatted = textilizable(text)

        assert formatted.include?('included page')
      end
    end

    context "with a cross-project page" do
      should "show the included page's content" do
        text = "{% include_page #{@project2.identifier}:'Second Page' %}"
        formatted = textilizable(text)

        assert formatted.include?('second page')
      end
    end

    context "with a circular inclusion" do
      should "render a warning" do
        circle_page = WikiPage.generate!(:wiki => @wiki, :title => 'Circle', :content => WikiContent.new(:text => '{% include_page Circle2 %}'))
        circle_page2 = WikiPage.generate!(:wiki => @wiki, :title => 'Circle2', :content => WikiContent.new(:text => '{% include_page Circle %}'))
        formatted = textilizable(circle_page.reload.text)

        assert_match /flash error/, formatted
        assert formatted.include?('Circular inclusion detected')
      end
    end
    
    context "with an invalid arg" do
      should "render a warning" do
        text = "{% include_page '404' %}"
        formatted = textilizable(text)

        assert_match /flash error/, formatted
        assert formatted.include?('Page not found')
      end
    end
  end
  
end
