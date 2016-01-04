module CompactIndex
  GemVersion = Struct.new(:number, :platform, :checksum, :info_checksum,
                          :dependencies, :ruby_version, :rubygems_version) do
    def number_and_platform
      if platform.nil? || platform == "ruby"
        number.dup
      else
        "#{number}-#{platform}"
      end
    end

    def <=>(other)
      number_comp = number <=> other.number

      if number_comp.zero?
        [number, platform] <=> [other.number, other.platform]
      else
        number_comp
      end
    end

    def to_line
      line = number_and_platform << " " << deps_line << "|checksum:#{checksum}"
      line << ",ruby:#{ruby_version}" if ruby_version && ruby_version != ">= 0"
      line << ",rubygems:#{rubygems_version}" if rubygems_version && rubygems_version != ">= 0"
      line
    end

  private

    def deps_line
      return "" if dependencies.nil?
      dependencies.map do |d|
        [d[:gem], d.version_and_platform.split(", ").sort.join("&")].join(":")
      end.join(",")
    end

  end
end
