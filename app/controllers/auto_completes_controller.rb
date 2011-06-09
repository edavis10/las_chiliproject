class AutoCompletesController < ApplicationController
  before_filter :find_project, :only => :issues

  helper :custom_fields
  
  def issues
    @issues = []
    q = params[:q].to_s

    if q.present?
      query = (params[:scope] == "all" && Setting.cross_project_issue_relations?) ? Issue : @project.issues

      @issues |= query.visible.find_all_by_id(q.to_i) if q =~ /^\d+$/

      @issues |= query.visible.find(:all,
                                    :limit => 10,
                                    :order => "#{Issue.table_name}.id ASC",
                                    :conditions => ["LOWER(#{Issue.table_name}.subject) LIKE :q OR CAST(#{Issue.table_name}.id AS CHAR(13)) LIKE :q", {:q => "%#{q.downcase}%" }])
    end
    @issues.compact!
    render :layout => false
  end

  def users
    if params[:remove_group_members].present?
      @group = Group.find(params[:remove_group_members])
      @removed_users = @group.users
    end

    if params[:remove_watchers].present? && params[:klass].present?
      watcher_class = params[:klass].constantize
      if watcher_class.included_modules.include?(Redmine::Acts::Watchable) # check class is a watching class
        @object = watcher_class.find(params[:remove_watchers])
        @removed_users = @object.watcher_users
      end
    end

    @removed_users ||= []

    if params[:include_groups]
      user_finder = Principal
    else
      user_finder = User
    end
    
    @users = user_finder.active.like(params[:q]).find(:all, :limit => 100) - @removed_users
    render :layout => false
  end
  
  private

  def find_project
    project_id = (params[:issue] && params[:issue][:project_id]) || params[:project_id]
    @project = Project.find(project_id)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

end
