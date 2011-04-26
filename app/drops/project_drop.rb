class ProjectDrop < BaseDrop
  def name
    @object.name
  end

  def identifier
    @object.identifier
  end
end
