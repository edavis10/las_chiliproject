require File.expand_path('../../test_helper', __FILE__)

class ProjectDropTest < ActiveSupport::TestCase
  def setup
    @project = Project.generate!
    @drop = ProjectDrop.new(@project)
  end

  context "#name" do
    should "return the project name" do
      assert_equal @project.name, @drop.name
    end
  end

  context "#identifier" do
    should "return the project identifier" do
      assert_equal @project.identifier, @drop.identifier
    end
  end
  
end
