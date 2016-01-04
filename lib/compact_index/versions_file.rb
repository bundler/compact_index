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

    File.read(@path).tap do |out|
      out << gem_lines(gems) if gems
    end
  end

  def updated_at
    created_at_header(@path) || Time.at(0).to_datetime
  end

  def create(gems)
    gems.sort!

    File.open(@path, 'w') do |io|
      io.write "created_at: #{Time.now.iso8601}\n---\n"
      io.write gem_lines(gems)
    end
  end

private

  def gem_lines(gems)
    gems.each {|g| g.versions.sort! }

    gems.reduce("") do |lines, gem|
      version_numbers = gem.versions.map(&:number_and_platform).join(',')
      lines << gem.name <<
        " ".freeze << version_numbers <<
        " #{gem.versions.last.info_checksum}\n"
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
