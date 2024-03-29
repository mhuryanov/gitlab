# frozen_string_literal: true

module QA
  module Page
    module Project
      module SubMenus
        module Project
          extend QA::Page::PageConcern

          def self.included(base)
            super

            base.class_eval do
              include QA::Page::Project::SubMenus::Common

              view 'app/views/shared/nav/_sidebar_menu.html.haml' do
                element :sidebar_menu_link
              end
            end
          end

          def click_project
            retry_on_exception do
              within_sidebar do
                click_element(:sidebar_menu_link, menu_item: 'Project overview')
              end
            end
          end
        end
      end
    end
  end
end
