# coding: utf-8
require 'pp'
require 'json'
require 'net/http'
require 'time'

confA = {
  :baseurl => "nhoriguchi-openproject.japaneast.cloudapp.azure.com",
  :baseport => 80,
  :baseapi => "/api/v3/work_packages",
  :token => ENV["OP_API_KEY"],
  :cacheFile => "/tmp/openproject1.cache",
  :typemap => {
    "task" => 1,
    "milestone" => 2,
    "phase" => 3,
    "feature" => 4,
    "epic" => 5,
    "user story" => 6,
    "bug" => 7,
  },
  :statusmap => {
    "new" => 1,
    "in specification" => 2,
    "specified" => 3,
    "confirmed" => 4,
    "to be scheduled" => 5,
    "scheduled" => 6,
    "in progress" => 7,
    "developed" => 8,
    "in testing" => 9,
    "tested" => 10,
    "test failed" => 11,
    "closed" => 12,
    "on hold" => 13,
    "rejected" => 14,
  },
  :prioritymap => {
    "low" => 7,
    "normal" => 8,
    "high" => 9,
    "Immediate" => 10,
  },
  :projectmap => {
    "Demo project" => 1,
    "Scrum project" => 2,
    "先行技術調査の検討" => 34,
    "IT業界動向全般" => 35,
    "root" => 36,
    "Blockchain/DLT" => 37,
    "MinBFT" => 38,
    "Hyperledger" => 39,
    "Fabric" => 40,
    "Linux" => 41,
    "NVDIMM/pmem" => 42,
    "RHEL" => 43,
    "LKML" => 44,
    "HWPOISON" => 45,
    "LWN" => 46,
    "Kernel Testing" => 47,
    "eBPF" => 48,
    "Cloud" => 49,
    "misc" => 50,
    "Database" => 51,
    "linux-bl" => 52,
  }
}

# Local server for testing
confB = {
  :baseurl => "192.168.0.26",
  :baseport => 8080,
  :baseapi => "/api/v3/work_packages",
  :token => "b174d6dc55feddcf82797b7370837348fb6c9b1b250bf6cf47cc1ae1938d5076",
  :cacheFile => "/tmp/openproject2.cache",
}

confC = {
  :baseurl => "nhoriguchi-openproject.japaneast.cloudapp.azure.com",
  :baseport => 80,
  :baseapi => "/api/v3/work_packages",
  :token => "3a7b9d129663b6d751d76eadf9b9bada0187c108c8eb16e8a68f24aa8b33f292",
  :cacheFile => "/tmp/openproject3.cache",
}

baseapi = "/api/v3/work_packages"

@pjmap = {
  1 => 42,
  2 => 37,
  3 => 38,
  4 => 40,
  5 => 41,
  7 => 43,
  6 => 45,
  8 => 49,
  9 => 49,
  10 => 49,
  11 => 49,
  12 => 44,
  13 => 50,
  15 => 50,
  16 => 50,
  17 => 49,
  18 => 47,
  19 => 50,
  20 => 36,
  22 => 39,
  23 => 46,
  24 => 48,
  25 => 52,
  26 => 42,
  27 => 51,

  14 => 3,
  21 => 3,
}

# Project to local OpenProject
#  - TopSE
#  - private
pjnamemap = {
  1 => "NVDIMM/pmem",
  2 => "Blockchain/DLT",
  3 => "MinBFT",
  4 => "Fabric",
  5 => "Linux",
  6 => "HWPOISON",
  7 => "RHEL",
  8 => "Cloud",
  9 => "Cloud",
  10 => "Cloud",
  11 => "Cloud",
  12 => "LKML",
  13 => "misc",
  15 => "misc",
  16 => "misc",
  17 => "Cloud",
  18 => "Kernel Testing",
  19 => "misc",
  20 => "root",
  22 => "Hyperledger",
  23 => "LWN",
  24 => "eBPF",
  25 => "linux-bl",
  26 => "NVDIMM/pmem",
  27 => "Database",
}

