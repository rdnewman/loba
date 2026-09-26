require "json"

module ForkHelpers
  # Runs the block in a forked child and returns its result through JSON:
  # hash keys come back as symbols, symbol values as strings. Put
  # expectations in the parent. A child error is re-raised there.
  def in_forked_child(&)
    reader, writer = IO.pipe

    child_pid = fork do
      reader.close
      report_to_parent(writer, &)
    end

    writer.close

    outcome = JSON.parse(reader.read, symbolize_names: true)
    Process.wait(child_pid)

    if outcome[:error]
      raise "forked child failed -- #{outcome[:error]}"
    end

    outcome[:value]
  end

private

  # Rescues Exception because RSpec's expectation failures aren't
  # StandardErrors; an escape would leave the parent an empty pipe. exit!
  # skips at_exit hooks, so the child doesn't run RSpec's and SimpleCov's
  # shutdown as if it were the parent.
  def report_to_parent(writer)
    payload =
      begin
        JSON.generate({ value: yield })
      rescue Exception => e # rubocop:disable Lint/RescueException -- see above
        JSON.generate({ error: "#{e.class}: #{e.message}" })
      end
    writer.write(payload)
  ensure
    writer.close
    exit!(0)
  end
end
