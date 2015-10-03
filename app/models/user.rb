class User < ActiveRecord::Base
  has_many :hidden_images
  has_many :discarded_images, class_name: "Image", through: :hidden_images, source: "image"

  # Has this user discarded a given image?
  def discarded? (id)
    discarded_images.exists?(id: id)
  end
end
