# Runs db/queries/settlement_totals_audit.sql and prints the results.
#
# Exists so the audit can be run against production through the same Cloud Run
# job that runs migrations — same image, same DATABASE_URL secret, nothing
# copied to a laptop:
#
#   gcloud run jobs execute fuel-loyalty-git-migrate --region=us-central1 --wait \
#     --args="exec,rails,runner,script/audit_settlement_totals.rb"
#
# Read-only: it issues SELECTs and nothing else.
QUERY_FILE = Rails.root.join("db/queries/settlement_totals_audit.sql")

TITLES = [
  "1. Stored totals that disagree with their line items (expect none)",
  "2. Settlements probably re-submitted before the fix (heuristic)",
  "3. Unique indexes preventing a recurrence (expect 6)"
].freeze

# The file is three statements separated by blank-line-and-comment blocks;
# splitting on the terminating semicolon at end-of-line keeps each one whole.
statements = QUERY_FILE.read
  .split(/;\s*$/)
  .map { |chunk| chunk.strip }
  .reject { |chunk| chunk.empty? || chunk.lines.all? { |line| line.strip.start_with?("--") || line.strip.empty? } }

statements.each_with_index do |sql, index|
  puts
  puts "=" * 78
  puts TITLES[index] || "Query #{index + 1}"
  puts "=" * 78

  rows = ActiveRecord::Base.connection.select_all(sql).to_a

  if rows.empty?
    puts "(no rows)"
    next
  end

  puts "#{rows.size} row#{'s' unless rows.size == 1}"
  rows.each do |row|
    puts
    row.each { |column, value| puts format("  %-30s %s", column, value.inspect) }
  end
end

puts
puts "Done. Query 1 returning no rows is the pass condition."