@trackermap = {
  "Epic" => 5,   # "Epic",
  "Task" => 1,   # "Task",
  "Event" => 1,  # "Task",
  "Report" => 1, # "Task",
}

@statusmap = {
  "New" => 1,     # "New",
  "WIP" => 7,     # "In Progress",
  "Done" => 12,   # "Closed",
  "Dont" => 14,   # "Rejected",
  "Closed" => 12, # "Closed",
  "Open" => 7,    # "In Progress",
}

@prioritymap = {
  "Low" => 7,        # "Low",
  "Normal" => 8,     # "Normal",
  "High" => 9,       # "High",
  "Urgent" => 10,    # "Immediate",
  "Immediate" => 10, # "Immediate",
}


# TODO: still under development
def prepareServerMeta conf
  reqget = Net::HTTP::Get.new("/api/v3/projects")
  reqget.basic_auth('apikey', conf[:token])
  http = Net::HTTP.new(conf[:baseurl], conf[:baseport])
  response = nil
  http.start do |http|
    response = http.request reqget
  end
  tmp1 = JSON.load(response.body)  
  conf[:projectmap] = {}
  tmp1["_embedded"].each do |pj|
    conf[:projectmap][pj["name"]] = pj["id"]
  end
  pp conf
end

def createWorkPackage conf, json
  req = Net::HTTP::Post.new(conf[:baseapi], 'Content-Type' => 'application/json')
  req.basic_auth('apikey', conf[:token])
  req.body = json

  http = Net::HTTP.new(conf[:baseurl], conf[:baseport])
  response = http.start do |http|
    http.request(req)
  end

  if response.code != "201"
    pp JSON.load(response.body)
    raise "failed to create Work Package"
  else
    puts "OK: #{response.code}"
  end
end

def updateWorkPackage id, conf, json
  reqget = Net::HTTP::Get.new(conf[:baseapi] + "/#{id}")
  reqget.basic_auth('apikey', conf[:token])
  http = Net::HTTP.new(conf[:baseurl], conf[:baseport])
  response = nil
  http.start do |http|
    response = http.request reqget
  end
  tmp1 = JSON.load(response.body)
  lockVersion = tmp1["lockVersion"]

  req = Net::HTTP::Patch.new(conf[:baseapi] + "/#{id}", 'Content-Type' => 'application/json')
  req.basic_auth('apikey', conf[:token])
  json["lockVersion"] = lockVersion
  req.body = json.to_json
  # pp json.to_json

  http.start do |http|
    response = http.request(req)
  end
  if response.code != "201"
    pp JSON.load(response.body)
  end
end

def getWorkPackage id, conf
  if id.nil?
    reqget = Net::HTTP::Get.new(conf[:baseapi])
  else
    reqget = Net::HTTP::Get.new(conf[:baseapi] + "/#{id}")
  end
  reqget.basic_auth('apikey', conf[:token])
  http = Net::HTTP.new(conf[:baseurl], conf[:baseport])
  response = nil
  http.start do |http|
    response = http.request reqget
  end
  return JSON.load(response.body)
end

def makeUpdateJson rmhash
  newtmp = {
    "subject" => rmhash["subject"],
    "_type" => "WorkPackage",
    "description" => {
        "format" => "markdown",
        "raw" => rmhash["description"]
    },
    "_links"=> {
      "project" => {"href" => "/api/v3/projects/#{@pjmap[rmhash["project"]["id"]]}"},
      "type" => {"href" => "/api/v3/types/#{@trackermap[rmhash["tracker"]["name"]]}"},
      "status" => {"href" => "/api/v3/statuses/#{@statusmap[rmhash["status"]["name"]]}"},
      "priority" => {"href" => "/api/v3/priorities/#{@prioritymap[rmhash["priority"]["name"]]}"},
    }
  }

  newtmp["startDate"] = rmhash["start_date"] if rmhash["start_date"]
  newtmp["dueDate"] = rmhash["due_date"] if rmhash["due_date"]
  newtmp["percentageDone"] = rmhash["done_ratio"]
  estimate = rmhash["estimated_hours"]
  estimate = 1 if ( ! estimate ) and ( rmhash["tracker"]["name"] == "Task" )
  newtmp["estimatedTime"] = "PT#{estimate}H" if estimate
  return newtmp
