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

class AddAuthSourcePosition < ActiveRecord::Migration
  def self.up
    add_column :auth_sources, :position, :integer, :default => 1
    add_index :auth_sources, :position

    AuthSource.all.each_with_index {|auth, i| auth.update_attribute(:position, i+1)}
  end

  def self.down
    remove_column :auth_sources, :position
  end
end
