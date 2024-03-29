# frozen_string_literal: true

module Registrations
  class ProjectsController < ApplicationController
    layout 'checkout'

    LEARN_GITLAB_TEMPLATE = 'learn_gitlab.tar.gz'
    LEARN_GITLAB_ULTIMATE_TEMPLATE = 'learn_gitlab_ultimate_trial.tar.gz'

    before_action :check_signup_onboarding_enabled
    before_action only: [:new] do
      set_namespace
      authorize_create_project!
    end

    feature_category :onboarding

    def new
      @project = Project.new(namespace: @namespace)
    end

    def create
      @project = ::Projects::CreateService.new(current_user, project_params).execute

      if @project.saved?
        learn_gitlab_project = create_learn_gitlab_project

        experiment(:registrations_group_invite, actor: current_user)
          .track(:signup_successful, property: @project.namespace_id.to_s)

        if helpers.in_trial_onboarding_flow?
          trial_onboarding_context = {
            namespace_id: learn_gitlab_project.namespace_id,
            project_id: @project.id,
            learn_gitlab_project_id: learn_gitlab_project.id
          }

          record_experiment_user(:trial_onboarding_issues, trial_onboarding_context)
          record_experiment_conversion_event(:trial_onboarding_issues)

          redirect_to trial_getting_started_users_sign_up_welcome_path(learn_gitlab_project_id: learn_gitlab_project.id)
        else
          redirect_to users_sign_up_experience_level_path(namespace_path: @project.namespace)
        end
      else
        render :new
      end
    end

    private

    def check_signup_onboarding_enabled
      access_denied! unless helpers.signup_onboarding_enabled?
    end

    def create_learn_gitlab_project
      learn_gitlab_project = File.open(learn_gitlab_template_path) do |archive|
        ::Projects::GitlabProjectsImportService.new(
          current_user,
          namespace_id: @project.namespace_id,
          file: archive,
          name: learn_gitlab_project_name
        ).execute
      end

      learn_gitlab_project
    end

    def authorize_create_project!
      access_denied! unless can?(current_user, :create_projects, @namespace)
    end

    def set_namespace
      @namespace = Namespace.find_by_id(params[:namespace_id])
    end

    def project_params
      params.require(:project).permit(project_params_attributes)
    end

    def project_params_attributes
      [
        :namespace_id,
        :name,
        :path,
        :visibility_level
      ]
    end

    def learn_gitlab_project_name
      helpers.in_trial_onboarding_flow? ? s_('Learn GitLab - Ultimate trial') : s_('Learn GitLab')
    end

    def learn_gitlab_template_path
      file = if helpers.in_trial_onboarding_flow? || learn_gitlab_experiment_enabled?
               LEARN_GITLAB_ULTIMATE_TEMPLATE
             else
               LEARN_GITLAB_TEMPLATE
             end

      Rails.root.join('vendor', 'project_templates', file)
    end

    def learn_gitlab_experiment_enabled?
      Gitlab::Experimentation.in_experiment_group?(:learn_gitlab_a, subject: current_user) ||
        Gitlab::Experimentation.in_experiment_group?(:learn_gitlab_b, subject: current_user)
    end
  end
end
