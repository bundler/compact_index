require 'tempfile'
require 'spec_helper'
require 'compact_index/versions_file'
require 'support/versions'
require 'support/versions_file'

describe CompactIndex::VersionsFile do
  before :all do
    @file_contents = "gem1 1.1,1.2\ngem2 2.1,2.1-jruby\n"
    @file = Tempfile.new('versions.list')
    @file.write @file_contents
    @file.rewind
  end

  after :all do
    @file.unlink
  end

  let(:versions_file) do
    CompactIndex::VersionsFile.new(@file.path)
  end

  let(:gem_time) { Time.now }

  context "using the file" do
    let(:file) { Tempfile.new("create_versions.list") }
    let(:gems) do
        [
          CompactIndex::Gem.new("gem5", [
            build_version(:number => "1.0.1")
          ]),
          CompactIndex::Gem.new("gem2", [
            build_version(:number => "1.0.1"),
            build_version(:number => "1.0.2", :platform => 'arch')
          ])
        ]
    end
    let(:versions_file) { versions_file = CompactIndex::VersionsFile.new(file.path) }


    describe "#create" do
      it "writes one line per gem" do
        expected_file_output = /created_at: .*?\n---\ngem2 1.0.1,1.0.2-arch abc123102\ngem5 1.0.1 abc123101\n/
        versions_file.create(gems)
        expect(file.open.read).to match(expected_file_output)
      end

      it "adds the date on top" do
        date_regexp = /\Acreated_at: (.*?)\n/
        versions_file.create(gems)
        file.open.read.match(date_regexp) do |m|
          expect(m[0]).to match(
            /(\d{4})-(\d{2})-(\d{2})T(\d{2})\:(\d{2})\:(\d{2})[+-](\d{2})\:(\d{2})/
          )
        end
      end

      it "orders gems by name" do
        file = Tempfile.new('versions-sort')
        versions_file = CompactIndex::VersionsFile.new(file.path)
        gems = [
          CompactIndex::Gem.new("gem_b", [build_version]),
          CompactIndex::Gem.new("gem_a", [build_version])
        ]
        versions_file.create(gems)
        expect(file.open.read).to match(/gem_a 1.0 abc12310\ngem_b 1.0/)
      end

      it "orders versions by number" do
        file = Tempfile.new('versions-sort')
        versions_file = CompactIndex::VersionsFile.new(file.path)
        gems = [
          CompactIndex::Gem.new('test', [
            build_version(:number => "2.2"),
            build_version(:number => "1.1.1"),
            build_version(:number => "1.1.1"),
            build_version(:number => "2.1.2")
          ])
        ]
        versions_file.create(gems)
        expect(file.open.read).to match(/test 1.1.1,1.1.1,2.1.2,2.2 abc12322/)
      end
    end
  end

  describe "#updated_at" do
    it "is epoch start when file does not exist" do
      expect(CompactIndex::VersionsFile.new("/tmp/doesntexist").updated_at).to eq(Time.at(0).to_datetime)
    end

    it "is epoch when created_at header does not exist" do
      expect(versions_file.updated_at).to eq(Time.at(0).to_datetime)
    end

    it "is the created_at time when the header exists" do
      Tempfile.new("created_at_versions") do |tmp|
        tmp.write("created_at: 2015-08-23T17:22:53-07:00\n---\ngem2 1.0.1\n")
        file = CompactIndex::VersionsFile.new(tmp.path).updated_at
        expect(file.updated_at).to eq(DateTime.parse("2015-08-23T17:22:53-07:00"))
      end
    end
  end

  describe "#contents" do
    it "return the file" do
      expect(versions_file.contents).to eq(@file_contents)
    end

    it "includes extra gems if given" do
      extra_gems = [
        CompactIndex::Gem.new("gem3", [
          build_version(:number => "1.0.1"),
          build_version(:number => "1.0.2", :platform => 'arch')
        ])
      ]
      expect(
        versions_file.contents(extra_gems)
      ).to eq(
        @file_contents + "gem3 1.0.1,1.0.2-arch abc123102\n"
      )
    end

    it "has checksum" do
      gems = [
        CompactIndex::Gem.new('test', [
          build_version(:info_checksum => 'testsum', :number => '1.0')
        ])
      ]
      expect(
        versions_file.contents(gems)
      ).to match(
        /test 1.0 testsum/
      )
    end

    it "has the platform" do
      gems = [
        CompactIndex::Gem.new('test', [
          build_version(:number => '1.0', :platform => 'jruby')
        ])
      ]
      expect(
        versions_file.contents(gems)
      ).to match(
        /test 1.0-jruby abc123/
      )
    end

    describe "with calculate_info_checksums flag" do
      let(:gems) {[
        CompactIndex::Gem.new('test', [
          build_version(:number => '1.0', :platform => 'ruby', :dependencies => [
            CompactIndex::Dependency.new('foo', '=1.0.1', 'ruby', 'abc123')
          ])
        ])
      ]}

      it "calculates the info_checksums on the fly" do
        expect(
          versions_file.contents(gems, :calculate_checksums => true)
        ).to match(
          /test 1.0 a6beccb34e26aa9e082bda0d8fa4ee77/
        )
      end
    end
  end
end
