# frozen_string_literal: true

# The Journal Tail Pager: production journals grow like production
# tables, and the question asked of both is always the same one -
# "what happened RECENTLY?" Answering it by replaying the whole file
# is SELECT * wearing a filesystem costume. This pager reads pages
# from the END, backwards, in fixed-size chunks: page 1 costs
# kilobytes no matter how many megabytes the journal holds.
#
#   bundle exec ruby examples/journal_tail.rb
#
# Runs offline; a 20,000-event journal is built, then barely read.

require_relative "../lib/agentic"
require "tmpdir"
require "json"

# Kaminari's lesson, ported: a page knows its items AND how to reach
# the one before it (the cursor is a byte offset, not a page number -
# offsets don't shift when new events append)
class JournalTailPager
  CHUNK = 16 * 1024

  Page = Struct.new(:events, :prev_cursor, :bytes_read, keyword_init: true)

  def initialize(path)
    @path = path
  end

  def last_page(per: 50) = page_before(File.size(@path), per: per)

  def page_before(cursor, per: 50)
    lines = []
    bytes_read = 0
    position = cursor
    buffer = +""

    while position.positive? && lines.size <= per
      step = [CHUNK, position].min
      position -= step
      chunk = File.open(@path, "rb") { |f|
        f.seek(position)
        f.read(step)
      }
      bytes_read += step
      buffer = chunk + buffer
      lines = buffer.split("\n", -1)
    end

    # First fragment may be a partial line unless we hit file start
    complete = position.zero? ? lines : lines.drop(1)
    complete = complete.reject(&:empty?)
    page_lines = complete.last(per)
    consumed = page_lines.sum(&:bytesize) + page_lines.size
    events = page_lines.filter_map do |l|
      JSON.parse(l, symbolize_names: true)
    rescue JSON::ParserError
      nil
    end
    Page.new(events: events, prev_cursor: cursor - consumed, bytes_read: bytes_read)
  end
end

# --- build a big journal ---------------------------------------------------------
path = File.join(Dir.tmpdir, "agentic_tail.journal.jsonl")
File.delete(path) if File.exist?(path)
journal = Agentic::ExecutionJournal.new(path: path, fsync_every: 500)
20_000.times do |i|
  journal.record(:task_succeeded, task_id: "t#{i}", description: "job:#{i % 40}", duration: 0.01, output: nil)
end
journal.sync
total_size = File.size(path)

puts "THE JOURNAL TAIL PAGER (#{total_size / 1024}KB journal, 20,000 events)"
puts

pager = JournalTailPager.new(path)
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
page = pager.last_page(per: 50)
page_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000

started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
Agentic::ExecutionJournal.replay(path: path)
full_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000

puts format("  last page (50 events):  %6.1fms, %5dKB read  (%s .. %s)",
  page_ms, page.bytes_read / 1024, page.events.first[:task_id], page.events.last[:task_id])
puts format("  full replay (control):  %6.1fms, %5dKB read", full_ms, total_size / 1024)
puts

# Walk two more pages backwards - the cursor is a byte offset
page2 = pager.page_before(page.prev_cursor, per: 50)
page3 = pager.page_before(page2.prev_cursor, per: 50)
puts "  paging backwards through history:"
[page, page2, page3].each_with_index do |p, i|
  puts format("    page %d: %s .. %s  (%d events)", i + 1, p.events.first[:task_id], p.events.last[:task_id], p.events.size)
end
puts
puts format("  the arithmetic: page 1 cost %dKB of a %dKB file (%.1f%%) and", page.bytes_read / 1024, total_size / 1024, page.bytes_read * 100.0 / total_size)
puts format("  ran %.0fx faster than full replay. the cursor is a BYTE OFFSET,", full_ms / page_ms)
puts "  not a page number - kaminari taught everyone what OFFSET 19950"
puts "  costs on a growing table, and the same lesson holds for growing"
puts "  files: numbered pages shift when rows append; cursors don't."
puts "  full replay remains the right tool for RESUME (you need all"
puts "  completions); the pager is the right tool for LOOKING (the"
puts "  incident was ten minutes ago, not ten thousand events ago)."
