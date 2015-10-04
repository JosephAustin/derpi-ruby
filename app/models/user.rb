class User < ActiveRecord::Base
  has_many :hidden_images
  has_many :discarded_images, class_name: "Image", through: :hidden_images, source: "image"
  has_many :hidden_indexers

  # Has this user discarded a given image?
  def discarded? (image)
	# Hidden indexers are temporary; we convert them to regular hidden images
	# when they are queries. This keeps them 'under the hood'.
	ActiveRecord::Base.transaction do
	  if hidden_indexers.exists?(indexer: image.indexer)
	    HiddenImage.create(image_id: image.id, user_id: self.id)
	    hidden_indexers.where(indexer: image.indexer).destroy_all
	  end
	end

    discarded_images.exists?(id: image.id)
  end
end
