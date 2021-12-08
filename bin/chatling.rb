#!/usr/bin/env ruby

require_relative "../lib/chatling/cli"

cli = Chatling::CLI.new(ARGV)
cli.run
