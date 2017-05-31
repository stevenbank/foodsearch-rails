require 'koala'

class GraphApiService
	DEFAULT_DISTANCE ||= 500
	DEFAULT_MIN_SCORE ||= 4
	DEFAULT_FIELDS ||= 'location,name,overall_star_rating,rating_count,category,phone,link'

	attr_accessor :graph
	def initialize
		@oauth = Koala::Facebook::OAuth.new
		oauth_access_token = @oauth.get_app_access_token
		self.graph = Koala::Facebook::API.new(oauth_access_token)
	end

	def search_places lat, lng
		location = "#{lat},#{lng}"
		facebook_results = graph.search('restaurant', type: :place,center: location, distance: DEFAULT_DISTANCE, fields: DEFAULT_FIELDS)
		results = facebook_results.sort_by { |r| r['overall_star_rating'].to_i }.reverse
		results = results.select { |r| r['overall_star_rating'].to_i > DEFAULT_MIN_SCORE }.sample(5)
		return results
	end

	def get_photo id
		"https://graph.facebook.com/#{id}/picture?type=large"
	end

end