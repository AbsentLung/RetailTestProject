class Alert < ApplicationRecord
  belongs_to :brand
  belongs_to :product
  belongs_to :store
  belongs_to :first_event, class_name: "TrackingEvent", foreign_key: :first_event_id, inverse_of: false
  belongs_to :second_event, class_name: "TrackingEvent", foreign_key: :second_event_id, inverse_of: false
end
