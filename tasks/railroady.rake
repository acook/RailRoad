# This suite of tasks generate graphical diagrams via code analysis.
# A UNIX-like environment is required as well as:
# 
# * The railroady gem. (http://github.com/preston/railroady)
# * The graphviz package which includes the `dot` and `neato` command-line utilities. MacPorts users can install in via `sudo port install graphviz`.
# * The `sed` command-line utility, which should already be available on all sane UNIX systems.
#
# Author: Preston Lee, http://railroady.prestonlee.com 
 
# Returns an absolute path for the following file.
def full_path(name = 'test.txt')
  f = File.join(Rails.root.to_s.gsub(' ', '\ '), 'doc', name)
  f.to_s
end

def git_repo_url
  "https://github.com/" + File.open(File.join(Rails.root.to_s.gsub(' ', '\ '), '.git', 'config'), 'r') do |f|
    while (line = f.gets)
      break if line.match(/git@github\.com:(.+)/)
    end
    # returns Mixbook/mixbook_com.git"
    line.match(/git@github\.com:(.+)/)[1].split('.')[0]
  end
end

def to_filename(str)
  str.downcase.gsub(/\s*diagram\s*/i, "") .underscore.gsub(/\s/, "/") if str
end
  
namespace :diagram do
 
  @CONTROLLERS_ALL_SVG = full_path('controllers_complete.svg').freeze
  @CONTROLLERS_BRIEF_SVG = full_path('controllers_brief.svg').freeze

  # Example config yaml file
  # ---
  #   :models:
  #   - :label: Visit/Referrer Diagram
  #     :filename: visit_referrer
  #     :filter: Referrer*, Visit*
  #     :group: "[Order, OrderRecipient], [ShoppingCart, ShoppingCartRecipient]"
  #   - :label: Visit/Order Diagram
  #     :filename: visit_order
  #     :filter: Visit*, Order*
  @CONFIG_YAML = File.join(Rails.root.to_s.gsub(' ', '\ '), 'config', 'railroady.yml')

  desc 'Generates an SVG class diagram for all models. Pass in OPTIONS to customize.'
  task :models do
    if File.exists?(@CONFIG_YAML)
      hash = YAML.load_file(@CONFIG_YAML)
      hash[:models].each do |model|
        model[:filename] ||= to_filename(model[:label] || model[:filter]) || "diagram"
        filename = "doc/diagrams/#{model[:filename]}.svg"
        FileUtils.mkdir_p(File.dirname(filename)) # make sure the folder-tree exists.
        options = "amM"
        options << "i" if model[:inheritance]
        sh %{railroady -#{options} -l "#{model[:label]}" -f "#{model[:filter]}" --github "#{git_repo_url}" -g "#{model[:group]}" | dot -Tsvg > #{filename}}
      end
    else
      path = if ENV["FILENAME"] && ENV["FILENAME"].include?("/")
        ENV["FILENAME"]
             else
         require 'fileutils'
         FileUtils.mkdir_p("#{Rails.root}/doc/diagrams/models")
         "doc/diagrams/models/#{ENV["FILENAME"] || filename}"
      end
      sh %{railroady -iamM #{ENV["OPTIONS"]} | dot -Tsvg > #{path}}
    end
  end
  
  namespace :controllers do
    desc 'Generates an SVG class diagram for all controllers.'
    task :complete do
      f = @CONTROLLERS_ALL_SVG
      puts "Generating #{f}"
      sh "railroady -ilC | neato -Tsvg > #{f}"
    end
 
    desc 'Generates an abbreviated SVG class diagram for all controllers.'
    task :brief do
      f = @CONTROLLERS_BRIEF_SVG
      puts "Generating #{f}"
      sh "railroady -bilC | neato -Tsvg > #{f}"
    end
  end
 
  desc 'Generates all SVG class diagrams.'
  task :all => ['diagram:models:complete', 'diagram:models:brief', 'diagram:controllers:complete', 'diagram:controllers:brief']

end