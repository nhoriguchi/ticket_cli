#! /usr/bin/env ruby
# coding: utf-8

# 基本的に、どの外部システムを使うにしても、やりたい作業は「読む」「リストする」「書く」
# であり、これに対応していれば最低限の作業は可能である。
# 想定対象としては redmine, openproject, gist, rocketchat, teams など。

require 'pp'
require 'json'


class MainCommand
  @@basedir = "/home/hori/hack/ticket"
  @@config = "config/redmine1.json"

  def self.cmd args

    configPath = [@@basedir, @@config].join("/")
    tmp = JSON.parse(File.read(configPath))

    cmd = args[0]

    case tmp["type"]
    when "redmine"
      require_relative "./redmine.rb"
      redmine = Redmine.new tmp
      if cmd == "list"
        redmine.list
      elsif cmd == "show"
        if args[1]
          redmine.show args[1]
        else
          puts "help"
        end
      elsif cmd == "edit"
        if args[1]
          redmine.edit args[1]
        else
          puts "help"
        end
      elsif cmd == "config"
      elsif cmd == "new"
      elsif cmd == "attach"
      else
        puts "help"
      end
    else
      raise "invalid config #{tmp}"
    end
  end
end

MainCommand.cmd ARGV
