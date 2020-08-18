# frozen_string_literal: true

module Gitlab
  module Regex
    module Packages
      CONAN_RECIPE_FILES = %w[conanfile.py conanmanifest.txt conan_sources.tgz conan_export.tgz].freeze
      CONAN_PACKAGE_FILES = %w[conaninfo.txt conanmanifest.txt conan_package.tgz].freeze

      def conan_file_name_regex
        @conan_file_name_regex ||=
          %r{\A#{(CONAN_RECIPE_FILES + CONAN_PACKAGE_FILES).join("|")}\z}.freeze
      end

      def conan_package_reference_regex
        @conan_package_reference_regex ||= %r{\A[A-Za-z0-9]+\z}.freeze
      end

      def conan_revision_regex
        @conan_revision_regex ||= %r{\A0\z}.freeze
      end

      def conan_recipe_component_regex
        @conan_recipe_component_regex ||= %r{\A[a-zA-Z0-9_][a-zA-Z0-9_\+\.-]{1,49}\z}.freeze
      end

      def composer_package_version_regex
        @composer_package_version_regex ||= %r{^v?(\d+(\.(\d+|x))*(-.+)?)}.freeze
      end

      def package_name_regex
        @package_name_regex ||= %r{\A\@?(([\w\-\.\+]*)\/)*([\w\-\.]+)@?(([\w\-\.\+]*)\/)*([\w\-\.]*)\z}.freeze
      end

      def maven_file_name_regex
        @maven_file_name_regex ||= %r{\A[A-Za-z0-9\.\_\-\+]+\z}.freeze
      end

      def maven_path_regex
        @maven_path_regex ||= %r{\A\@?(([\w\-\.]*)/)*([\w\-\.\+]*)\z}.freeze
      end

      def maven_app_name_regex
        @maven_app_name_regex ||= /\A[\w\-\.]+\z/.freeze
      end

      def maven_version_regex
        @maven_version_regex ||= /\A(\.?[\w\+-]+\.?)+\z/.freeze
      end

      def maven_app_group_regex
        maven_app_name_regex
      end

      def unbounded_semver_regex
        # See the official regex: https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string

        # The order of the alternatives in <prerelease> are intentionally
        # reordered to be greedy. Without this change, the unbounded regex would
        # only partially match "v0.0.0-20201230123456-abcdefabcdef".
        @unbounded_semver_regex ||= /
          (?<major>0|[1-9]\d*)
          \.(?<minor>0|[1-9]\d*)
          \.(?<patch>0|[1-9]\d*)
          (?:-(?<prerelease>(?:\d*[a-zA-Z-][0-9a-zA-Z-]*|[1-9]\d*|0)(?:\.(?:\d*[a-zA-Z-][0-9a-zA-Z-]*|[1-9]\d*|0))*))?
          (?:\+(?<build>[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?
        /x.freeze
      end

      def semver_regex
        @semver_regex ||= Regexp.new("\\A#{::Gitlab::Regex.unbounded_semver_regex.source}\\z", ::Gitlab::Regex.unbounded_semver_regex.options)
      end

      def go_package_regex
        # A Go package name looks like a URL but is not; it:
        #   - Must not have a scheme, such as http:// or https://
        #   - Must not have a port number, such as :8080 or :8443

        @go_package_regex ||= /
          \b (?# word boundary)
          (?<domain>
            [0-9a-z](?:(?:-|[0-9a-z]){0,61}[0-9a-z])? (?# first domain)
            (?:\.[0-9a-z](?:(?:-|[0-9a-z]){0,61}[0-9a-z])?)* (?# inner domains)
            \.[a-z]{2,} (?# top-level domain)
          )
          (?<path>\/(?:
            [-\/$_.+!*'(),0-9a-z] (?# plain URL character)
            | %[0-9a-f]{2})* (?# URL encoded character)
          )? (?# path)
          \b (?# word boundary)
        /ix.freeze
      end
    end

    extend self
    extend Packages

    def project_name_regex
      # The character range \p{Alnum} overlaps with \u{00A9}-\u{1f9ff}
      # hence the Ruby warning.
      # https://gitlab.com/gitlab-org/gitlab/merge_requests/23165#not-easy-fixable
      @project_name_regex ||= /\A[\p{Alnum}\u{00A9}-\u{1f9ff}_][\p{Alnum}\p{Pd}\u{00A9}-\u{1f9ff}_\. ]*\z/.freeze
    end

    def project_name_regex_message
      "can contain only letters, digits, emojis, '_', '.', dash, space. " \
      "It must start with letter, digit, emoji or '_'."
    end

    def group_name_regex
      @group_name_regex ||= /\A[\p{Alnum}\u{00A9}-\u{1f9ff}_][\p{Alnum}\p{Pd}\u{00A9}-\u{1f9ff}_()\. ]*\z/.freeze
    end

    def group_name_regex_message
      "can contain only letters, digits, emojis, '_', '.', dash, space, parenthesis. " \
      "It must start with letter, digit, emoji or '_'."
    end

    ##
    # Docker Distribution Registry repository / tag name rules
    #
    # See https://github.com/docker/distribution/blob/master/reference/regexp.go.
    #
    def container_repository_name_regex
      @container_repository_regex ||= %r{\A[a-z0-9]+((?:[._/]|__|[-]{0,10})[a-z0-9]+)*\Z}
    end

    ##
    # We do not use regexp anchors here because these are not allowed when
    # used as a routing constraint.
    #
    def container_registry_tag_regex
      @container_registry_tag_regex ||= /[\w][\w.-]{0,127}/
    end

    def environment_name_regex_chars
      'a-zA-Z0-9_/\\$\\{\\}\\. \\-'
    end

    def environment_name_regex_chars_without_slash
      'a-zA-Z0-9_\\$\\{\\}\\. -'
    end

    def environment_name_regex
      @environment_name_regex ||= /\A[#{environment_name_regex_chars_without_slash}]([#{environment_name_regex_chars}]*[#{environment_name_regex_chars_without_slash}])?\z/.freeze
    end

    def environment_name_regex_message
      "can contain only letters, digits, '-', '_', '/', '$', '{', '}', '.', and spaces, but it cannot start or end with '/'"
    end

    def environment_scope_regex_chars
      "#{environment_name_regex_chars}\\*"
    end

    def environment_scope_regex
      @environment_scope_regex ||= /\A[#{environment_scope_regex_chars}]+\z/.freeze
    end

    def environment_scope_regex_message
      "can contain only letters, digits, '-', '_', '/', '$', '{', '}', '.', '*' and spaces"
    end

    # https://gitlab.com/gitlab-org/cluster-integration/gitlab-agent/-/blob/master/doc/identity_and_auth.md#agent-identity-and-name
    def cluster_agent_name_regex
      /\A[a-z0-9]([-a-z0-9]*[a-z0-9])?\z/
    end

    def cluster_agent_name_regex_message
      %q{can contain only lowercase letters, digits, and '-', but cannot start or end with '-'}
    end

    def kubernetes_namespace_regex
      /\A[a-z0-9]([-a-z0-9]*[a-z0-9])?\z/
    end

    def kubernetes_namespace_regex_message
      "can contain only lowercase letters, digits, and '-'. " \
      "Must start with a letter, and cannot end with '-'"
    end

    # Pod name adheres to DNS Subdomain Names(RFC 1123) naming convention
    # https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#dns-subdomain-names
    def kubernetes_dns_subdomain_regex
      /\A[a-z0-9]([a-z0-9\-\.]*[a-z0-9])?\z/
    end

    def environment_slug_regex
      @environment_slug_regex ||= /\A[a-z]([a-z0-9-]*[a-z0-9])?\z/.freeze
    end

    def environment_slug_regex_message
      "can contain only lowercase letters, digits, and '-'. " \
      "Must start with a letter, and cannot end with '-'"
    end

    def build_trace_section_regex
      @build_trace_section_regexp ||= /section_((?:start)|(?:end)):(\d+):([a-zA-Z0-9_.-]+)\r\033\[0K/.freeze
    end

    def markdown_code_or_html_blocks
      @markdown_code_or_html_blocks ||= %r{
          (?<code>
            # Code blocks:
            # ```
            # Anything, including `>>>` blocks which are ignored by this filter
            # ```

            ^```
            .+?
            \n```\ *$
          )
        |
          (?<html>
            # HTML block:
            # <tag>
            # Anything, including `>>>` blocks which are ignored by this filter
            # </tag>

            ^<[^>]+?>\ *\n
            .+?
            \n<\/[^>]+?>\ *$
          )
      }mx
    end

    # Based on Jira's project key format
    # https://confluence.atlassian.com/adminjiraserver073/changing-the-project-key-format-861253229.html
    def jira_issue_key_regex
      @jira_issue_key_regex ||= /[A-Z][A-Z_0-9]+-\d+/
    end

    def jira_transition_id_regex
      @jira_transition_id_regex ||= /\d+/
    end

    def breakline_regex
      @breakline_regex ||= /\r\n|\r|\n/
    end

    # https://docs.aws.amazon.com/general/latest/gr/acct-identifiers.html
    def aws_account_id_regex
      /\A\d{12}\z/
    end

    def aws_account_id_message
      'must be a 12-digit number'
    end

    # https://docs.aws.amazon.com/general/latest/gr/aws-arns-and-namespaces.html
    def aws_arn_regex
      /\Aarn:\S+\z/
    end

    def aws_arn_regex_message
      'must be a valid Amazon Resource Name'
    end

    def utc_date_regex
      @utc_date_regex ||= /\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z/.freeze
    end

    def merge_request_wip
      /(?i)(\[WIP\]\s*|WIP:\s*|WIP$)/
    end

    def merge_request_draft
      /(?i)(\[draft\]|\(draft\)|draft:|draft\s\-\s|draft$)/
    end

    def issue
      @issue ||= /(?<issue>\d+\b)/
    end

    def base64_regex
      @base64_regex ||= /(?:[A-Za-z0-9+\/]{4})*(?:[A-Za-z0-9+\/]{2}==|[A-Za-z0-9+\/]{3}=)?/.freeze
    end
  end
end

Gitlab::Regex.prepend_if_ee('EE::Gitlab::Regex')
