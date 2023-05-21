# frozen_string_literal: true

require 'amazing_print'
require 'curb'
require 'down'
require 'fileutils'
require 'nokogiri'
require 'streamio-ffmpeg'
require 'time'
require 'net/ssh'
require 'ruby-progressbar'

ROOT_DIR = '~/podcasts'

PODCASTS = {
  'dead-rabbit-radio' => 'https://feeds.libsyn.com/140084/rss',
  'belief-hole' => 'https://feeds.libsyn.com/112657/rss',
  'philosophize-this' => 'https://feeds.libsyn.com/44756/rss'
}.freeze

TRANSCODING_OPTIONS = {
  audio_codec: 'pcm_s16le',
  audio_sample_rate: 44_100,
  audio_channels: 2
}.freeze

task :environment do
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
  FileUtils.mkdir_p(@episodes_dir, verbose: true)
  FileUtils.mkdir_p(@transcriptions_dir, verbose: true)
  FileUtils.mkdir_p(@tmp_dir, verbose: true)
end

namespace :podcast do
  task pull: :environment do
    unless File.exist?(@podcast_feed)
      curl = Curl::Easy.new(@podcast_url)
      curl.verbose = true
      curl.perform

      xml_data = curl.body_str

      File.write(@podcast_feed, xml_data)
    end

    abort('Podcast feed not pulled') unless File.exist?(@podcast_feed)
  end

  task distribute: :environment do
    puts 'podcast:distribute'

    Dir.chdir(@episodes_dir)
  end

  task convert: :environment do
    Dir.chdir(@episodes_dir)

    Dir.children('.').each do |dir|
      next if File.exist?(File.join(dir, '.converted'))
      next unless File.exist?(File.join(dir, '.downloaded'))

      mp3_path = File.join(dir, 'episode.mp3')
      next unless File.exist?(mp3_path)

      wav_path = File.join(dir, 'episode.wav')

      next if File.exist?(wav_path)

      mp3 = FFMPEG::Movie.new(mp3_path)
      mp3.transcode(wav_path, TRANSCODING_OPTIONS)

      FileUtils.touch(File.join(dir, '.converted'), verbose: true)

      FileUtils.rm_f(mp3_path, verbose: true)
    end
  end

  task load: ['podcast:pull'] do
    xml_data = File.open(@podcast_feed)

    doc = Nokogiri::XML(xml_data, &:noblanks)

    episodes = doc.xpath('//item')

    episodes.each do |episode|
      episode_id = episode.at_css('guid').content

      episode_dir = File.join(@episodes_dir, episode_id)
      FileUtils.mkdir_p(episode_dir, verbose: true) unless Dir.exist?(episode_dir)

      next if File.exist?(File.join(episode_dir, '.converted'))
      next if File.exist?(File.join(episode_dir, '.downloaded'))
      next if File.exist?(File.join(episode_dir, '.failed'))

      episode_xml = File.open(File.join(episode_dir, 'episode.xml'), 'w')
      episode.write_xml_to(episode_xml, encoding: 'UTF-8')

      enclosure = episode.at_css('enclosure')

      next unless enclosure

      episode_url = enclosure['url']

      next unless episode_url

      episode_mp3 = File.join(episode_dir, 'episode.mp3')

      next if File.exist?(episode_mp3)

      begin
        FileUtils.touch(File.join(episode_dir, '.downloading'), verbose: true)

        progress_bar = ProgressBar.create(title: 'Episode Download', total: nil, format: '%a |%b>>%i| %p%% %t')

        content_length_proc = ->(content_length) { progress_bar.total = content_length }

        progress_proc = ->(progress) { progress_bar.progress = progress }

        # default max_redirects is 2
        max_redirects = 16

        destination = episode_mp3

        Down.download(episode_url, destination:, content_length_proc:, progress_proc:, max_redirects:)

        progress_bar.finish

        FileUtils.rm_f(File.join(episode_dir, '.downloading'), verbose: true)
        FileUtils.touch(File.join(episode_dir, '.downloaded'), verbose: true)
      rescue StandardError
        FileUtils.touch(File.join(episode_dir, '.failed'), verbose: true)

        FileUtils.rm_f(episode_mp3, verbose: true)
      end
    end
  end
end

task default: [:setup, 'podcast:pull']
