# frozen_string_literal: true

class EventFilter
  attr_accessor :filter

  ALL = 'all'
  PUSH = 'push'
  MERGED = 'merged'
  ISSUE = 'issue'
  COMMENTS = 'comments'
  TEAM = 'team'
  WIKI = 'wiki'

  def initialize(filter)
    # Split using comma to maintain backward compatibility Ex/ "filter1,filter2"
    filter = filter.to_s.split(',')[0].to_s
    @filter = filters.include?(filter) ? filter : ALL
  end

  def active?(key)
    filter == key.to_s
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def apply_filter(events)
    events = apply_feature_flags(events)

    case filter
    when PUSH
      events.where(action: Event::PUSHED)
    when MERGED
      events.where(action: Event::MERGED)
    when COMMENTS
      events.where(action: Event::COMMENTED)
    when TEAM
      events.where(action: [Event::JOINED, Event::LEFT, Event::EXPIRED])
    when ISSUE
      events.where(action: [Event::CREATED, Event::UPDATED, Event::CLOSED, Event::REOPENED], target_type: 'Issue')
    when WIKI
      wiki_events(events)
    else
      events
    end
  end
  # rubocop: enable CodeReuse/ActiveRecord

  private

  def apply_feature_flags(events)
    return events.not_wiki_page unless Feature.enabled?(:wiki_events)

    events
  end

  def wiki_events(events)
    return events unless Feature.enabled?(:wiki_events)

    events.for_wiki_page
  end

  def filters
    [ALL, PUSH, MERGED, ISSUE, COMMENTS, TEAM, WIKI]
  end
end

EventFilter.prepend_if_ee('EE::EventFilter')
