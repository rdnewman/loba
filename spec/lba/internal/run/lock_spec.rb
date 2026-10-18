RSpec.describe Lba::Internal::Run::Lock do
  # Holds the lock on another thread until the returned release is called.
  def hold_on_another_thread(lock)
    held = Queue.new
    release = Queue.new
    holder = Thread.new do
      lock.synchronize do
        held << true
        release.pop
      end
    end
    held.pop

    lambda do
      release << true
      holder.join
    end
  end

  # Runs the block in a signal handler, where Ruby forbids waiting for a lock,
  # and returns what it returned or raised.
  def in_signal_handler
    outcome = nil
    previous_handler = Signal.trap("USR1") do
      outcome = begin
        [:returned, yield]
      rescue StandardError => e
        [:raised, e]
      end
    end
    Process.kill("USR1", Process.pid)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2
    sleep 0.001 until outcome || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
    outcome
  ensure
    Signal.trap("USR1", previous_handler)
  end

  describe "#synchronize" do
    it "returns the block's value" do
      lock = described_class.new

      result = lock.synchronize { :done }

      expect(result).to eq(:done)
    end

    it "keeps another thread waiting until the holder releases it", :aggregate_failures do
      lock = described_class.new
      release = hold_on_another_thread(lock)
      entered = Queue.new
      waiter = Thread.new { lock.synchronize { entered << true } }

      waited = waiter.join(0.05).nil?
      release.call
      waiter.join

      expect(waited).to be true
      expect(entered.size).to eq(1)
    end

    it "lets the thread holding it take it again" do
      lock = described_class.new

      result = lock.synchronize { lock.synchronize { :inner } }

      expect(result).to eq(:inner)
    end

    it "releases it when the block raises" do
      lock = described_class.new
      begin
        lock.synchronize { raise ArgumentError }
      rescue ArgumentError
        nil
      end

      other_thread = Thread.new { lock.synchronize { :taken } }

      expect(other_thread.join(1)&.value).to eq(:taken)
    end

    it "lets a ThreadError raised by the block through" do
      lock = described_class.new

      expect { lock.synchronize { raise ThreadError, "from the block" } }
        .to raise_error(ThreadError, "from the block")
    end

    context "when called in a signal handler" do
      it "runs the block holding the lock when it's free" do
        lock = described_class.new
        other_thread = nil

        outcome = in_signal_handler do
          lock.synchronize do
            other_thread = Thread.new { lock.synchronize { :taken } }
            other_thread.join(0.05).nil?
          end
        end
        other_thread.join

        expect(outcome).to eq([:returned, true])
      end

      it "runs the block when the interrupted thread holds the lock" do
        lock = described_class.new

        outcome = lock.synchronize { in_signal_handler { lock.synchronize { :ran } } }

        expect(outcome).to eq([:returned, :ran])
      end

      it "runs the block without the lock when another thread holds it" do
        lock = described_class.new
        release = hold_on_another_thread(lock)

        outcome = in_signal_handler { lock.synchronize { :ran } }
        release.call

        expect(outcome).to eq([:returned, :ran])
      end
    end
  end
end
