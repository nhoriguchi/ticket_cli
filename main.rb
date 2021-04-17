#! /usr/bin/env ruby
# coding: utf-8

# 基本的に、どの外部システムを使うにしても、やりたい作業は「読む」「リストする」「書く」
# であり、これに対応していれば最低限の作業は可能である。
# 想定対象としては redmine, openproject, gist, rocketchat, teams など。

# TODO
# - draft 関連のハンドリングの部分はサーバー非依存にしたい。

require 'pp'
require 'yaml'
require 'optparse'

class MainCommand
  @@config = "#{ENV['HOME']}/.ticket/config"

  def self.cmd args
    tmp = YAML.load_file(@@config)

    @options = {
      :server => tmp['defaultserver'],
      :insecure => false,
      :debug => false,
    }
    @options.merge! tmp

    @options[:server] = ENV['SERVER'] if ENV['SERVER']
    @options[:insecure] = true if ENV['INSECURE']
    @options[:debug] = true if ENV['DEBUG']

    OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [-options] subcommand"
      opts.on("-s <server>", "--server") do |s|
        @options[:server] = s
      end
      opts.on("-S", "--insecure") do
        @options[:insecure] = true
      end
      opts.on("-D", "--debug") do
        @options[:debug] = true
      end
    end.order! args

    cmd = args.shift

    @options["cachedir"] += "/#{@options[:server]}"
    case tmp["servers"][@options[:server]]["type"]
    when "redmine"
      require_relative "./redmine.rb"

      redmine = Redmine.new @options
      if cmd == "list"
        redmine.list args
      elsif cmd == "show"
        redmine.show args
      elsif cmd == "edit"
        redmine.edit args
      elsif cmd == "config"
        redmine.config args
      elsif cmd == "new"
        redmine.new args
      elsif cmd == "attach"
        redmine.attach args
      else
        puts "help"
      end
    else
      raise "invalid config #{tmp}"
    end
  end
end

MainCommand.cmd ARGV
