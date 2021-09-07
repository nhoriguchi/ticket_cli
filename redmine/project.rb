# coding: utf-8

module RedmineCmdProject
  def project args
    @config = {}

    OptionParser.new do |opts|
      opts.banner = "Usage: ticket project"
      opts.on("-t", "--tree") do
        @config[:tree] = true
      end
    end.order! args

    if @config[:tree] == true
      p get_project_tree
    else
      show_projects
    end
  end

  def show_projects
    puts "ID\tProject Name"
    # pp @metaCacheData["projects"]
    @metaCacheData["projects"].sort_by {|v| v["id"]}.each do |pj|
      puts "#{pj["id"]}\t#{pj["identifier"]}\t#{pj["name"]}"
    end
  end

  def get_project_tree
    tree = {}
    @metaCacheData["projects"].each do |pj|
      next if pj["parent"].nil?
      parent = pj["parent"]["id"]
      tree[parent] = [] if tree[parent].nil?
      tree[parent] << pj["id"]
    end
    return tree
  end
end
