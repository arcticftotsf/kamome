class Todo < ApplicationRecord
  belongs_to :user
  encrypts :title
end
