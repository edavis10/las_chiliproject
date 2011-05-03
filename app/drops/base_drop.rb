class BaseDrop < Liquid::Drop
  def initialize(object)
    @object = object
  end

  def object
    @object
  end
end
