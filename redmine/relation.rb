# coding: utf-8

module RedmineCmdRelation
  def relation args
    OptionParser.new do |opts|
      opts.banner = "Usage:

  show relations:
    ticket relation [-options]

  create relation:
    ticket relation [-options] <id> <relation> <id>

  id1 -> id2   or   id1 precedes    id2
  id1 <- id2   or   id1 follows     id2
  id1 -o id2   or   id1 blocks      id2
  id1 o- id2   or   id1 blocked     id2
  id1 -c id2   or   id1 copied_to   id2
  id1 c- id2   or   id1 copied_from id2
  id1 -- id2   or   id1 relates     id2
  id1 == id2   or   id1 duplicates  id2

"
      opts.on("-r", "--remove") do # TODO: remove relation
      end
    end.order! args

    if args.size == 3
      create_relation args
    elsif args.size == 0
      show_relations
    end
  end

  def show_relations
    tmp = {}
    @cacheData.each do |id, v|
      v["relations"].each do |rel|
        if tmp[rel["id"]].nil?
          tmp[rel["id"]] = rel["issue_id"], rel["relation_type"], rel["issue_to_id"]
        end
      end
    end
    puts "Key\tFrom\tRelation\tTo"
    tmp.keys.sort.each do |key|
      puts "#{key}\t" + tmp[key].join("\t")
    end
  end

  def create_relation args
    sid = args[0]
    raise "ticket #{sid} not exist" if @cacheData[sid].nil?
    relation = parse_relation args[1]
    tid = args[2]
    raise "ticket #{tid} not exist" if @cacheData[tid].nil?

    upload_relation sid, {"relation": {"issue_to_id": tid, "relation_type": relation}}
  end

  def upload_relation id, data
    @options[:logger].debug(data)
    uri = URI("#{@baseurl}/issues/#{id}/relations.json")
    response = post_issue uri, data

    case response
    when Net::HTTPSuccess, Net::HTTPRedirection
      puts "upload done"
    else
      raise response.value
    end
    return response
  end

  def parse_relation str
    if not ["->", "<-", "-o", "o-", "-c", "c-", "--", "==", "precedes", "follows", "blocks", "blocked", "copied_to", "copied_from", "relates", "duplicates"].include? str
      raise "invalid relation: #{str}"
    end

    case str
    when "->"
      return "procedes"
    when "<-"
      return "follows"
    when "-o"
      return "blocks"
    when "o-"
      return "blocked"
    when "-c"
      return "copied_to"
    when "c-"
      return "copied_from"
    when "--"
      return "relates"
    when "=="
      return "duplicates"
    else
      return str
    end
  end

  def get_short_relation str
    if not ["->", "<-", "-o", "o-", "-c", "c-", "--", "==", "precedes", "follows", "blocks", "blocked", "copied_to", "copied_from", "relates", "duplicates"].include? str
      raise "invalid relation: #{str}"
    end

    case str
    when "procedes"
      return "->"
    when "follows"
      return "<-"
    when "blocks"
      return "-o"
    when "blocked"
      return "o-"
    when "copied_to"
      return "-c"
    when "copied_from"
      return "c-"
    when "relates"
      return "--"
    when "duplicates"
      return "=="
    else
      return str
    end
  end
end
