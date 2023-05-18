# frozen_string_literal: true

require 'amazing_print'
require 'curb'
require 'fileutils'
require 'nokogiri'

ROOT_DIR = '~/podcasts'

PODCASTS = {
  'dead-rabbit-radio' => 'https://feeds.libsyn.com/140084/rss'
}.freeze

task :environment do
  ap 'environment'

  @podcast_name = ENV['PODCAST'].to_s
  @podcast_url = PODCASTS[@podcast_name]

  @working_dir = File.join(File.expand_path(ROOT_DIR), @podcast_name)
  @episodes_dir = File.join(@working_dir, 'episodes')
  @transcriptions_dir = File.join(@working_dir, 'transcriptions')
  @tmp_dir = File.join(@working_dir, 'tmp')

  ap ['environment', @podcast_name, @podcast_url, @working_dir]
end

task setup: :environment do
  ap 'setup'

  FileUtils.mkdir_p(@episodes_dir, verbose: true)
  FileUtils.mkdir_p(@transcriptions_dir, verbose: true)
  FileUtils.mkdir_p(@tmp_dir, verbose: true)
end

namespace :podcast do
  task pull: :environment do
    ap 'podcast:pull'

    podcast_feed = File.join(@working_dir, 'feed.xml')

    if File.exist?(podcast_feed)
      puts 'SKIPPING: Podcast feed already exists'
    else
      puts 'Pulling podcast feed'

      xml_data = Curl.get(@podcast_url).body_str

      File.write(podcast_feed, xml_data)
    end

    abort('Podcast feed not pulled') unless File.exist?(podcast_feed)
  end
end

task default: [:setup, 'podcast:pull'] do
  ap 'default'
end
