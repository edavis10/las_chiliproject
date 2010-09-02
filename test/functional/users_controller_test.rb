# redMine - project management software
# Copyright (C) 2006-2007  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require File.dirname(__FILE__) + '/../test_helper'
require 'users_controller'

# Re-raise errors caught by the controller.
class UsersController; def rescue_action(e) raise e end; end

class UsersControllerTest < ActionController::TestCase
  include Redmine::I18n
  
  fixtures :users, :projects, :members, :member_roles, :roles
  
  def setup
    @controller = UsersController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    User.current = nil
    @request.session[:user_id] = 1 # admin
  end
  
  def test_index
    get :index
    assert_response :success
    assert_template 'index'
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:users)
    # active users only
    assert_nil assigns(:users).detect {|u| !u.active?}
  end
  
  def test_index_with_name_filter
    get :index, :name => 'john'
    assert_response :success
    assert_template 'index'
    users = assigns(:users)
    assert_not_nil users
    assert_equal 1, users.size
    assert_equal 'John', users.first.firstname
  end
  
  def test_show
    @request.session[:user_id] = nil
    get :show, :id => 2
    assert_response :success
    assert_template 'show'
    assert_not_nil assigns(:user)
  end

  def test_show_should_not_fail_when_custom_values_are_nil
    user = User.find(2)

    # Create a custom field to illustrate the issue
    custom_field = CustomField.create!(:name => 'Testing', :field_format => 'text')
    custom_value = user.custom_values.build(:custom_field => custom_field).save!

    get :show, :id => 2
    assert_response :success
  end

  def test_show_inactive
    @request.session[:user_id] = nil
    get :show, :id => 5
    assert_response 404
  end
  
  def test_show_should_not_reveal_users_with_no_visible_activity_or_project
    @request.session[:user_id] = nil
    get :show, :id => 9
    assert_response 404
  end
  
  def test_show_inactive_by_admin
    @request.session[:user_id] = 1
    get :show, :id => 5
    assert_response 200
    assert_not_nil assigns(:user)
  end
  
  def test_show_displays_memberships_based_on_project_visibility
    @request.session[:user_id] = 1
    get :show, :id => 2
    assert_response :success
    memberships = assigns(:memberships)
    assert_not_nil memberships
    project_ids = memberships.map(&:project_id)
    assert project_ids.include?(2) #private project admin can see
  end

  def test_edit
    ActionMailer::Base.deliveries.clear
    post :edit, :id => 2, :user => {:firstname => 'Changed'}, :notification_option => 'all', :pref => {:hide_mail => '1', :comments_sorting => 'desc'}

    user = User.find(2)
    assert_equal 'Changed', user.firstname
    assert_equal 'all', user.mail_notification
    assert_equal true, user.pref[:hide_mail]
    assert_equal 'desc', user.pref[:comments_sorting]
    assert ActionMailer::Base.deliveries.empty?
  end
  
  def test_edit_with_activation_should_send_a_notification
    u = User.new(:firstname => 'Foo', :lastname => 'Bar', :mail => 'foo.bar@somenet.foo', :language => 'fr')
    u.login = 'foo'
    u.status = User::STATUS_REGISTERED
    u.save!
    ActionMailer::Base.deliveries.clear
    Setting.bcc_recipients = '1'
    
    post :edit, :id => u.id, :user => {:status => User::STATUS_ACTIVE}
    assert u.reload.active?
    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert_equal ['foo.bar@somenet.foo'], mail.bcc
    assert mail.body.include?(ll('fr', :notice_account_activated))
  end
  
  def test_edit_with_password_change_should_send_a_notification
    ActionMailer::Base.deliveries.clear
    Setting.bcc_recipients = '1'
    
    u = User.find(2)
    post :edit, :id => u.id, :user => {}, :password => 'newpass', :password_confirmation => 'newpass', :send_information => '1'
    assert_equal User.hash_password('newpass'), u.reload.hashed_password 
    
    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert_equal [u.mail], mail.bcc
    assert mail.body.include?('newpass')
  end
  
  def test_edit_membership
    post :edit_membership, :id => 2, :membership_id => 1,
                           :membership => { :role_ids => [2]}
    assert_redirected_to :action => 'edit', :id => '2', :tab => 'memberships'
    assert_equal [2], Member.find(1).role_ids
  end

  def test_new_membership_with_multiple_projects
    assert_difference 'User.find(2).members.count', 2 do
      post :edit_membership, :id => 2, :project_ids => [3,6], :membership => { :role_ids => ['1', '2']}
    end
  end
  
  def test_destroy_membership
    post :destroy_membership, :id => 2, :membership_id => 1
    assert_redirected_to :action => 'edit', :id => '2', :tab => 'memberships'
    assert_nil Member.find_by_id(1)
  end
end
