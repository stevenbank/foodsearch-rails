require 'koala'

class GraphApiService < BaseService
  include Process

  DEFAULT_SEARCH ||= 'restaurant'
  DEFAULT_DISTANCE ||= 500
  DEFAULT_MIN_SCORE ||= 3.5
  DEFAULT_RANDOM ||= true
  DEFAULT_OPEN ||= false
  DEFAULT_FIELDS ||= 'location,name,overall_star_rating,rating_count,
                            phone,link,price_range,category,category_list,
                            hours,website,is_permanently_closed'
  SEARCH_API ||= 'https://graph.facebook.com/v2.12/search?'

  def initialize
    @oauth_access_token = Koala::Facebook::OAuth.new.get_app_access_token
    @graph = Koala::Facebook::API.new(@oauth_access_token)
  end

  def search_places lat, lng, options={}
    limit = 100
    user = options[:user] || nil
    size = options[:size] || 5
    mode = options[:mode] || nil
    open_now = options.dig(:open_now).present? ? options[:open_now] : user.try(:open_now)
    keyword = options[:keyword] || DEFAULT_SEARCH

    position = "#{lat},#{lng}"
    max_distance = user.try(:max_distance) || DEFAULT_DISTANCE
    min_score = user.try(:min_score) || DEFAULT_MIN_SCORE
    random_type = user.try(:random_type) || DEFAULT_RANDOM
    open_now = open_now || DEFAULT_OPEN

    # old API
    # results = @graph.search(keyword,
    #                         type: :place,
    #                         center: position,
    #                         distance: max_distance,
    #                         locale: I18n.locale.to_s,
    #                         limit: limit,
    #                         fields: DEFAULT_FIELDS)
    # 測試API
    api_url = "#{SEARCH_API}q=#{keyword}&suppress_http_code=1&
              type=place&
              center=#{position}&
              distance=#{max_distance}&
              locale=#{I18n.locale}$
              limit=#{limit}&
              fields=#{DEFAULT_FIELDS}&
              access_token=#{@oauth_access_token}"
    response = Net::HTTP.get(URI.parse(api_url))
    next_result_url = JSON.parse(response).dig('paging', 'next')
    results = JSON.parse(response).dig('data')

    until !next_result_url.present? do
      response = Net::HTTP.get(URI.parse(next_result_url))
      next_result_url = JSON.parse(response).dig('paging', 'next')
      results += JSON.parse(response).dig('data')
    end

    # 移除連結不存在 的搜尋結果
    # 移除類別不包含 餐 的搜尋結果
    # 移除評分低於設定數字的搜尋結果

    # results = facebook_results.reject { |r|
    #   r['category_list'].any? {|c| c['name'].presence_in(REJECT_CATEGORY) } ||
    #     r['is_permanently_closed'] == true ||
    #     r['overall_star_rating'].to_i < min_score }
    results = results.reject { |r| r['overall_star_rating'].to_f < min_score }
    # 判斷目前是否營業中
    results = results.each { |r| r['open_now'] = check_open_now(r['hours']) }
    results = results.reject { |r| r['open_now'] == false } if open_now == 'true'

    # 計算距離
    results = results.each { |r| r['distance'] = (count_distance([lat, lng], [r['location']['latitude'], r['location']['longitude']])).to_i }
    results = results.reject { |r| r['distance'] > max_distance }

    results = case mode
              when 'score'
                results.sort_by { |r| [r['overall_star_rating'].to_f, r['rating_count'].to_i] }.reverse
              when 'distance'
                results.sort_by { |r| r['distance'] }
              else
                random_type ? results.sample(size) : results.first(size)
              end
  end

  def check_open_now hours=nil
    open_now = false
    if hours.present?
      date = Time.now.strftime('%a').downcase
      hours = hours.reject {|key, value| !key.include?(date)}
      if hours.size > 0
        open_time_array = []
        (1..3).each do |i|
          temp_array = []
          hours.each do |key, value|
            temp_array << value if key.include?("_#{i}_")
          end
          open_time_array << temp_array if temp_array.size > 0
        end
        current_time = Time.now.strftime('%R')
        open_time_array.each do |time|
          if time.last > time.first
            open_now = true if current_time.between?(time.first, time.last)
          else
            open_now = true if current_time.between?(time.first, "24:00")
            open_now = true if current_time.between?("00:00", time.last)
          end
        end
      else
        open_now = true
      end
    else
      open_now = true
    end
    open_now
  end
end
