require File.expand_path('../../test_helper', __FILE__)

class IssueDropTest < ActiveSupport::TestCase
  include ApplicationHelper
  
  def setup
    @project = Project.generate!
    @issue = Issue.generate_for_project!(@project)
    @drop = IssueDrop.new(@issue)
  end

  [
   :tracker,
   :project,
   :subject,
   :description,
   :due_date,
   :category,
   :status,
   :assigned_to,
   :priority,
   :fixed_version,
   :author,
   :created_on,
   :updated_on,
   :start_date,
   :done_ratio,
   :estimated_hours,
   :parent
  ].each do |attribute|

    should "IssueDrop##{attribute} should return the actual #{attribute} attribute" do
      assert @issue.respond_to?(attribute), "Issue does not have an #{attribute} method"
      assert @drop.respond_to?(attribute), "IssueDrop does not have an #{attribute} method"
      
      assert_equal @issue.send(attribute), @drop.send(attribute)
    end
  end

  context "custom fields" do
    setup do
      @field = IssueCustomField.generate!(:name => 'The Name', :field_format => 'string', :is_for_all => true, :trackers => @project.trackers)
      @field_name_conflict = IssueCustomField.generate!(:name => 'Subject', :field_format => 'string', :is_for_all => true, :trackers => @project.trackers)
      @issue.custom_fields = [{'id' => @field.id, 'value' => 'Custom field value'},
                              {'id' => @field_name_conflict.id, 'value' => 'Second subject'}]
      assert @issue.save
      assert_equal "Custom field value", @issue.reload.custom_value_for(@field).value
      assert_equal "Second subject", @issue.reload.custom_value_for(@field_name_conflict).value
      @drop = IssueDrop.new(@issue)
    end
      
    should "be accessible under #custom_field(name)" do
      assert_equal @issue.reload.custom_value_for(@field).value, @drop.custom_field('The Name')
    end

    should "be accessible under the custom field name (lowercase, underscored)" do
      assert_equal @issue.reload.custom_value_for(@field).value, @drop.the_name

      assert textilizable("{{issue.the_name}}").include?("Custom field value")
    end

    should "not be accessible under the custom field name if it conflict with an existing drop method" do
      assert_equal @issue.subject, @drop.subject # no confict
    end
  end
  
end
