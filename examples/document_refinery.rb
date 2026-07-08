# frozen_string_literal: true

# The Document Refinery: an HTML-to-digest pipeline where every
# stage assumes the input is hostile until proven boring - because
# it is. Real-world markup arrives with script injections, event
# handlers, javascript: hrefs, unclosed tags, and encoding damage,
# and "parse then use" is how that hostility reaches your users.
# The refinery runs sanitize -> extract -> normalize as a plan per
# document (documents in parallel), fans into one digest, and a
# referee proves nothing dangerous survived refinement.
#
#   bundle exec ruby examples/document_refinery.rb
#
# Runs offline against embedded fixtures; exits 1 if anything
# hostile leaks through. (Stdlib-only parsing here for offline
# honesty - in production you'd put Nokogiri at stage 2 and I'd
# thank you for it.)

require_relative "../lib/agentic"
require "tmpdir"

Agentic.logger.level = :fatal

FEEDS = {
  "changelog weekly" => "<html><head><title>Changelog Weekly — Issue 12</title></head>" \
    "<body><script>track(document.cookie)</script><h1>Changelog Weekly</h1>" \
    "<a href='https://changelog.example/12'>Read issue</a>" \
    "<a href='javascript:alert(1)'>totally safe link</a><p>Gems shipped this week: 41</p>",
  "ruby news" => "<html><title>Ruby News</title><body onload='pwn()'>" \
    "<p style='display:none'>SEO garbage</p><a href='/34' onclick='steal()'>Release 3.4</a>" \
    "<img src='https://tracker.example/pixel.gif' width='1'><p>Patch tuesday: 3 CVEs fixed</p>",
  "mojibake gazette" => "<html><title>Caf\xE9 Ruby, la gazette</title><body>" \
    "<p>Nouveaut\xE9s: 7 gems</p><a href='https://cafe.example/fr'>Lire</a>"
}.freeze

# --- the refinery stages, each one paranoid on purpose ------------------------------
# DECODE runs FIRST, not last: every regex downstream assumes valid
# UTF-8 and raises on damaged bytes, so encoding repair is the price
# of admission, not a finishing touch. Damage is data, not a crash -
# transcode the legacy bytes instead of moving the outage downstream.
DECODE = ->(raw) {
  utf8 = raw.dup.force_encoding(Encoding::UTF_8)
  utf8.valid_encoding? ? utf8 : raw.dup.force_encoding(Encoding::ISO_8859_1).encode(Encoding::UTF_8)
}

SANITIZE = ->(html) {
  html.gsub(%r{<script.*?</script>}mi, "")             # no executable content
    .gsub(/\son\w+\s*=\s*(['"]).*?\1/i, "")            # no event handlers
    .gsub(/href\s*=\s*(['"])\s*javascript:.*?\1/i, "href='#neutralized'")
}

EXTRACT = ->(html) {
  {title: html[%r{<title>(.*?)</title>}mi, 1].to_s.strip,
   links: html.scan(/href\s*=\s*['"]([^'"]+)['"]/i).flatten,
   text: html.gsub(%r{<[^>]*>}, " ").squeeze(" ").strip}
}

RESOLVE = ->(doc, base_url) {
  {title: doc[:title],
   links: doc[:links].map { |l| l.start_with?("/") ? base_url + l : l }.reject { |l| l == "#neutralized" },
   text: doc[:text]}
}

journal = Agentic::ExecutionJournal.new(path: File.join(Dir.tmpdir, "agentic_refinery.jsonl"))
File.delete(journal.path) if File.exist?(journal.path)
orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 3, lifecycle_hooks: journal.lifecycle_hooks)

refined_tasks = FEEDS.map do |name, raw|
  decode = Agentic::Task.new(description: "decode: #{name}", agent_spec: {"name" => "d", "instructions" => "w"}, payload: raw)
  sanitize = Agentic::Task.new(description: "sanitize: #{name}", agent_spec: {"name" => "s", "instructions" => "w"})
  extract = Agentic::Task.new(description: "extract: #{name}", agent_spec: {"name" => "e", "instructions" => "w"})
  resolve = Agentic::Task.new(description: "resolve: #{name}", agent_spec: {"name" => "r", "instructions" => "w"})
  orchestrator.add_task(decode, agent: ->(t) { DECODE.call(t.payload) })
  orchestrator.add_task(sanitize, [decode], agent: ->(t) { SANITIZE.call(t.previous_output) })
  orchestrator.add_task(extract, [sanitize], agent: ->(t) { EXTRACT.call(t.previous_output) })
  orchestrator.add_task(resolve, [extract], agent: ->(t) { RESOLVE.call(t.previous_output, "https://#{name.delete(" ")}.example") })
  resolve
end

digest = Agentic::Task.new(description: "digest", agent_spec: {"name" => "d", "instructions" => "w"})
orchestrator.add_task(digest, refined_tasks, agent: ->(t) {
  refined_tasks.map { |rt| t.output_of(rt) }.map { |d| "#{d[:title]} (#{d[:links].size} links) - #{d[:text][0, 40]}" }
})

result = orchestrator.execute_plan
entries = result.task_result(digest.id).output

puts "THE DOCUMENT REFINERY (all input is hostile until proven boring)"
puts
puts "  refined #{FEEDS.size} feeds in parallel:"
entries.each { |e| puts "    - #{e}" }
puts

# --- the referee: prove the hostility died in the refinery --------------------------
outputs = refined_tasks.map { |rt| result.task_result(rt.id).output }
violations = []
outputs.each do |doc|
  blob = [doc[:title], doc[:text], *doc[:links]].join(" ")
  violations << "script content survived" if blob.match?(/track\(|pwn\(|steal\(|<script/i)
  violations << "javascript: href survived" if doc[:links].any? { |l| l.start_with?("javascript:") }
  violations << "invalid encoding in output" unless blob.valid_encoding? && blob.encoding == Encoding::UTF_8
  violations << "relative link escaped unresolved" if doc[:links].any? { |l| l.start_with?("/") }
end
violations << "a feed went missing from the digest" unless entries.size == FEEDS.size

puts "  referee: #{violations.empty? ? "no script bodies, no javascript: hrefs, no event handlers," : violations.uniq.join("; ")}"
puts "           all output valid UTF-8, relative links resolved, #{entries.size}/#{FEEDS.size} feeds present" if violations.empty?
puts
puts "  the pipeline shape is the security model: DECODE first (the gazette"
puts "  arrived as latin-1 bytes wearing a UTF-8 flag, and every regex"
puts "  downstream raises on damaged bytes - encoding repair is the price"
puts "  of admission, not a finishing touch); sanitize BEFORE extract (so"
puts "  extraction can't be fooled by what it finds); resolve links last;"
puts "  and a referee that greps the refined product for everything the"
puts "  fixtures smuggled in. the first draft ran encoding repair LAST and"
puts "  the plan itself refused: sanitize crashed on the gazette. the"
puts "  pipeline knew more about encoding order than its author did."
exit(violations.empty? ? 0 : 1)
