require "fileutils"
require "stringio"

RSpec.describe Lba::Internal::Writer do
  let(:tmp_dir) { Dir.mktmpdir }

  after { FileUtils.remove_entry(tmp_dir) }

  describe ".write" do
    it "appends the record as one JSON line, adding a trailing newline" do
      sink = StringIO.new

      described_class.write({ "type" => "val", "label" => "foo" }, sink:)

      expect(sink.string).to eq(%({"type":"val","label":"foo"}\n))
    end

    it "flushes an IO sink after writing so a follower sees the record immediately" do
      sink = instance_double(IO, write: nil, flush: nil)

      described_class.write({ "type" => "ts" }, sink:)

      expect(sink).to have_received(:flush).once
    end

    it "appends to a path sink without truncating existing content" do
      path = File.join(tmp_dir, "sink.jsonl")
      File.write(path, %({"seq":1}\n))

      described_class.write({ "seq" => 2 }, sink: path)

      expect(File.read(path)).to eq(%({"seq":1}\n{"seq":2}\n))
    end
  end
end
