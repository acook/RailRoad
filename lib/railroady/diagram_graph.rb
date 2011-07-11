# RailRoady - RoR diagrams generator
# http://railroad.rubyforge.org
#
# Copyright 2007-2008 - Javier Smaldone (http://www.smaldone.com.ar)
# See COPYING for more details


# RailRoady diagram structure
class DiagramGraph

  attr_writer :label
  attr_accessor :github
  APP_MODEL_GIT_PATH = "blob/master/app/models/"
  SVG_COLORS = %w{chocolate beige blue blueviolet brown coral crimson cyan grey green lightblue lime navy olive orange pink plum purple red}

  def initialize
    @diagram_type = ''
    @show_label = false
    @nodes = []
    @edges = []
    @clusters = {}
  end

  def add_node(node)
    @nodes << node
  end

  def add_edge(edge)
    @edges << edge
  end

  # Refactoring: should probably use Sets instead of hashes.
  def add_cluster(superclass_name, node)
    # Remove node to be generated
    @nodes.delete_at(@nodes.index(node))

    node[:superclass_name] = superclass_name
    
    # Check to see if node's superclass isn't already in another cluster
    superclass_hash = @clusters.select { |key, array_node_hash| array_node_hash.any? {|x| x[:class_name] == superclass_name } }
    unless superclass_hash.empty?
      @clusters[superclass_hash.keys.first] << node
    else
      @clusters.include?(superclass_name) ? @clusters[superclass_name] << node :
        @clusters[superclass_name] = [node]
    end

    # Find superclass node to be generated and move it in clusters
    if i = @nodes.index { |hash| hash[:class_name] == superclass_name }
      @clusters[superclass_name].unshift(@nodes[i])
      @nodes.delete_at(i)
    end

  end

  def diagram_type= (type)
    @diagram_type = type
  end

  def show_label= (value)
    @show_label = value
  end

  def label
    @label ||= [
      "#{@diagram_type} diagram",
      "Date: #{Time.now.strftime "%b %d %Y - %H:%M"}" +
      "Migration version: #{ActiveRecord::Migrator.current_version}" +
      "Generated by #{APP_HUMAN_NAME} #{APP_VERSION}"+
      "http://railroady.prestonlee.com" ]
  end


  # Generate DOT graph
  def to_dot
