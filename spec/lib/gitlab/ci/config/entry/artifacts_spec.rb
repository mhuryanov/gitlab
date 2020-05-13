# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Ci::Config::Entry::Artifacts do
  let(:entry) { described_class.new(config) }

  describe 'validation' do
    context 'when entry config value is correct' do
      let(:config) { { paths: %w[public/] } }

      describe '#value' do
        it 'returns artifacts configuration' do
          expect(entry.value).to eq config
        end
      end

      describe '#valid?' do
        it 'is valid' do
          expect(entry).to be_valid
        end
      end

      context "when value includes 'reports' keyword" do
        let(:config) { { paths: %w[public/], reports: { junit: 'junit.xml' } } }

        it 'returns general artifact and report-type artifacts configuration' do
          expect(entry.value).to eq config
        end
      end

      context "when value includes 'expose_as' keyword" do
        let(:config) { { paths: %w[results.txt], expose_as: "Test results" } }

        it 'returns general artifact and report-type artifacts configuration' do
          expect(entry.value).to eq config
        end
      end
    end

    context 'when entry value is not correct' do
      describe '#errors' do
        context 'when value of attribute is invalid' do
          let(:config) { { name: 10 } }

          it 'reports error' do
            expect(entry.errors)
              .to include 'artifacts name should be a string'
          end
        end

        context 'when there is an unknown key present' do
          let(:config) { { test: 100 } }

          it 'reports error' do
            expect(entry.errors)
              .to include 'artifacts config contains unknown keys: test'
          end
        end

        context "when 'reports' keyword is not hash" do
          let(:config) { { paths: %w[public/], reports: 'junit.xml' } }

          it 'reports error' do
            expect(entry.errors)
              .to include 'artifacts reports should be a hash'
          end
        end

        context "when 'expose_as' is not a string" do
          let(:config) { { paths: %w[results.txt], expose_as: 1 } }

          it 'reports error' do
            expect(entry.errors)
              .to include 'artifacts expose as should be a string'
          end
        end

        context "when 'expose_as' is too long" do
          let(:config) { { paths: %w[results.txt], expose_as: 'A' * 101 } }

          it 'reports error' do
            expect(entry.errors)
              .to include 'artifacts expose as is too long (maximum is 100 characters)'
          end
        end

        context "when 'expose_as' is an empty string" do
          let(:config) { { paths: %w[results.txt], expose_as: '' } }

          it 'reports error' do
            expect(entry.errors)
              .to include 'artifacts expose as ' + Gitlab::Ci::Config::Entry::Artifacts::EXPOSE_AS_ERROR_MESSAGE
          end
        end

        context "when 'expose_as' contains invalid characters" do
          let(:config) do
            { paths: %w[results.txt], expose_as: '<script>alert("xss");</script>' }
          end

          it 'reports error' do
            expect(entry.errors)
              .to include 'artifacts expose as ' + Gitlab::Ci::Config::Entry::Artifacts::EXPOSE_AS_ERROR_MESSAGE
          end
        end

        context "when 'expose_as' is used without 'paths'" do
          let(:config) { { expose_as: 'Test results' } }

          it 'reports error' do
            expect(entry.errors)
              .to include "artifacts paths can't be blank"
          end
        end

        context "when 'paths' includes '*' and 'expose_as' is defined" do
          let(:config) { { expose_as: 'Test results', paths: ['test.txt', 'test*.txt'] } }

          it 'reports error' do
            expect(entry.errors)
              .to include "artifacts paths can't contain '*' when used with 'expose_as'"
          end
        end
      end
    end

    describe 'excluded artifacts' do
      context 'when configuration is valid and the feature is enabled' do
        before do
          stub_feature_flags(ci_artifacts_exclude: true)
        end

        context 'when configuration is valid' do
          let(:config) { { untracked: true, exclude: ['some/directory/'] } }

          it 'correctly parses the configuration' do
            expect(entry).to be_valid
            expect(entry.value).to eq config
          end
        end

        context 'when configuration is not valid' do
          let(:config) { { untracked: true, exclude: 1234 } }

          it 'returns an error' do
            expect(entry).not_to be_valid
            expect(entry.errors)
              .to include 'artifacts exclude should be an array of strings'
          end
        end
      end

      context 'when artifacts/exclude feature is disabled' do
        before do
          stub_feature_flags(ci_artifacts_exclude: false)
        end

        context 'when configuration has been provided' do
          let(:config) { { untracked: true, exclude: ['some/directory/'] } }

          it 'returns an error' do
            expect(entry).not_to be_valid
            expect(entry.errors).to include 'artifacts exclude feature is disabled'
          end
        end

        context 'when configuration is not present' do
          let(:config) { { untracked: true } }

          it 'is a valid configuration' do
            expect(entry).to be_valid
          end
        end
      end
    end
  end
end