end

def addActivity id, conf, str
  req = Net::HTTP::Post.new(conf[:baseapi] + "/#{id}/activities", 'Content-Type' => 'application/json')
  req.basic_auth('apikey', conf[:token])
  tmp = {
    "comment": {
      "raw": str
    }
  }
  req.body = tmp.to_json

  response = nil
  http = Net::HTTP.new(conf[:baseurl], conf[:baseport])
  http.start do |http|
    response = http.request(req)
  end
  return JSON.load(response.body)
end

def updateCache conf, cache
  url = "http://" + conf[:baseurl] + conf[:baseapi]
  uri = URI(url)
  cacheUpdate = 0

  cacheFile = conf[:cacheFile]

  tmp = cache.map do |k, v|
    v["updatedAt"]
  end
  latest = tmp.sort[-1]
  day = (Time.now - Time.parse(latest)).to_i / 86400 + 1

  params = {"pageSize" => 500, "offset" => 1, "filters" => '[{"status":{"operator": "*"}}, {"updatedAt":{"operator":">t-", "values": ["'+"#{day}"+'"]}}]', "sortBy" => '[["updatedAt", "desc"]]'}
  uri.query = URI.encode_www_form(params)
  reqget = Net::HTTP::Get.new(uri)
  reqget.basic_auth('apikey', conf[:token])

  http = Net::HTTP.new(conf[:baseurl], conf[:baseport])
  res = nil
  http.start do |http|
    res = http.request reqget
  end
  tmp = JSON.load(res.body)
  total = tmp["total"]
  pageSize = tmp["pageSize"]
  tmp = tmp["_embedded"]["elements"]
  tmp.each do |elm|
    cache[elm["id"]] = elm
    cacheUpdate += 1
  end

  additional = (total - 1) / pageSize
  additional.times do |i|
    params = {"pageSize" => 500, "offset" => 2+i, "filters" => '[{"status":{"operator": "*"}}, {"updatedAt":{"operator":">t-", "values": ["'+"#{day}"+'"]}}]', "sortBy" => '[["updatedAt", "desc"]]'}
    uri.query = URI.encode_www_form(params)
    reqget = Net::HTTP::Get.new(uri)
    reqget.basic_auth('apikey', conf[:token])

    http = Net::HTTP.new(conf[:baseurl], conf[:baseport])
    res = nil
    http.start do |http|
      res = http.request reqget
    end
    tmp = JSON.load(res.body)["_embedded"]["elements"]
    tmp.each do |elm|
      cache[elm["id"]] = elm
      cacheUpdate += 1
    end
  end

  File.write(cacheFile, cache.to_json)
  return cacheUpdate
end

if ARGV[0] == "show"
  if ARGV[1]
    wpid = ARGV[1].to_i
    res = getWorkPackage wpid, confC
  else
    res = getWorkPackage nil, confC
  end
  pp res
  # converted info (Redmine -> OpenProject)
  #  - subject            -> ["subject"]
  #  - project            -> ["_links"]["project"]
  #  - tracker?           ->
  #  - status             -> ["_links"]["status"]
  #  - priority           ->
  #  - author             -> ["_links"]["status"]
  #  - assigned_to        -> ["_links"]["status"]
  #
  #  - description        -> ["description"]["raw"]
  #  - start_date         -> ["_links"]["date"]
  #  - due_date           -> ["_links"]["???"]
  #  - done_ratio         -> ["_links"]["percentageDone"]
  #  - estimated_hours    -> ["_links"]["estimatedTime"]
  #  - estimated_hours    -> ["_links"]["derivedEstimatedTime"]
  #  - created_on         -> ["_links"]["createdAt"]
  #  - updated_on         -> ["_links"]["updatedAt"]
  #  - closed_on          -> N/A
  #  - attachment         -> ["_links"]["status"]
  #  - relations          -> ["_links"]["status"]
