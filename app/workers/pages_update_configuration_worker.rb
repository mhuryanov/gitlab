# frozen_string_literal: true

class PagesUpdateConfigurationWorker
  include ApplicationWorker

  idempotent!
  feature_category :pages

  def self.perform_async(*args)
    return unless ::Settings.pages.local_store.enabled

    super(*args)
  end

  def perform(project_id)
    project = Project.find_by_id(project_id)
    return unless project

    Projects::UpdatePagesConfigurationService.new(project).execute
  end
end
