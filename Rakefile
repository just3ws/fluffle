# frozen_string_literal: true

require 'amazing_print'
require 'curb'
require 'down'
require 'fileutils'
require 'net/ssh'
require 'nokogiri'
require 'pathname'
require 'rake'
require 'ruby-progressbar'
require 'streamio-ffmpeg'
require 'time'

ROOT_DIR = File.join(Dir.home, 'podcasts')

LOCAL_DIR = '~/podcasts/dead-rabbit-radio/episodes'
REMOTE_DIR = '~/podcasts/dead-rabbit-radio/episodes'
NODES = %w[node01 node02 node03 node04 node05].freeze
SSH_USER = 'deploy'
MAX_PODCAST_GB_PER_NODE = 2
MIN_MB_AVAILABLE_ON_NODE = 5_000

# Conversion constants
BYTES_IN_GB = (1024 * 1024 * 1024).to_f

PODCASTS = {
  'dead-rabbit-radio' => 'https://feeds.libsyn.com/140084/rss',
  'belief-hole' => 'https://feeds.libsyn.com/112657/rss',
  'philosophize-this' => 'https://feeds.libsyn.com/44756/rss'
}.freeze

TRANSCODING_OPTIONS = {
  audio_codec: 'pcm_s16le',
  audio_sample_rate: 16_000,
  audio_channels: 1
}.freeze

task :environment do
  @podcast_name = ENV['PODCAST'].to_s
  @podcast_url = PODCASTS[@podcast_name]

  @working_dir = File.join(File.expand_path(ROOT_DIR), @podcast_name)
  FileUtils.mkdir_p(@working_dir, verbose: true)

  @episodes_dir = File.join(@working_dir, 'episodes')
  FileUtils.mkdir_p(@episodes_dir, verbose: true)

  # @transcriptions_dir = File.join(@working_dir, 'transcriptions')
  # @tmp_dir = File.join(@working_dir, 'tmp')

  @podcast_feed = File.join(@working_dir, 'feed.xml')
  @force = ENV['FORCE'].to_s == '1'
  @keep = ENV['KEEP'].to_s == '1'

  ap ['environment', @podcast_name, @podcast_url, @working_dir], multiline: false
end

task setup: :environment do
  FileUtils.mkdir_p(@episodes_dir, verbose: true)
  # FileUtils.mkdir_p(@transcriptions_dir, verbose: true)
  # FileUtils.mkdir_p(@tmp_dir, verbose: true)
end

namespace :podcasts do
  task pull: :environment do
    FileUtils.rm_f(@podcast_feed, verbose: true) if @force

    unless File.exist?(@podcast_feed)
      curl = Curl::Easy.new(@podcast_url)
      curl.verbose = true
      curl.perform

      xml_data = curl.body_str

      File.write(@podcast_feed, xml_data)
    end

    abort('Podcast feed not pulled') unless File.exist?(@podcast_feed)
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

      FileUtils.rm_f(mp3_path, verbose: true) unless @keep
    end
  end

  task load: ['podcasts:pull'] do
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

  desc 'Distribute podcast files'
  task distribute: :environment do
    Dir.chdir(@episodes_dir)

    attempts = 10

    Dir.children('.').each do |episode_dir|
      attempts -= 1
      abort('Exhausted distribution attempts') if attempts.negative?

      wav_file_path = File.join(episode_dir, 'episode.wav')
      next unless File.exist?(wav_file_path)

      local_file_size = File.size(wav_file_path)
      ap [local_file_size:], multiline: false

      converted_file_path = File.join(episode_dir, '.converted')
      next unless File.exist?(converted_file_path)

      distributed_file_path = File.join(episode_dir, '.distributed')
      next if File.exist?(distributed_file_path)

      NODES.each do |node|
        puts "Trying #{node}"
        remote_episode_dir = "/home/deploy/podcasts/#{@podcast_name}/episodes/#{Pathname.new(episode_dir).basename}"

        Net::SSH.start(node, SSH_USER) do |ssh|
          ssh.exec!("mkdir -p #{remote_episode_dir}")

          available_mb_on_node = ssh.exec!("df --output=avail -BM / | tail -n 1 | tr -d '[:space:]' | tr -d 'M'").to_i

          ap [available_mb_on_node:], multiline: false
          next if available_mb_on_node <= MIN_MB_AVAILABLE_ON_NODE

          # podcast_gb_on_node = `ssh #{SSH_USER}@#{node} du -sb /home/deploy/podcasts/#{@podcast_name}/episodes`.split.first.to_f / BYTES_IN_GB
          podcast_gb_on_node = ssh.exec!("du -sb /home/deploy/podcasts/#{@podcast_name}/episodes").split.first.to_f / BYTES_IN_GB
          ap [podcast_gb_on_node:], multiline: false
          next if podcast_gb_on_node >= MAX_PODCAST_GB_PER_NODE

          system("rsync -avzP #{wav_file_path} #{SSH_USER}@#{node}:#{remote_episode_dir}")
          attempts += 1 if attempts < 10

          ap "#{remote_episode_dir}/episode.wav", multiline: false
          remote_file_size = ssh.exec!("du -b #{remote_episode_dir}/episode.wav").split.first.to_i
          ap [remote_file_size:], multiline: false

          if remote_file_size == local_file_size
            FileUtils.touch(distributed_file_path, verbose: true)
            break
          end

          abort("Episode upload failed for #{wav_file_path} to #{node}")
        end
      end
    end
  end
end

task default: [:setup, 'podcast:pull']