#    puts @clusters.inspect
    return dot_header +
           @nodes.map{ |node_hash| dot_node(node_hash) }.join +
           @clusters.map{ |k, nodes| dot_cluster(k, nodes, SVG_COLORS[rand(SVG_COLORS.size)]) }.join +
           @edges.map{ |edge_hash| dot_edge(edge_hash) }.join +
           dot_footer
  end

  # Generate XMI diagram (not yet implemented)
  def to_xmi
     STDERR.print "Sorry. XMI output not yet implemented.\n\n"
     return ""
  end

  private

  def dot_cluster(name, nodes, color)
    block = dot_cluster_header(name)
    block += "\t" + nodes.map{ |node_hash| dot_node(node_hash) }.join("\t")
    block += "\t" + dot_cluster_edges(name, nodes)
    "#{block} \t#{dot_footer}"
  end

  # Build DOT edges within a specific cluster
  #TODO: fix so that edges converge to a single point only when it has more than 3 childern.
  def dot_cluster_edges(name, node_hash)
    block = "\t\"#{name}_edge\"" + '[label="", fixedsize="false", width=0, height=0, shape=none]' + "\n"
    block += "\t\t#{quote(name)} -> \"#{name}_edge\"" + '[label="", dir="back", arrowtail=empty, arrowsize="2", len="0.2"]' + "\n"

    block += node_hash[1..-1].map do |node|
      type, class_name = node[:superclass_name]==name ? ['is-a', "#{name}_edge"] : ['is-a-child', node[:superclass_name]]
      dot_edge(:type => type, :class_name => class_name, :association_class_name => node[:class_name])
    end.join("\t")
  end

  def dot_cluster_header(name)
    "\tsubgraph cluster_#{name.underscore} {\n \t\tlabel=#{quote(name)}\n"
  end

  # Build DOT diagram header
  def dot_header
    "digraph #{@diagram_type.downcase}_diagram {\n\tgraph[overlap=false, splines=ortho]\n#{dot_label}"
  end

  # Build DOT diagram footer
  def dot_footer
    "}\n"
  end

  # Build diagram label
  def dot_label
    return if !@show_label || label.empty?
    "\tlabelloc=\"t\";\n \tlabel=\"#{label.map {|x| "#{x}\\l" }.join}\"\n"
  end

  # Build a DOT graph node
  def dot_node(node_hash)
    type, name, attributes, filename, color = node_hash[:type], node_hash[:class_name], node_hash[:attributes], node_hash[:class_name], node_hash[:color]

    case type
      when 'model'
           options = 'shape=Mrecord, label="{' + name + '|'
           options += attributes.join('\l')
           options += '\l}"'
           options += ", bgcolor=#{quote(color)}"
           if filepath = file_url(name)
             options += ", URL=#{quote(filepath)}"
           end
      when 'model-brief'
           options = ''
      when 'class'
           options = 'shape=record, label="{' + name + '|}"'
      when 'class-brief'
           options = 'shape=box'
      when 'controller'
           options = 'shape=Mrecord, label="{' + name + '|'
           public_methods    = attributes[:public].join('\l')
           protected_methods = attributes[:protected].join('\l')
           private_methods   = attributes[:private].join('\l')
           options += public_methods + '\l|' + protected_methods + '\l|' +
                      private_methods + '\l'
           options += '}"'
      when 'controller-brief'
           options = ''
      when 'module'
           options = 'shape=box, style=dotted, label="' + name + '"'
      when 'aasm'
           # Return subgraph format
           return "subgraph cluster_#{name.downcase} {\n\tlabel = #{quote(name)}\n\t#{attributes.join("\n  ")}}"
    end # case
    return "\t#{quote(name)} [#{options}]\n"
  end # dot_node

  def file_url(class_name)
    filename = class_name.underscore
    last = nil
    possible_paths = filename.split("/").map do |piece|
      last = [last, piece].join("/")
    end
    path = possible_paths.detect do |path|
      File.exists?("#{Rails.root}/app/models#{path}.rb")
    end
    path ||= filename
    @github + APP_MODEL_GIT_PATH + path[1..-1] + '.rb' if !@github.nil?
  end

  # Build a DOT graph edge
  # http://www.graphviz.org/doc/info/attrs.html
  def dot_edge(edge_hash)
    type, from, to = edge_hash[:type], edge_hash[:class_name], edge_hash[:association_class_name]
    name = edge_hash[:association_name] || ''
    options =  name != '' ? "label=\"#{name}\", tooltip=\"#{name}\", " : ''
    options +=  case type
      when 'one-one'    then 'arrowtail=tee,  arrowhead=odot, dir="both", concentrate=true'
      when 'one-many'   then 'arrowtail=odot, arrowhead=crow, dir="both", concentrate=true'
      when 'many-many'  then 'arrowtail=crow, arrowhead=crow, dir="both", concentrate=true'
      when 'is-a'       then 'label="", dir="none"'
      when 'is-a-child' then 'label="", dir="back", arrowtail=empty'
      when 'invisible'  then 'style=invis, dir=both'
      when 'event'      then "fontsize=10"
      else raise("Unknown type: #{type}")
    end

    if len = compute_length(from, to, type)
      options << ", len=#{len}"
    end

    "\t#{quote(from)} -> #{quote(to)} [#{options}]\n"
  end # dot_edge

  # Quotes a class name
  def quote(name)
    '"' + name.to_s + '"'
  end

  # Compute estimated length between two nodes.
  # We attempt to use queues about the classes to determine their "closeness"
  def compute_length(from_class_name, to_class_name, type)
    # Function only currently works for AR classes
    return unless [from_class, to_class].all? { |x| x.is_a?(ActiveRecord::Base) }

    len = 10
    if type.include?("is-a")
      len -= 9
    elsif to_class_name.starts_with?(from_class_name) || from_class_name.starts_with?(to_class_name)
      len -= 6
    elsif to_class_name.include?(from_class_name) || from_class_name.include?(to_class_name)
      len -= 3
    end
    len
  end

end # class DiagramGraph