elsif ARGV[0] == "update1"
  raise "DO NOT USE THIS ANY MORE"
  newtmp = {
    "subject"=>"sphinx_note の docker image の alpine 化",
    "_type" => "WorkPackage",
    "description": {
        "format": "markdown",
        "raw": "Imported From Redmine Ticket 4"
    },
    "_links"=>
    {"project"=>{"href"=>"/api/v3/projects/50"},
     "type"=>{"href"=>"/api/v3/types/1"},
     "status"=>{"href"=>"/api/v3/statuses/7"},
     "priority"=>{"href"=>"/api/v3/priorities/8"}
    }
  }

  # TODO: need lockVersion accourding to https://docs.openproject.org/api/work-packages/
  updateWorkPackage 74, confA, newtmp
elsif ARGV[0] == "create1"
  raise "DO NOT USE THIS ANY MORE"
  json = '{
    "subject":"My subject 2",
    "description": {
        "format": "markdown",
        "raw": "My raw ~markdown~ formatted description. _Bye guys!_"
    },
    "_links": {
        "project": {"href":"/api/v3/projects/1"},
        "type":{"href":"/api/v3/types/1"},
        "status":{"href":"/api/v3/statuses/1"},
        "priority":{"href":"/api/v3/priorities/8"}
    }
}'

  # STILL FAIL
  req = Net::HTTP::Post.new(confA[:baseapi], 'Content-Type' => 'application/json')
  req.basic_auth('apikey', confA[:token])
  req.body = json

  http = Net::HTTP.new(confA[:baseurl], confA[:baseport])
  response = http.start do |http|
    http.request(req)
  end

  # pp JSON.load(response.body)
  # pp response.value
elsif ARGV[0] == "showMeta"
  pp @pjmap
  pp @trackermap
  pp @statusmap
  pp @prioritymap
elsif ARGV[0] == "iterateRedmineTickets"
  raise "this finished it's job, so don't use it."

  tmp = JSON.parse(File.read("/home/hori/work/redmine/main/issues.json"))
  tmp["issues"].each do |is|
    next
    next if is["id"] == 2
    next if is["id"] == 4
    next if is["id"] == 73

    dst = "azure"
    if pjnamemap[is["project"]["id"]].nil?
      dst = "local"
    else
      next
    end

    puts "#{is["id"]} #{dst} #{is["status"]["name"]} #{is["project"]["name"]}: #{is["subject"]}"

    newtmp = makeUpdateJson is
    newtmp["description"]["raw"] = "#{is["id"]}"
    # pp newtmp

    if pjnamemap[is["project"]["id"]].nil?
      createWorkPackage confB, newtmp.to_json
    else
      createWorkPackage confA, newtmp.to_json
    end
  end
elsif ARGV[0] == "listWP"
  raise "this finished it's job, so don't use it, see id_mapping.txt"

  conf = confB # confA

  reqget = Net::HTTP::Get.new(conf[:baseapi])
  reqget.basic_auth('apikey', conf[:token])
  reqget.set_form_data({"pageSize" => 500, "offset" => 1, "filters" => '[{"status":{"operator": "*"}}]'})
  http = Net::HTTP.new(conf[:baseurl], conf[:baseport])
  response = nil
  http.start do |http|
    response = http.request reqget
  end
  tmp1 = JSON.load(response.body)
  # puts response.body

  reqget.set_form_data({"pageSize" => 500, "offset" => 2, "filters" => '[{"status":{"operator": "*"}}]'})
  http.start do |http|
    response = http.request reqget
  end
  tmp2 = JSON.load(response.body)

  puts response.body
