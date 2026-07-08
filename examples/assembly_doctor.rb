# frozen_string_literal: true

# The Assembly Doctor: syntax_suggest for plans. When a 12-step plan
# won't assemble, "KeyError: task not found" is technically true the
# way "syntax error, unexpected end" is technically true - it names
# the symptom and hides the street address. The doctor examines a
# broken plan spec the way syntax_suggest examines a broken file:
# find the smallest region that explains the failure, SHOW it with
# an arrow pointing at the problem, and suggest the one-keystroke
# fix when the framework can see it. Error messages are the UI of
# failure, and failure is most of programming.
#
#   bundle exec ruby examples/assembly_doctor.rb
#
# Runs offline; diagnoses two classic assembly wounds, then proves
# the repaired plan actually runs.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

# A deploy pipeline, written by a human at 5pm: one typo'd dependency
# name, and one cycle added during a hasty refactor
PLAN = [
  {step: "checkout code"},
  {step: "install deps", after: ["checkout code"]},
  {step: "compile assets", after: ["install deps"]},
  {step: "fetch metadata", after: ["checkout code"]},
  {step: "upload assets", after: ["compile assets", "fetch metdata"]}, # <- 5pm
  {step: "run migrations", after: ["install deps", "verify health"]},  # <- the refactor
  {step: "restart app", after: ["run migrations", "upload assets"]},
  {step: "verify health", after: ["restart app"]}
].freeze

# --- the doctor -------------------------------------------------------------------
def diagnose(plan)
  names = plan.map { |s| s[:step] }
  findings = []

  # Wound 1: dependencies that name no step (with the framework's own
  # did-you-mean pass - the plan is holding the list of valid names)
  plan.each_with_index do |step, i|
    Array(step[:after]).each do |dep|
      next if names.include?(dep)
      findings << {kind: "unmatched dependency", snippet: [i, dep],
                   hint: Agentic::Suggestions.hint(dep, names)}
    end
  end

  # Wound 2: cycles - shown as the LOOP itself, not as a deadlocked
  # hang. Depth-first search finds a member; walking dependencies that
  # still reach the origin reconstructs the loop for display
  deps_of = ->(name) { Array(plan.find { |s| s[:step] == name }&.dig(:after)) }
  reaches = ->(from, target, seen) {
    return false if seen.include?(from)
    deps_of.call(from).include?(target) ||
      deps_of.call(from).any? { |d| reaches.call(d, target, seen + [from]) }
  }
  cycle_member = names.find { |n| reaches.call(n, n, []) }
  if cycle_member
    loop_path = [cycle_member]
    until loop_path.size > 1 && loop_path.last == cycle_member
      loop_path << deps_of.call(loop_path.last).find { |d| d == cycle_member || reaches.call(d, cycle_member, []) }
    end
    findings << {kind: "dependency cycle", snippet: loop_path}
  end

  findings
end

def print_diagnosis(plan, findings)
  findings.each do |f|
    case f[:kind]
    when "unmatched dependency"
      i, dep = f[:snippet]
      line = "    >  #{i + 1}  #{plan[i][:step].inspect}  after: #{dep.inspect}"
      puts "  Unmatched dependency, in step #{i + 1}:"
      puts "       #{i}  #{plan[i - 1][:step].inspect}"
      puts line
      puts "#{" " * line.index(dep.inspect)}#{"^" * dep.inspect.size} no step has this name#{f[:hint]}"
    when "dependency cycle"
      puts "  Dependency cycle - the plan can never start:"
      puts "    >  #{f[:snippet].join(" -> ")}"
      puts "       every member of the loop waits for another member. one of"
      puts "       these edges is aspirational, not structural - probably the"
      puts "       newest one."
    end
    puts
  end
end

puts "THE ASSEMBLY DOCTOR (error messages are the UI of failure)"
puts
findings = diagnose(PLAN)
puts "  examining the 5pm deploy plan (#{PLAN.size} steps): #{findings.size} wounds found"
puts
print_diagnosis(PLAN, findings)

# --- the repaired plan must actually run - doctors get audited too -----------------
fixed = PLAN.map { |s| {step: s[:step], after: Array(s[:after]).map { |d| (d == "fetch metdata") ? "fetch metadata" : d } - ["verify health"]} }
fixed[5][:after] = ["install deps"] # run migrations no longer waits on verify health
abort("  doctor still sees wounds in the fixed plan!") unless diagnose(fixed).empty?

orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 4)
tasks = {}
fixed.each do |s|
  tasks[s[:step]] = Agentic::Task.new(description: s[:step], agent_spec: {"name" => s[:step], "instructions" => "go"})
  orchestrator.add_task(tasks[s[:step]], s[:after].map { |d| tasks.fetch(d) }, agent: ->(_t) { "ok" })
end
result = orchestrator.execute_plan

puts "  after the two one-line fixes: doctor finds nothing; plan runs: #{result.status}"
puts
puts "  the doctor's rules are syntax_suggest's rules, one abstraction up:"
puts "  don't report the symptom's location, report the SMALLEST REGION"
puts "  that explains it (the typo'd edge, the whole loop); show the code,"
puts "  not a stack trace; and when the system is holding the list of"
puts "  valid names - it always is - spend one Levenshtein pass to turn"
puts "  the diagnosis into a one-keystroke fix. the framework's own"
puts "  Suggestions module supplied the did-you-mean. people don't quit"
puts "  because programming is hard; they quit because failure is rude."
exit((findings.size == 2 && result.status == :completed) ? 0 : 1)
