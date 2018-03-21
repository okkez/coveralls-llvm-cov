require "json"

module Coveralls
  module LLVM
    module Cov
      class Converter
        def initialize(llvm_coverage, source_encoding = Encoding::UTF_8, service_name = "travis-ci", service_job_id = nil)
          @llvm_coverage = llvm_coverage
          @source_encoding = source_encoding
          @service_name = service_name
          @service_job_id = service_job_id
        end

        def convert
          source_files = []
          llvm_cov_info = parse_llvm_coverage
          llvm_cov_info.each do |filename, info|
            source_files << generage_source_file(filename, info)
          end
          return
          payload = {
            service_name: @service_name,
            service_job_id: service_job_id,
            git: git_info,
            source_files: source_files
          }
          payload
        end

        def parse_llvm_coverage
          llvm_info = Hash.new do |h, k|
            h[k] = { "coverage" => {}, "branches" => {} }
          end
          llvm_coverage = JSON.parse(File.read(@llvm_coverage))
          llvm_coverage["data"][0]["files"].each do |entry|
            source_file, coverage, branches = parse_entry(entry)
            llvm_info[source_file]["coverage"] = coverage
            llvm_info[source_file]["branches"] = branches
          end
          []
        end

        def generage_source_file(filename, info)
          source = File.open(filename, "r:#{@source_encoding}", &:read).encode("UTF-8")
          coverage = []
          source.lines.each_with_index do |_line, index|
          end
        end

        def parse_entry(entry)
          source_file = nil
          segments = []
          expansions = []
          summary = {}
          entry.each do |key, value|
            case key
            when "filename"
              source_file = value
            when "segments"
              # line, column, count, has_count, is_region_entry
              segments = value
            when "expansions"
              expansions = value
            when "summary"
              summary = value
            else
              warn "Unknown key: #{key}"
            end
          end
          coverage, branches = parse_segments(segments)
          [source_file, coverage, branches]
        end

        def parse_segments(segments)
          segments = segments.map do |s|
            CoverageSegment.new(*s)
          end
          coverage = {}
          branches = {}
          region_entries = []
          segments.each_cons(2) do |s1, s2|
            if s1.region_entry?
              region_entries.push(s1)
            else
              region_entries.pop
            end
            previous_line = 0
            (s1.line..s2.line).each do |line|
              if region_entries.empty?
                coverage[line] = nil unless coverage.key?(line)
              else
                if previous_line == s1.line
                  coverage[line] = s1.count unless coverage[line]
                else
                  coverage[line] = s1.count unless coverage[line]
                end
              end
              previous_line = line
            end
          end
          [coverage, branches]
        end

        def git_info
          {
            head: {
              id: `git log -1 --format=%H`,
              committer_email: `git log -1 --format=%ce`,
              committer_name: `git log -1 --format=%cN`,
              author_email: `git log -1 --format=%ae`,
              author_name: `git log -1 --format=%aN`,
              message: `git log -1 --format=%s`,
            },
            remotes: [], # FIXME need this?
            branch: `git rev-parse --abbrev-ref HEAD`,
          }
        end

        def service_job_id
          ENV["TRAVIS_JOB_ID"] || @service_job_id
        end
      end

      class CoverageSegment
        attr_reader :line, :column, :count

        def initialize(line, column, count, has_count, is_region_entry, is_gap_region = false)
          @line = line
          @column = column
          @count = count
          @has_count = has_count
          @is_region_entry = is_region_entry
          @is_gap_region = is_gap_region
        end

        def count?
          @has_count == 1
        end

        def region_entry?
          @is_region_entry == 1
        end

        def gap_region?
          @is_gap_region
        end
      end
    end
  end
end


def main
  converter = Coveralls::LLVM::Cov::Converter.new("hello.json")
  converter.convert
end

main
