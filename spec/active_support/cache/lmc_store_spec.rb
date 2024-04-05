require 'spec_helper'
require 'lmc-store'
require 'securerandom'

describe ActiveSupport::Cache::LmcStore do
  describe 'caching' do
    subject { described_class.new }
    before { subject.clear }

    describe 'read/write/delete' do
      context 'when cache is empty' do
        it '#read returns nil' do
          expect(subject.read('foo')).to be_nil
        end

        it '#write returns true' do
          expect(subject.write('foo', '1337')).to be true
        end

        it '#delete returns false' do
          expect(subject.delete('foo')).to be false
        end
      end

      context 'when cache is not empty' do
        before do
          subject.write('foo', '1337')
        end

        it '#read returns cached value' do
          expect(subject.read('foo')).to eq('1337')
        end

        it '#write returns true' do
          expect(subject.write('foo', '1338')).to be true
        end

        it '#delete returns true' do
          expect(subject.delete('foo')).to be true
        end
      end

      it 'caches structured values' do
        data = { foo: 12.34, bar: 56, qux: nil }
        subject.write('foo', data)
        expect(subject.read('foo')).to eq(data)
      end
    end

    describe '#fetch' do
      it 'persists values' do
        subject.fetch('foo') { '1337' }
        result = subject.fetch('foo') { '1338' }
        expect(result).to eq '1337'
      end

      it 'is lazy' do
        generator = double('value')
        allow(generator).to receive(:value).once

        2.times do
          subject.fetch('foo') { generator.value }
        end
      end
    end
  end

  describe 'eviction' do
    def blob(size_mb)
      SecureRandom.random_bytes(size_mb.megabytes)
    end

    subject { described_class.new(size: 16.megabytes) }
    before { subject.clear }

    it 'evicts items' do
      expect(subject).to receive(:prune).at_least(1).and_call_original

      16.times do |index|
        subject.write(index.to_s, blob(1))
      end
    end
  end

  describe 'persistence' do
    subject { described_class.new }

    before do
      fork do
        subject.clear
        subject.write 'foo', 'bar'
        exit 0
      end
      Process.wait
    end

    it 'can read on-disk data' do
      expect(subject.read('foo')).to eq 'bar'
    end
  end

  describe 'concurrency' do
    def cache_factory
      described_class.new
    end

    it 'in the same thread' do
      cache1 = cache_factory
      cache2 = cache_factory

      cache1.write('foo', 'bar1')
      cache2.write('foo', 'bar2')

      expect(cache1.read('foo')).to eq 'bar2'
    end

    it 'across multiple processes' do
      cache_factory.clear

      (0..4).each do |process_index|
        fork do
          cache = cache_factory
          (0..99).each do |index|
            cache.write((index * 5 + process_index).to_s, "cache#{process_index}")
          end
          exit 0
        end
      end

      Process.wait

      cache = cache_factory
      (0..499).each do |index|
        expect(cache.read(index.to_s)).to match /cache\d/
      end
    end
  end

end