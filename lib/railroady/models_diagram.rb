# RailRoady - RoR diagrams generator
# http://railroad.rubyforge.org
#
# Copyright 2007-2008 - Javier Smaldone (http://www.smaldone.com.ar)
# See COPYING for more details

require 'railroady/app_diagram'
require 'railroady/model_edge'
require 'railroady/model_node'
require 'set'

# RailRoady models diagram
class ModelsDiagram < AppDiagram
  attr_reader :filter_class_names, :filter_association_names

  def initialize(options = OptionsStruct.new)
    super(options)
    @graph.diagram_type = 'Models'
  end
  
  # Process model files
  def generate
    generate_filter_sets!
    say_if_verbose("Generating models diagram")
    model_classes.each do |klass|
      begin
        process_class(klass) if !filter_class_names || filter_class_names.include?(klass.to_s)
      rescue Exception
        say("Warning: exception #{$!} raised while trying to load model class #{file}")
      end
    end
  end

  # Require all the files in the app/models directory.
  def load_environment
    super
    Rails::Application.subclasses.each(&:eager_load!)
  end

  def model_classes
    load_environment
    ActiveRecord::Base.descendants
  end
  
  # Aryk: Old way, doing it based on file name opens up the possibility of missing classes defined within files.
  #  def get_files(prefix ='')
  #    files = !@options.specify.empty? ? Dir.glob(@options.specify) : Dir.glob(prefix << "app/models/**/*.rb")
  #    files += Dir.glob("vendor/plugins/**/app/models/*.rb") if @options.plugins_models
  #    files -= Dir.glob(@options.exclude)
  #    files
  #  end

  # Process a model class
  def process_class(current_class)
    say_if_verbose("Processing #{current_class}", :tab => 1)

    # Is current_clas derived from ActiveRecord::Base?
    node = if defined?(ActiveRecord::Base) && current_class < ActiveRecord::Base
      node_attribs = []
      node_type = if @options.brief || current_class.abstract_class?
        'model-brief'
      else
        columns = current_class.send(@options.only_content_columns ? :content_columns : :columns).dup
        if @options.hide_magic
          # From patch #13351
          # http://wiki.rubyonrails.org/rails/pages/MagicFieldNames
          magic_fields = [
            "created_at", "created_on", "updated_at", "updated_on",
            "lock_version", "type", "id", "position", "parent_id", "lft",
            "rgt", "quote", "template" ]
          magic_fields << current_class.table_name + "_count" if current_class.respond_to? 'table_name'
          columns.reject! { |c| magic_fields.include?(c.name) }
        end
        columns.each do |column|
          node_attrib = column.name
          node_attrib += " :#{column.type}" unless @options.hide_types
          node_attribs << node_attrib
        end
        'model'
      end

      model_node = ModelNode.new(current_class, node_type, node_attribs)
      
      # Process class associations
      reflections = current_class.reflect_on_all_associations
      reflections.select! { |assoc| filter_association_names.include?(assoc.name) } if filter_association_names
      if @options.inheritance && !@options.transitive
        superclass_associations = current_class.superclass.reflect_on_all_associations
        reflections.reject! { |a| superclass_associations.include?(a) }
      end
      reflections.each { |r| process_association(model_node, r) }
      # Only consider meaningful inheritance relations for generated classes and group them into subgraphs/clusters
      model_node.sti_inheritance = true if @options.inheritance &&
        ![ActiveRecord::Base, Object].include?(current_class.superclass) && filter_class_names.include?(current_class.superclass.to_s)
      model_node
    elsif @options.all && (current_class.is_a? Class)
      # Not ActiveRecord::Base model
      node_type = @options.brief ? 'class-brief' : 'class'
      ModelNode.new(current_class, node_type)
    elsif @options.modules && (current_class.is_a? Module)
      ModelNode.new(current_class, 'module')
    end

    @graph.add_model_node(node)
  end

  # Process a model association
  def process_association(model_node, reflection)
    say_if_verbose("Processing model association #{reflection.name.to_s}", :tab => 2)

    if reflection.macro.to_s == 'belongs_to' && @options.hide_belongs_to
      say_if_verbose("Skipping model association #{reflection.name.to_s}", :tab => 3)
      return
    end
    
    model_node.add_edge(reflection)
  end

  private

  def potential_class_name?(class_name)
    class_name=~/^[A-Z][\w\d]+$/
  end

  # Expression created from @options.filter to match against
  # If they simply did "Klass*", replace that with "Klass.*" for regexp matching
  def filter_expression
    @filter_expression ||= /^(#{@options.filter.map { |f| f.gsub(/(\w)\*/, '\1.*').strip } * "|"})$/
  end

  def say_if_verbose(*args)
    say(*args) if @options.verbose
  end

  def say(msg, options={})
    tab = options[:tab] || 0
    STDERR.print "#{"\t" * tab}#{msg}\n"
  end

  def generate_filter_sets!
    return if @options.filter.empty?
    @filter_class_names, @filter_association_names = Set.new, Set.new
    generate_filter_sets_by_detecting_constants_and_associations!
    generate_filter_sets_by_loading_constants!
    expand_filter_sets_by_inheritance!
    say_if_verbose("Limiting class names to:\n#{@filter_class_names.to_a.join(", ")}\n")
    say_if_verbose("Limiting association names to:\n#{@filter_association_names.to_a.join(", ")}\n")
  end

  def expand_filter_sets_by_inheritance!
    @filter_class_names.to_a.each do |class_name|
      filter_class = class_name.constantize
      model_classes.each { |klass| @filter_class_names << klass.to_s if klass < filter_class }
    end
  end

  # Look through the loaded models and attempt to match using elements from @options.filter.
  def generate_filter_sets_by_detecting_constants_and_associations!
    model_classes.each do |klass|
      @filter_class_names << klass.to_s if filter_expression.match(klass.to_s)
      if defined?(ActiveRecord::Base) && klass < ActiveRecord::Base
        klass.reflect_on_all_associations.each do |reflection|
          if [reflection.name.to_s, reflection.class_name].any? { |name| filter_expression.match(name) }
            @filter_association_names << reflection.name
            @filter_class_names << reflection.class_name
          end
        end
      end
    end
  end

  # Populates the @filter_class_names by detecting explicit class names in the filter.
  def generate_filter_sets_by_loading_constants!
    @options.filter.each do |filter|
      begin
        @filter_class_names << filter.constantize.to_s
      rescue LoadError
        say_if_verbose("Thought #{filter} was a class name, but couldn't find it.")
      end if potential_class_name?(filter)
    end
  end

end # class ModelsDiagram