elsif ARGV[0] == "copyTicket"
  raise "DONE"
  tmp = JSON.parse(File.read("/home/hori/work/redmine/main/issues.json"))
  rmid = ARGV[1].to_i
  a = tmp["issues"].find do |is|
    is["id"] == rmid
  end

  tmpidmap = {}
  File.read("/home/hori/work/hack/openproject/id_mapping.txt").split("\n").map do |line|
    tmpidmap[line.split("\t")[1].to_i] = line.split("\t")[0].to_i
  end
  targetwpid = tmpidmap[rmid]

  if a["custom_fields"]
    b = a["custom_fields"].find {|elm| elm["name"] == "customid"}
    targetwpid = b["value"].to_i
  end

  if targetwpid.nil?
    raise "No work package exist on server for Redmine issue #{rmid}."
  end

  newtmp = makeUpdateJson a
  pp newtmp
  if pjnamemap[a["project"]["id"]].nil?
    puts "copy data from Redmine Ticket #{rmid} to local OpenProject #{targetwpid}"
    updateWorkPackage targetwpid, confB, newtmp
  else
    puts "copy data from Redmine Ticket #{rmid} to Azure OpenProject #{targetwpid}"
    updateWorkPackage targetwpid, confA, newtmp
  end
elsif ARGV[0] == "copyTicketAll"
  raise "MAYBE DONE"
  tmpidmap = {}
  File.read("/home/hori/work/hack/openproject/id_mapping.txt").split("\n").map do |line|
    tmpidmap[line.split("\t")[1].to_i] = line.split("\t")[0].to_i
  end
  targetwpid = tmpidmap[rmid]

  tmp = JSON.parse(File.read("/home/hori/work/redmine/main/issues.json"))
  tmp["issues"].each do |is|
    rmid = is["id"]
    targetwpid = tmpidmap[rmid]
    next if targetwpid.nil?

    puts "#{rmid} #{targetwpid}"

    newtmp = makeUpdateJson is
    # pp newtmp
    if pjnamemap[is["project"]["id"]].nil?
      puts "copy data from Redmine Ticket #{rmid} to local OpenProject #{targetwpid}"
      updateWorkPackage targetwpid, confB, newtmp
    else
      puts "copy data from Redmine Ticket #{rmid} to Azure OpenProject #{targetwpid}"
      updateWorkPackage targetwpid, confA, newtmp
    end
  end
elsif ARGV[0] == "activity"
  raise "DONE"
  addActivity 176, confB, "comment test"
