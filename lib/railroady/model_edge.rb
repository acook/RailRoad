class ModelEdge
  attr_accessor :from_class_name, :to_class_name, :association_type, :reflection
  attr_writer :model_node
  LIST_OF_EDGE_TYPES = %w{invisible one-one one-many many-many}
  @@habtm = []

  def initialize(model_node, reflection)
    self.model_node = model_node
    @reflection = reflection
    # Only non standard association names needs a label
    # Patch from "alpack" to support classes in a non-root module namespace. See: http://disq.us/yxl1v
    @to_class_name = @reflection.class_name.gsub(%r{^::}, '')
    @association_type = @reflection.name.to_s
    @type = nil
    @model = nil
  end

  def model_node=(input)
    raise ArgumentError, 'Argument is not a valid ModelNode' unless input.is_a?(ModelNode)
    @model_node = input
    @from_class_name = @model_node.class_name
  end

  def type
    @type = determine_edge_type
  end

  def type=(input)
    raise ArgumentError, 'Argument is not a valid edge type' unless LIST_OF_EDGE_TYPES.include?(input)
    @type = input
  end

#  def inspect
#    # Omit activerecord model for sanity
#
#   "<" + self.instance_variables.select { |var| var != @model_node }.map do |var|
#      "#{var.to_s}:'#{instance_variable_get(var)}'"
#    end.join(" ") + ">"
#  end

  private

  def determine_edge_type
#    # Ignoring belongs_to macro since has_many and has_one edges' arrowtails/arrowheads will succinctly indicate
#    # the relationship between the models, there is no need to duplicate the edges to indicated the relationship in reverse.
#    # Doesn't conflict with polymorphic belongs_to relationships.
    if @reflection.macro.to_s == 'belongs_to' && @to_class_name.constantize.reflect_on_all_associations(:has_many).any? do
        |r| r.name == @model_node.class_name.underscore.pluralize.to_sym
      end
      'invisible'
    elsif ['has_one', 'belongs_to'].include? @reflection.macro.to_s
      'one-one'
    elsif @reflection.macro.to_s == 'has_many' && !@reflection.options[:through]
      'one-many'
    elsif !@@habtm.include?([@reflection.class_name, @from_class_name, @association_type]) # && @filter_association_names.include?(@association_type)# habtm or has_many, :through
      @@habtm << [@from_class_name, @reflection.class_name, @association_type]
      'many-many'
    end
  end
end