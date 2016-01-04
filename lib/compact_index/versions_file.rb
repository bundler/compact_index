require 'time'
require 'date'
require 'compact_index'

class CompactIndex::VersionsFile
  def initialize(file = nil)
    @path = file || "/versions.list"
  end

  def contents(gems = nil, args = {})
    if args[:calculate_checksums]
      gems = calculate_checksums(gems)
    end

    out = File.read(@path)
    out << parse_gems(gems) if gems
    out
  end

  def updated_at
    created_at_header(@path) || Time.at(0).to_datetime
  end

  def update_with(gems)
    if File.exists?(@path) && !File.zero?(@path)
      update(gems)
    else
      create(gems)
    end
  end


  private


  def create(gems)
    content = "\Acreated_at: #{Time.now.iso8601}"
    content << "\n---\n"
    content << parse_gems_for_create(gems)

    File.open(@path, 'w') do |io|
      io.write content
    end
  end

  def update(gems)
    File.open(@path, 'a') do |io|
      io.write parse_gems(gems)
    end
  end

  def parse_gems_for_create(gems)
    # Join all versions for each gem in one hash
    gems_hash = {}
    gems.each do |entry|
      gems_hash[entry[:name]] ||= []
      gems_hash[entry[:name]] += entry[:versions]
    end

    # Transform hash in a list of line informations to be printed
    gems = gems_hash.map do |gem, versions|
      { :name => gem, :versions => versions, :checksum => versions.first[:info_checksum] }
    end

    # Sort gems by name and versions by number
    gems.sort! { |a,b| a[:name] <=> b[:name] }
    gems.each do |entry|
      entry[:versions].sort! do |a,b|
        Gem::Version.create(a[:number]) <=> Gem::Version.create(b[:number])
      end
    end

    gem_lines(gems)
  end

  def parse_gems(gems)
    gem_lines = gems.map do |entry|
      {
        :name => entry[:name],
        :versions => entry[:versions],
        :checksum => entry[:versions].first[:info_checksum]
      }
    end
    gem_lines(gem_lines)
  end

  def gem_lines(gems)
    gems.reduce("") do |concat, entry|
      versions = entry[:versions]
      concat << "#{entry[:name]} #{versions.map(&:number_and_platform).join(',')} #{entry[:checksum]}\n"
    end
  end

  def calculate_checksums(gems)
    gems.each do |gem|
      info_checksum = Digest::MD5.hexdigest(CompactIndex.info(gem[:versions]))
      gem[:versions].last[:info_checksum] = info_checksum
    end
  end

  def created_at_header(path)
    return unless File.exists? path

    File.open(path) do |file|
      file.each_line do |line|
        line.match(/created_at: (.*)\n|---\n/) do |match|
          return match[1] && DateTime.parse(match[1])
        end
      end
    end

    nil
  end

end