elsif ARGV[0] == "replaceLink1"
  raise "DONE"

  rmid = ARGV[1].to_i
  tmp = JSON.parse(File.read("/home/hori/work/redmine/main/issues.json"))
  r2o = {}
  o2r = {}
  File.read("/home/hori/work/hack/openproject/id_mapping.txt").split("\n").map do |line|
    r2o[line.split("\t")[1].to_i] = line.split("\t")[0].to_i
    o2r[line.split("\t")[0].to_i] = line.split("\t")[1].to_i
  end

  count = 0
  tmp["issues"].each do |is|
    rmid = is["id"]
    desc = is["description"]
    i = 0
    next if desc.nil?
    next if rmid == 493
    desc2 = desc.split("\r\n").map do |line|
      i += 1 if line =~ /\s*~~~$/ or line =~ /\s*```$/
      i += 1 if i % 2 == 0 and line == "<pre>"
      i += 1 if i % 2 == 1 and line == "</pre>"
      i += 1 if i % 2 == 0 and line == "#+begin_example"
      i += 1 if i % 2 == 1 and line == "#+end_example"
      if i % 2 == 0
        tmpline = line.dup
        line.gsub!(/(?<!MinBFT|fabdoc|SWF|Blockchain|#|\d|Issue |Pull Request |org::|cc info \(|\.md|\.html)#(\d{1,3})/) do |num|
          if r2o[$1.to_i]
            "##"+"#{r2o[$1.to_i]}"
          else
            "##{$1}"
          end
        end
        if tmpline != line
          puts "#{rmid}: --- #{tmpline}"
          puts "#{rmid}: +++ #{line}"
        end
      end
      line
    end.join("\r\n")
    if desc != desc2
      count += 1
      newtmp = makeUpdateJson is
      newtmp["description"]["raw"] = desc2
      if pjnamemap[is["project"]["id"]].nil?
        puts "update description of #{rmid}/local #{r2o[rmid]}"
        updateWorkPackage r2o[rmid], confB, newtmp
      else
        puts "update description of #{rmid}/azure #{r2o[rmid]}"
        updateWorkPackage r2o[rmid], confA, newtmp
      end
    end
  end
  puts "#{count} tickets are replaced."
elsif ARGV[0] == "copyNotes"
  raise "DONE"
  r2o = {}
  File.read("/home/hori/work/hack/openproject/id_mapping.txt").split("\n").map do |line|
    r2o[line.split("\t")[1].to_i] = line.split("\t")[0].to_i
  end
  targetwpid = r2o[rmid]

  # python3 ~/hack/docker/redmine/scripts/show_journal.py 848 | sed 's/^/> /'

  tmp = JSON.parse(File.read("/home/hori/work/redmine/main/issues.json"))
  tmp["issues"].each do |is|
    rmid = is["id"]
    targetwpid = r2o[rmid]
    next if targetwpid.nil?
    next if targetwpid == 76
    next if targetwpid == 74

    puts "Redmine:#{rmid} OpenProject:#{targetwpid}"
    journals = `python3 /home/hori/hack/docker/redmine/scripts/show_journal.py #{rmid} | sed 's/^/> /'`
    if journals.empty?
      puts "journal is empty"
      next
    else
      puts "journal is not empty"
      puts journals

      i = 0
      journals2 = journals.split("\r\n").map do |line|
        i += 1 if line =~ /\s*~~~$/ or line =~ /\s*```$/
        i += 1 if i % 2 == 0 and line == "<pre>"
        i += 1 if i % 2 == 1 and line == "</pre>"
        i += 1 if i % 2 == 0 and line == "#+begin_example"
        i += 1 if i % 2 == 1 and line == "#+end_example"
        if i % 2 == 0
          tmpline = line.dup
          line.gsub!(/(?<!MinBFT|fabdoc|SWF|Blockchain|#|\d|Issue |Pull Request |org::|cc info \(|\.md|\.html)#(\d{1,3})/) do |num|
            if r2o[$1.to_i]
              "##"+"#{r2o[$1.to_i]}"
            else
              "##{$1}"
            end
          end
          if tmpline != line
            puts "#{rmid}: --- #{tmpline}"
            puts "#{rmid}: +++ #{line}"
          end
        end
        line
      end.join("\r\n")

      journals3 = "Redmine の注記から過去ログの転載\n\n" + journals2

      if pjnamemap[is["project"]["id"]].nil?
        addActivity targetwpid, confB, journals3
      else
        addActivity targetwpid, confA, journals3
      end
    end
  end
elsif ARGV[0] == "setParents"
  r2o = {}
  File.read("/home/hori/work/hack/openproject/id_mapping.txt").split("\n").map do |line|
    r2o[line.split("\t")[1].to_i] = line.split("\t")[0].to_i
  end

  tmp = JSON.parse(File.read("/home/hori/work/redmine/main/issues.json"))
  tmp["issues"].each do |is|
    rmid = is["id"]
    parent = is["parent"]
    if parent
      puts "#{rmid}/#{r2o[rmid]} has parent #{parent["id"]}/#{r2o[parent["id"]]}"
      # "parent"=>{"href"=>"/api/v3/work_packages/2"}
      newtmp = {
        "_links" => {"parent" => {"href"=>"/api/v3/work_packages/#{r2o[parent["id"]]}"}}
      }
      if pjnamemap[is["project"]["id"]].nil?
        puts "set local #{rmid}/#{r2o[rmid]}'parent to #{parent["id"]}/#{r2o[parent["id"]]}"
        updateWorkPackage r2o[rmid], confB, newtmp
      else
        puts "set Azure #{rmid}/#{r2o[rmid]}'parent to #{parent["id"]}/#{r2o[parent["id"]]}"
        updateWorkPackage r2o[rmid], confA, newtmp
      end
    else
      puts "#{rmid}/#{r2o[rmid]} has no parent"
    end
  end
elsif ARGV[0] == "edit"
  opjid = ARGV[1].to_i
  tmp = getWorkPackage opjid, confA

  # prepareServerMeta confA
  # raise

  type = tmp["_links"]["type"]["title"]
  priority = tmp["_links"]["priority"]["title"]
  project = tmp["_links"]["project"]["title"]
  status = tmp["_links"]["status"]["title"]
  lockVersion = tmp["lockVersion"]
  subject = tmp["subject"]
  description = tmp["description"]["raw"]
  progress = tmp["percentageDone"]
  estimatedTime = tmp["estimatedTime"]
  startDate = tmp["startDate"]
  dueDate = tmp["dueDate"]
  parent = tmp["_links"]["parent"]["href"]
  parent = File.basename(parent) if parent

  editdata = ["---"]
  editdata << "ID: #{tmp["id"]}"
  editdata << "Progress: #{progress}"
  editdata << "Status: #{status}"
  editdata << "Subject: #{subject}"
  editdata << "Project: #{project}"
  editdata << "Type: #{type}"
  editdata << "Priority: #{priority}"
  editdata << "EstimatedTime: #{estimatedTime}"
  editdata << "StartDate: #{startDate}"
  editdata << "DueDate: #{dueDate}"
  editdata << "Parent: #{parent}"
  editdata << ["---"]
  editdata << description

  puts editdata.join("\n")

  require 'fileutils'
  tstamp = Time.now

  tmpdir = "/tmp/openproject/#{tstamp.strftime("%y%m%d_%H%M%S")}"
  FileUtils.mkdir_p tmpdir
  editFile = tmpdir + "/edit.md"
  File.write(editFile, editdata.join("\n"))
  File.write(tmpdir + "/arg", ARGV.join(" "))

  system "#{ENV["EDITOR"]} #{editFile}"

  afterEdit = File.read(editFile).split("\n")
  afterMeta = []
  afterDescription = []
  metaline = 0
  afterEdit.each do |line|
    if metaline == 0
      if line == "---"
        metaline = 1
      else
        afterDescription << line
      end
    elsif metaline == 1
      if line == "---"
        metaline = 2
      else
        afterMeta << line
      end
    else
      afterDescription << line
    end
  end

  tmphash = {
    "subject" => subject,
    "lockVersion" => lockVersion,
    "_type" => "WorkPackage",
    "description" => {
        "format" => "markdown",
        "raw" => description,
    },
    "percentageDone" => progress,
    "estimatedTime" => estimatedTime,
    "startDate" => startDate,
    "dueDate" => dueDate,
    "_links"=> {
      "project" => {"href" => "/api/v3/projects/#{confA[:projectmap][project]}"},
      "type" => {"href" => "/api/v3/types/#{confA[:typemap][type.downcase]}"},
      "status" => {"href" => "/api/v3/statuses/#{confA[:statusmap][status.downcase]}"},
      "priority" => {"href" => "/api/v3/priorities/#{confA[:prioritymap][priority.downcase]}"},
    }
  }

  afterMeta.each do |line|
    if line =~ /^(id):\s+(.*)$/i
    elsif line =~ /^(progress):\s+(.*)$/i
      tmphash["percentageDone"] = $2.to_i
    elsif line =~ /^(status):\s+(.*)$/i
      tmphash["_links"]["status"]["href"] = "/api/v3/statuses/#{confA[:statusmap][$2.downcase]}"
    elsif line =~ /^(subject):\s+(.*)$/i
      tmphash["subject"] = $2
    elsif line =~ /^(project):\s+(.*)$/i
      tmphash["_links"]["project"]["href"] = "/api/v3/projects/#{confA[:projectmap][$2]}"
    elsif line =~ /^(type):\s+(.*)$/i
      tmphash["_links"]["type"]["href"] = "/api/v3/types/#{confA[:typemap][$2.downcase]}"
    elsif line =~ /^(priority):\s+(.*)$/i
      tmphash["_links"]["priority"]["href"] = "/api/v3/priorities/#{confA[:prioritymap][$2.downcase]}"
    elsif line =~ /^(estimatedtime):\s+(.*)$/i
      # convert simple integer to the format like "PT4H"
      ehour = $2
      ehour = "PT#{ehour.to_i}H" if ehour =~ /^[0-9]+$/
      tmphash["estimatedTime"] = ehour.empty? ? nil : ehour
    elsif line =~ /^(startdate):\s+(.*)$/i
      tmphash["startDate"] = $2.empty? ? nil : $2
    elsif line =~ /^(duedate):\s+(.*)$/i
      tmphash["dueDate"] = $2.empty? ? nil : $2
    elsif line =~ /^(parent):\s+(.*)$/i
      parent = $2
      if parent.empty? or parent =~ /(null|nil)/i
        tmphash["_links"]["parent"] = {"href" => nil}
      else
        tmphash["_links"]["parent"] = {"href" => "/api/v3/work_packages/#{parent}"}
      end
    else
      puts "invalid metaline #{line}"
    end
  end
  tmphash["description"]["raw"] = afterDescription.join("\n")

  updateWorkPackage opjid, confA, tmphash

  # raise
  # if pjnamemap[is["project"]["id"]].nil?
  #   updateWorkPackage opjid, confB, newtmp
  # else
  # end

  ### TODO
  # assignee
  # activity
  # singal handling
  # conflict check
elsif ARGV[0] == "cache"
  cache = JSON.parse(File.read(confA[:cacheFile]))
  updated = updateCache confA, cache
  puts "#{updated} records are updated"
elsif ARGV[0] == "list"
  cache = JSON.parse(File.read(confA[:cacheFile]))
  keys = cache.keys.sort {|a, b| b.to_i <=> a.to_i}
  keys.each do |k|
    c = cache[k]
    printf "%-4d %3d %-10s %-14s (%s) %s\n", k, c["percentageDone"], c["_links"]["type"]["title"], c["_links"]["status"]["title"], c["_links"]["project"]["title"], c["subject"]
  end
elsif ARGV[0] == "tree"
  cache = JSON.parse(File.read(confA[:cacheFile]))
  pj = ARGV[1]

  def show_level k, cache, childIds, level=0
    puts "  "*level + "#{k} #{cache[k.to_s]["subject"]}"
    if childIds[k]
      childIds[k].each do |k2|
        show_level k2, cache, childIds, level+1
      end
    end
  end

  if pj == nil
    tmp = cache.values.group_by {|i| i["_links"]["project"]}
    # pp cache.values[0..2]
    tmp.each do |pj, issues|
      pjid = pj["href"].split("/")[-1].to_i
      puts "PJ:#{pjid} #{pj["title"]}"

      toplevels = []
      childIds = {}
      issues.sort! {|v| v["id"]}
      issues.each do |v|
        parent = v["_links"]["parent"]["href"]
        if parent == nil
          toplevels << v["id"]
        else
          pid = parent.split("/")[-1].to_i
          childIds[pid] = [] if childIds[pid] == nil
          childIds[pid] << v["id"]
        end
      end

      toplevels.each do |k|
        show_level k, cache, childIds, 1
      end
    end
  elsif pj.to_i > 0
    issues = cache.filter do |id, issue|
      issue["_links"]["project"]["href"] == "/api/v3/projects/#{pj.to_i}"
    end
    toplevels = []
    childIds = {}
    issues.each do |k, v|
      tmp = v["_links"]["parent"]["href"]
      if tmp == nil
        toplevels << k.to_i
      else
        pid = tmp.split("/")[-1].to_i
        childIds[pid] = [] if childIds[pid] == nil
        childIds[pid] << k.to_i
      end
    end

    toplevels.each do |k|
      show_level k, cache, childIds, 1
    end
  end
  # keys = cache.keys.sort {|a, b| b.to_i <=> a.to_i}
else
  puts "unexpected command #{ARGV[0]}"
end
