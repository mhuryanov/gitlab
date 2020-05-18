# frozen_string_literal: true

# PostReceiveService class
#
# Used for scheduling related jobs after a push action has been performed
class PostReceiveService
  attr_reader :user, :repository, :project, :params

  def initialize(user, repository, project, params)
    @user = user
    @repository = repository
    @project = project
    @params = params
  end

  def execute
    response = Gitlab::InternalPostReceive::Response.new

    push_options = Gitlab::PushOptions.new(params[:push_options])

    response.reference_counter_decreased = Gitlab::ReferenceCounter.new(params[:gl_repository]).decrease

    PostReceive.perform_async(params[:gl_repository], params[:identifier],
                              params[:changes], push_options.as_json)

    mr_options = push_options.get(:merge_request)
    if mr_options.present?
      message = process_mr_push_options(mr_options, params[:changes])
      response.add_alert_message(message)
    end

    response.add_alert_message(storage_size_limit_alert)

    broadcast_message = BroadcastMessage.current_banner_messages&.last&.message
    response.add_alert_message(broadcast_message)

    response.add_merge_request_urls(merge_request_urls)

    # Neither User nor Project are guaranteed to be returned; an orphaned write deploy
    # key could be used
    if user && project
      redirect_message = Gitlab::Checks::ProjectMoved.fetch_message(user.id, project.id)
      project_created_message = Gitlab::Checks::ProjectCreated.fetch_message(user.id, project.id)

      response.add_basic_message(redirect_message)
      response.add_basic_message(project_created_message)
    end

    response
  end

  def process_mr_push_options(push_options, changes)
    Gitlab::QueryLimiting.whitelist('https://gitlab.com/gitlab-org/gitlab-foss/issues/61359')
    return unless repository

    unless repository.repo_type.project?
      return push_options_warning('Push options are only supported for projects')
    end

    service = ::MergeRequests::PushOptionsHandlerService.new(
      project, user, changes, push_options
    ).execute

    if service.errors.present?
      push_options_warning(service.errors.join("\n\n"))
    end
  end

  def push_options_warning(warning)
    options = Array.wrap(params[:push_options]).map { |p| "'#{p}'" }.join(' ')
    "WARNINGS:\nError encountered with push options #{options}: #{warning}"
  end

  def merge_request_urls
    return [] unless repository&.repo_type&.project?

    ::MergeRequests::GetUrlsService.new(project).execute(params[:changes])
  end

  private

  def storage_size_limit_alert
    return unless repository&.repo_type&.project?

    payload = Namespaces::CheckStorageSizeService.new(project.namespace, user).execute.payload
    return unless payload.present?

    alert_level = "##### #{payload[:alert_level].to_s.upcase} #####"

    [alert_level, payload[:usage_message], payload[:explanation_message]].join("\n")
  end
end

PostReceiveService.prepend_if_ee('EE::PostReceiveService')
