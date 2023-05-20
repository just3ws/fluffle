# frozen_string_literal: true

require 'amazing_print'
require 'curb'
require 'down'
require 'fileutils'
require 'logger'
require 'nokogiri'
require 'pry'
require 'time'
require 'streamio-ffmpeg'

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

  @podcast_feed = File.join(@working_dir, 'feed.xml')

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

    if File.exist?(@podcast_feed)
      puts 'SKIPPING: Podcast feed already exists'
    else
      puts 'Pulling podcast feed'

      xml_data = Curl.get(@podcast_url).body_str

      File.write(@podcast_feed, xml_data)
    end

    abort('Podcast feed not pulled') unless File.exist?(@podcast_feed)
  end

  # task convert: ['podcast:load'] do
  task convert: :environment do
    ap 'podcast:convert'
    Dir.chdir(@episodes_dir)

    Dir.glob(File.join(@episodes_dir, './.downloaded')).each do |dir|
      puts dir
    end

    Dir.children(Dir.pwd).each do |dir|
      if File.exist?(File.join(dir, '.converted'))
        puts 'Skipping .converted'
        next
      end
      next unless File.exist?(File.join(dir, '.downloaded'))

      mp3_path = File.join(dir, 'episode.mp3')
      next unless File.exist?(mp3_path)

      wav_path = File.join(dir, 'episode.wav')

      if File.exist?(wav_path)
        puts 'Skipping converted'
        FileUtils.touch(File.join(dir, '.converted'))

        next
      end

      ap "CONVERT #{dir}"

      FileUtils.touch(File.join(dir, '.converted'))

      mp3 = FFMPEG::Movie.new(mp3_path)
      mp3.transcode(
        wav_path,
        audio_codec: 'pcm_s16le',
        audio_sample_rate: 44_100,
        audio_channels: 2
      )
    end
  end

  task load: ['podcast:pull'] do
    ap 'podcast:load'

    xml_data = File.open(@podcast_feed)

    doc = Nokogiri::XML(xml_data, &:noblanks)

    episodes = doc.xpath('//item')

    episodes.each do |episode|
      episode_id = episode.at_css('guid').content

      episode_dir = File.join(@episodes_dir, episode_id)
      FileUtils.mkdir_p(episode_dir) unless Dir.exist?(episode_dir)

      log = Logger.new(File.join(episode_dir, 'episode.log'))
      log.level = Logger::DEBUG

      if File.exist?(File.join(episode_dir, '.downloaded'))
        message = [Time.now.iso8601(3), 'SKIPPING: Skipping due to .downloaded flag'].join("\t")
        log.warn { message }
        puts message

        next
      end

      if File.exist?(File.join(episode_dir, '.failed'))
        message = [Time.now.iso8601(3), 'SKIPPING: Skipping due to .failed flag'].join("\t")
        log.warn { message }
        puts message

        next
      end

      io = File.open(File.join(episode_dir, 'episode.xml'), 'w')
      episode.write_xml_to(io, encoding: 'UTF-8')

      enclosure = episode.at_css('enclosure')

      unless enclosure
        message = [Time.now.iso8601(3), "SKIPPING: No enclosure for episode_id: #{episode_id}"].join("\t")
        log.warn { message }
        puts message

        next
      end

      episode_url = enclosure['url']

      episode_mp3 = File.join(episode_dir, 'episode.mp3')

      if File.exist?(episode_mp3)
        message = [Time.now.iso8601(3), 'SKIPPING: Episode has already been downloaded'].join("\t")
        log.warn { message }
        puts message

        next
      end

      puts 'Downloading episode'

      begin
        message = [Time.now.iso8601(3), 'downloading'].join("\t")
        log.info { message }
        puts message

        FileUtils.touch(File.join(episode_dir, '.downloading'))

        Down.download(episode_url, destination: episode_mp3, max_redirects: 64)

        message = [Time.now.iso8601(3), 'downloaded'].join("\t")

        FileUtils.rm_f(File.join(episode_dir, '.downloading'))
        FileUtils.touch(File.join(episode_dir, '.downloaded'))

        log.info { message }
        puts message
      rescue StandardError => e
        FileUtils.touch(File.join(episode_dir, '.failed'))

        FileUtils.rm_f(episode_mp3)

        message = [Time.now.iso8601(3), 'failed'].join("\t")
        log.error { message }
        puts message

        log.debug { [e.class.name, e.message, e.backtrace.take(10).join("\n")].inspect }
      end
    end
  end
end

task default: [:setup, 'podcast:pull'] do
  ap 'default'
end
