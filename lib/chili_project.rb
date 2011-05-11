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
require 'chili_project/liquid'
require 'chili_project/liquid/variables'
require 'chili_project/liquid/filters'
require 'chili_project/liquid/tags'
require 'chili_project/liquid/legacy'

ChiliProject::Liquid::Legacy.add('child_pages', :tag)
ChiliProject::Liquid::Legacy.add('include', :tag, 'include_page')

module ChiliProject
end
