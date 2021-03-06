#-- copyright
# ChiliProject is a project management system.
#
# Copyright (C) 2010-2011 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

class AddTrackerIsInRoadmap < ActiveRecord::Migration
  def self.up
    add_column :trackers, :is_in_roadmap, :boolean, :default => true, :null => false
  end

  def self.down
    remove_column :trackers, :is_in_roadmap
  end
end
