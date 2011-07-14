class ModelNode
  attr_accessor :sti_inheritance, :grouping, :attributes, :type
  attr_reader :edges, :class_name, :model, :superclass_name


  def initialize(active_record_model, type, attributes=nil)
    raise ArgumentError, "Argument #{active_record_model} is not an ActiveRecord::Base" unless active_record_model < ActiveRecord::Base
    @model = active_record_model
    @superclass_name = @model.superclass.name.to_s
    @class_name = @model.name
    @type = type
    @attributes = attributes
    @edges = []  # Contains all edges this model_node points to via ->
    @sti_inheritance = false
  end

  def add_edge(input)
    raise ArgumentError, "Argument #{input} is not ModelNode or ActiveRecord::Reflection" unless(input.is_a?(ModelNode) || !input.class.to_s[/^ActiveRecord::Reflection/].nil?)
    result = !input.class.to_s[/^ActiveRecord::Reflection/].nil? ? ModelEdge.new(self, input) : input
    @edges << result
  end


  def ==(class_name)
    @class_name == class_name.to_s
  end

end