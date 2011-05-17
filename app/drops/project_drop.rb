class ProjectDrop < BaseDrop
  
  def initialize(object)
    if object.visible?
      @object = object
    end
  end

  allowed_methods :name
  allowed_methods :identifier
end
