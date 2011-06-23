# RailRoady - RoR diagrams generator
# http://railroad.rubyforge.org
#
# Copyright 2007-2008 - Javier Smaldone (http://www.smaldone.com.ar)
# See COPYING for more details


# RailRoady diagram structure
class DiagramGraph

  attr_writer :label

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

  def add_cluster(superclass_name, node)
    # Remove node to be generated
    @nodes.delete_at(@nodes.index(node))

    node << superclass_name # node[-1] contains superclass_name

    # Check to see if node's superclass isn't already in another cluster
    if superclass_key = @clusters.select { |key, hash| hash[:nodes].flatten.include?(superclass_name) }.keys[0]
      @clusters[superclass_key][:nodes] << node
    else
      @clusters.include?(superclass_name) ? @clusters[superclass_name][:nodes] << node :
        @clusters[superclass_name] = {:nodes => [node]}
    end

    # Find superclass node to be generated and move it in clusters
    if i = @nodes.index { |array| array.include?(superclass_name) }
      @clusters[superclass_name][:nodes].unshift(@nodes[i])
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
    return dot_header +
           @nodes.map{ |n| dot_node(n[0], n[1], n[2]) }.join +
           @clusters.map{ |k, h| dot_cluster(k, h[:nodes]) }.join +
           @edges.map{ |e| dot_edge(e[0], e[1], e[2], e[3]) }.join +
           dot_footer
  end

  # Generate XMI diagram (not yet implemented)
  def to_xmi
     STDERR.print "Sorry. XMI output not yet implemented.\n\n"
     return ""
  end

  private

  def dot_cluster(name, nodes)
    block = dot_cluster_header(name)
    block += "\t" + nodes.map{|n| dot_node(n[0], n[1], n[2])}.join("\t")
    block += "\t" + dot_cluster_edges(name, nodes)
    "#{block} \t#{dot_footer}"
  end

  # Build DOT edges within a specific cluster
  def dot_cluster_edges(name, nodes)
    block = "\t\"#{name}_edge\"" + '[label="", fixedsize="false", width=0, height=0, shape=none]' + "\n"
    block += "\t\t#{quote(name)} -> \"#{name}_edge\"" + '[label="", dir="back", arrowtail=empty, arrowsize="2", len="0.2"]' + "\n"
    block += nodes[1..-1].map do |n|
      n[-1] == name ? dot_edge('is-a', "#{name}_edge", n[1]) : dot_edge('is-a-child', "#{n[-1]}", n[1])
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
#    "\t_diagram_info [shape=\"plaintext\", label=\"#{label.map {|x| "#{x}\\l" }.join}\", fontsize=13]\n"
    "\t labelloc=\"t\";\n \tlabel=\"#{label.map {|x| "#{x}\\l" }.join}\"\n"
  end

  # Build a DOT graph node
  def dot_node(type, name, attributes=nil)
    case type
      when 'model'
           options = 'shape=Mrecord, label="{' + name + '|'
           options += attributes.join('\l')
           options += '\l}"'
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

  # Build a DOT graph edge
  # http://www.graphviz.org/doc/info/attrs.html
  def dot_edge(type, from, to, name = '')
    options =  name != '' ? "label=\"#{name}\", " : ''
    case type
      when 'one-one'
           options += 'arrowtail=odot, arrowhead=odot, dir=both, concentrate=true'
      when 'one-many'
           options += 'arrowtail=odot, arrowhead=normal, dir=both, concentrate=true'
      when 'many-many'
           options += 'arrowtail=normal, arrowhead=normal, dir=both, concentrate=true'
      when 'is-a'
           options += 'label="", dir="none"'
      when 'is-a-child'
           options += 'label="", dir="back", arrowtail=empty'
      when 'event'
           options += "fontsize=10"
    end
    return "\t#{quote(from)} -> #{quote(to)} [#{options}]\n"
  end # dot_edge

  # Quotes a class name
  def quote(name)
    '"' + name.to_s + '"'
  end

end # class DiagramGraph
